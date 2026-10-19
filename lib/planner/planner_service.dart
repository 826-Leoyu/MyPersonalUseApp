import 'package:characters/characters.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../storage/planner_database.dart';
import 'day_board.dart';
import 'day_counts.dart';
import 'day_key.dart';
import 'link.dart';
import 'link_kind.dart';
import 'planner_exceptions.dart';
import 'task_card.dart';

/// 界面层使用的业务门面。所有业务规则都在这里，每个写操作是一个事务。
class PlannerService {
  PlannerService({
    required PlannerDatabase database,
    this._clock = const Clock(),
    String Function()? generateId,
  }) : _db = database,
       _generateId = generateId ?? const Uuid().v4;

  static const maxTitleLength = 200;
  static const maxNoteLength = 5000;

  final PlannerDatabase _db;
  final Clock _clock;
  final String Function() _generateId;

  /// 在 [dayKey] 的画布上新建一张卡片，放在当天所有卡片的最上层。
  Future<TaskCard> createCard(
    DayKey dayKey, {
    required double x,
    required double y,
    required String title,
    int? colorArgb,
  }) async {
    final cleanTitle = _validTitle(title);
    if (dayKey < _today) {
      throw const InvalidState('过去的日期不能新建卡片');
    }
    return _write(() async {
      final now = _nowMillis;
      final row = TaskCardRow(
        id: _generateId(),
        dayKey: dayKey.toString(),
        title: cleanTitle,
        x: x,
        y: y,
        width: TaskCard.defaultWidth,
        height: TaskCard.defaultHeight,
        zIndex: await _maxZIndex(dayKey) + 1,
        colorArgb: colorArgb ?? TaskCard.defaultColorArgb,
        status: CardStatus.active,
        carriedOver: false,
        originalDayKey: dayKey.toString(),
        createdAt: now,
        updatedAt: now,
      );
      await _db.into(_db.taskCards).insert(row);
      return _toCard(row);
    });
  }

  /// 修改标题和备注；[note] 为 null 表示没有备注。
  Future<void> updateCardContent(
    String id, {
    required String title,
    required String? note,
  }) async {
    final cleanTitle = _validTitle(title);
    if (note != null && note.characters.length > maxNoteLength) {
      throw const InvalidInput('备注最多 $maxNoteLength 个字');
    }
    await _write(
      () => _updateCard(
        id,
        TaskCardsCompanion(title: Value(cleanTitle), note: Value(note)),
      ),
    );
  }

  /// 把卡片移到新位置，并提到当天所有卡片的最上层。
  Future<void> moveCard(
    String id, {
    required double x,
    required double y,
  }) async {
    await _write(() async {
      final card = await _requireCard(id);
      final topZIndex = await _maxZIndex(card.dayKey) + 1;
      await _updateCard(
        id,
        TaskCardsCompanion(x: Value(x), y: Value(y), zIndex: Value(topZIndex)),
      );
    });
  }

  /// 调整卡片大小；超出上下限时截断到范围以内，不报错。
  Future<void> resizeCard(
    String id, {
    required double width,
    required double height,
  }) async {
    final clampedWidth = width.clamp(TaskCard.minWidth, TaskCard.maxWidth);
    final clampedHeight = height.clamp(TaskCard.minHeight, TaskCard.maxHeight);
    await _write(
      () => _updateCard(
        id,
        TaskCardsCompanion(
          width: Value(clampedWidth),
          height: Value(clampedHeight),
        ),
      ),
    );
  }

  /// 修改卡片颜色，[colorArgb] 是 ARGB 颜色值。
  Future<void> setCardColor(String id, int colorArgb) async {
    await _write(
      () => _updateCard(id, TaskCardsCompanion(colorArgb: Value(colorArgb))),
    );
  }

  /// 完成一张卡片：它离开画布，进入当天的"已完成"列表。
  ///
  /// 卡片不是未完成、或者在回收站里时抛出 [InvalidState]。
  Future<void> completeCard(String id) async {
    await _write(() async {
      final card = await _requireCard(id);
      if (card.status != CardStatus.active || card.deletedAt != null) {
        throw const InvalidState('只有画布上未完成的卡片可以完成');
      }
      await _updateCard(
        id,
        TaskCardsCompanion(
          status: const Value(CardStatus.completed),
          completedAt: Value(_nowMillis),
        ),
      );
    });
  }

  /// 取消完成：卡片恢复为未完成，回到画布上原来的位置和层级。
  ///
  /// 卡片不是已完成、或者在回收站里时抛出 [InvalidState]。
  // TODO(#12): 卡片日期早于今天时，按顺延规则立即搬到今天并生成历史记录。
  Future<void> uncompleteCard(String id) async {
    await _write(() async {
      final card = await _requireCard(id);
      if (card.status != CardStatus.completed || card.deletedAt != null) {
        throw const InvalidState('只有已完成列表里的卡片可以取消完成');
      }
      await _updateCard(
        id,
        const TaskCardsCompanion(
          status: Value(CardStatus.active),
          completedAt: Value(null),
        ),
      );
    });
  }

  /// 在 [draggedId] 和 [targetId] 之间连线或断开。
  Future<ToggleLinkResult> toggleLink(String draggedId, String targetId) {
    return _write(() async {
      await _requireLinkable(draggedId, targetId);
      final now = _nowMillis;
      final existing = await _activeLinkBetween(draggedId, targetId);
      if (existing != null) {
        await _softDeleteLink(existing.id);
        return LinkRemoved(existing.id);
      }
      final row = LinkRow(
        id: _generateId(),
        fromCardId: draggedId,
        toCardId: targetId,
        kind: LinkKind.visual,
        createdAt: now,
        updatedAt: now,
      );
      await _db.into(_db.links).insert(row);
      return LinkCreated(row.id);
    });
  }

  /// 断开连线（软删除）。已经断开时静默成功；连线不存在时抛出 [NotFound]。
  Future<void> removeLink(String linkId) async {
    await _write(() async {
      final link = await _requireLink(linkId);
      if (link.deletedAt == null) await _softDeleteLink(linkId);
    });
  }

  /// 恢复断开的连线，只给撤销使用。没有断开时静默成功。
  ///
  /// 两端卡片不满足显示条件，或者这两张卡片之间已经有另一条未删除的连线时，
  /// 抛出 [InvalidState]；连线不存在时抛出 [NotFound]。
  Future<void> restoreLink(String linkId) async {
    await _write(() async {
      final link = await _requireLink(linkId);
      if (link.deletedAt == null) return;
      await _requireLinkable(link.fromCardId, link.toCardId);
      if (await _activeLinkBetween(link.fromCardId, link.toCardId) != null) {
        throw const InvalidState('这两张卡片之间已经有另一条连线');
      }
      await _updateLink(linkId, const LinksCompanion(deletedAt: Value(null)));
    });
  }

  Future<void> _softDeleteLink(String linkId) =>
      _updateLink(linkId, LinksCompanion(deletedAt: Value(_nowMillis)));

  /// 修改一条连线并刷新 updatedAt。调用前已确认连线存在。
  Future<void> _updateLink(String linkId, LinksCompanion changes) async {
    await (_db.update(_db.links)..where((l) => l.id.equals(linkId))).write(
      changes.copyWith(updatedAt: Value(_nowMillis)),
    );
  }

  Future<LinkRow> _requireLink(String id) async {
    final row = await (_db.select(
      _db.links,
    )..where((l) => l.id.equals(id))).getSingleOrNull();
    if (row == null) throw NotFound('找不到连线 $id');
    return row;
  }

  /// 检查两张卡片之间可以显示连线：不是同一张、都是未完成、都不在回收站、
  /// 并且在同一天；否则抛出 [InvalidState]。卡片不存在时抛出 [NotFound]。
  Future<void> _requireLinkable(String cardA, String cardB) async {
    if (cardA == cardB) throw const InvalidState('卡片不能连到自己');
    final a = await _requireCard(cardA);
    final b = await _requireCard(cardB);
    for (final card in [a, b]) {
      if (card.status != CardStatus.active || card.deletedAt != null) {
        throw const InvalidState('已完成或在回收站里的卡片不能连线');
      }
    }
    if (a.dayKey != b.dayKey) {
      throw const InvalidState('不在同一天的卡片不能连线');
    }
  }

  /// 两张卡片之间（不管方向）未删除的那条连线；没有时为 null。
  Future<LinkRow?> _activeLinkBetween(String cardA, String cardB) {
    final query = _db.select(_db.links)
      ..where(
        (l) =>
            l.deletedAt.isNull() &
            ((l.fromCardId.equals(cardA) & l.toCardId.equals(cardB)) |
                (l.fromCardId.equals(cardB) & l.toCardId.equals(cardA))),
      );
    return query.getSingleOrNull();
  }

  /// 持续推送 [dayKey] 这一天画布上要显示的内容。卡片或连线变化时都会推送。
  Stream<DayBoard> watchDay(DayKey dayKey) {
    // 画布内容来自卡片和连线两张表，用一个只声明 readsFrom 的查询监听
    // 两张表的变化，每次变化时在一个事务里重新读出完整的画布，保证一致。
    final changes = _db
        .customSelect('SELECT 1', readsFrom: {_db.taskCards, _db.links})
        .watch();
    return changes.asyncMap((_) => _db.transaction(() => _loadBoard(dayKey)));
  }

  /// 持续推送 [dayKey] 这一天的已完成卡片，按完成时间倒序。
  Stream<List<TaskCard>> watchCompleted(DayKey dayKey) {
    final query = _db.select(_db.taskCards)
      ..where(
        (c) =>
            c.dayKey.equals(dayKey.toString()) &
            c.status.equalsValue(CardStatus.completed) &
            c.deletedAt.isNull(),
      )
      ..orderBy([(c) => OrderingTerm.desc(c.completedAt)]);
    return query.watch().map((rows) => rows.map(_toCard).toList());
  }

  /// 持续推送从 [from] 到 [to]（包含两端）每一天的未完成数和已完成数。
  /// 范围内没有卡片的日子也有一项，数量都是 0。
  ///
  /// [from] 晚于 [to] 时抛出 [InvalidInput]。
  Stream<Map<DayKey, DayCounts>> watchDayCounts(DayKey from, DayKey to) {
    if (from > to) throw const InvalidInput('开始日期不能晚于结束日期');
    final cards = _db.taskCards;
    final count = cards.id.count();
    final query = _db.selectOnly(cards)
      ..addColumns([cards.dayKey, cards.status, count])
      ..where(
        cards.dayKey.isBetweenValues(from.toString(), to.toString()) &
            cards.deletedAt.isNull(),
      )
      ..groupBy([cards.dayKey, cards.status]);
    return query.watch().map((rows) {
      final active = <DayKey, int>{};
      final completed = <DayKey, int>{};
      for (final row in rows) {
        final day = DayKey.parse(row.read(cards.dayKey)!);
        final byStatus = switch (cards.status.converter.fromSql(
          row.read(cards.status)!,
        )) {
          CardStatus.active => active,
          CardStatus.completed => completed,
        };
        byStatus[day] = row.read(count)!;
      }
      return {
        for (var day = from; day <= to; day = day.addDays(1))
          day: DayCounts(
            activeCount: active[day] ?? 0,
            completedCount: completed[day] ?? 0,
          ),
      };
    });
  }

  Future<DayBoard> _loadBoard(DayKey dayKey) async {
    final cardRows =
        await (_db.select(_db.taskCards)
              ..where(
                (c) =>
                    c.dayKey.equals(dayKey.toString()) &
                    c.status.equalsValue(CardStatus.active) &
                    c.deletedAt.isNull(),
              )
              ..orderBy([(c) => OrderingTerm(expression: c.zIndex)]))
            .get();
    // 连线显示规则：两端都是这一天画布上显示的卡片（同一天、未完成、不在回收站）。
    final cardIds = cardRows.map((c) => c.id);
    final linkRows =
        await (_db.select(_db.links)..where(
              (l) =>
                  l.deletedAt.isNull() &
                  l.fromCardId.isIn(cardIds) &
                  l.toCardId.isIn(cardIds),
            ))
            .get();
    final completedCount = _db.taskCards.id.count();
    final countQuery = _db.selectOnly(_db.taskCards)
      ..addColumns([completedCount])
      ..where(
        _db.taskCards.dayKey.equals(dayKey.toString()) &
            _db.taskCards.status.equalsValue(CardStatus.completed) &
            _db.taskCards.deletedAt.isNull(),
      );
    return DayBoard(
      cards: cardRows.map(_toCard).toList(),
      links: linkRows.map(_toLink).toList(),
      completedCount: (await countQuery.getSingle()).read(completedCount)!,
    );
  }

  /// 卡片当前的日期、状态、是否在回收站；找不到时抛出 [NotFound]。
  Future<CardLocation> findCard(String id) async {
    final card = await _requireCard(id);
    return CardLocation(
      dayKey: card.dayKey,
      status: card.status,
      inTrash: card.deletedAt != null,
    );
  }

  /// 在一个事务里执行写操作。存储报错时事务整体回滚，并抛出 [StorageFailure]；
  /// 业务错误原样抛出。
  Future<T> _write<T>(Future<T> Function() action) async {
    try {
      return await _db.transaction(action);
    } on PlannerException {
      rethrow;
    } on Exception catch (e) {
      throw StorageFailure('保存失败', e);
    }
  }

  /// 修改一张卡片并刷新 updatedAt；卡片不存在时抛出 [NotFound]。
  ///
  /// 先读后写，这样即使存储写入失败，找不到卡片时也报 [NotFound]。
  Future<void> _updateCard(String id, TaskCardsCompanion changes) async {
    await _requireCard(id);
    await (_db.update(_db.taskCards)..where((c) => c.id.equals(id))).write(
      changes.copyWith(updatedAt: Value(_nowMillis)),
    );
  }

  Future<TaskCard> _requireCard(String id) async {
    final row = await (_db.select(
      _db.taskCards,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (row == null) throw NotFound('找不到卡片 $id');
    return _toCard(row);
  }

  /// 当天卡片的最大 zIndex；当天没有卡片时为 0。
  Future<int> _maxZIndex(DayKey dayKey) async {
    final maxZIndex = _db.taskCards.zIndex.max();
    final query = _db.selectOnly(_db.taskCards)
      ..addColumns([maxZIndex])
      ..where(_db.taskCards.dayKey.equals(dayKey.toString()));
    final row = await query.getSingle();
    return row.read(maxZIndex) ?? 0;
  }

  int get _nowMillis => _clock.now().toUtc().millisecondsSinceEpoch;

  DayKey get _today => DayKey.fromDateTime(_clock.now());

  /// 去掉首尾空格后的标题；为空或超过 [maxTitleLength] 个字时抛出 [InvalidInput]。
  /// 按看到的字（字形簇）计数，一个组合表情算一个字。
  static String _validTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw const InvalidInput('标题不能为空');
    if (trimmed.characters.length > maxTitleLength) {
      throw const InvalidInput('标题最多 $maxTitleLength 个字');
    }
    return trimmed;
  }

  static TaskCard _toCard(TaskCardRow row) => TaskCard(
    id: row.id,
    dayKey: DayKey.parse(row.dayKey),
    title: row.title,
    note: row.note,
    x: row.x,
    y: row.y,
    width: row.width,
    height: row.height,
    zIndex: row.zIndex,
    colorArgb: row.colorArgb,
    status: row.status,
    completedAt: _fromMillis(row.completedAt),
    carriedOver: row.carriedOver,
    originalDayKey: DayKey.parse(row.originalDayKey),
    deletedAt: _fromMillis(row.deletedAt),
    createdAt: _fromMillis(row.createdAt)!,
    updatedAt: _fromMillis(row.updatedAt)!,
  );

  static Link _toLink(LinkRow row) => Link(
    id: row.id,
    fromCardId: row.fromCardId,
    toCardId: row.toCardId,
    kind: row.kind,
    deletedAt: _fromMillis(row.deletedAt),
    createdAt: _fromMillis(row.createdAt)!,
    updatedAt: _fromMillis(row.updatedAt)!,
  );

  static DateTime? _fromMillis(int? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
