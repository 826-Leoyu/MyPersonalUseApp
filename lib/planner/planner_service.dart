import 'dart:math';

import 'package:characters/characters.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../storage/planner_database.dart';
import 'carry_over_layout.dart';
import 'carry_over_record.dart';
import 'day_board.dart';
import 'day_counts.dart';
import 'day_key.dart';
import 'link.dart';
import 'link_kind.dart';
import 'maintenance_summary.dart';
import 'planner_exceptions.dart';
import 'task_card.dart';
import 'trashed_card.dart';

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

  /// 删除的卡片在回收站里保留多久。
  static const trashRetention = Duration(days: 10);

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

  /// 取消完成：卡片恢复为未完成，回到画布上原来的位置和层级。卡片的日期
  /// 已经过去时，按顺延规则（单张为一组）立即搬到今天并留下历史记录；
  /// 系统时钟被调回过去时，"今天"见 [_effectiveToday]。
  ///
  /// 卡片不是已完成、或者在回收站里时抛出 [InvalidState]。
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
      await _carryOverIfPast(id);
    });
  }

  /// 把卡片移到回收站。连线和历史记录不动。
  ///
  /// 已经在回收站里时静默成功，删除时间不变；卡片不存在时抛出 [NotFound]。
  Future<void> deleteCard(String id) async {
    await _write(() async {
      final card = await _requireCard(id);
      if (card.deletedAt != null) return;
      await _updateCard(id, TaskCardsCompanion(deletedAt: Value(_nowMillis)));
    });
  }

  /// 把卡片从回收站拿出来，回到原来的日期、位置和状态。未完成卡片的日期
  /// 已经过去时，按顺延规则（单张为一组）立即搬到今天并留下历史记录；
  /// 系统时钟被调回过去时，"今天"见 [_effectiveToday]。
  ///
  /// 不在回收站里时静默成功（删除的撤销提示和撤销栈可能先后恢复同一张卡片）；
  /// 卡片不存在时抛出 [NotFound]。
  Future<void> restoreCard(String id) async {
    await _write(() async {
      final card = await _requireCard(id);
      if (card.deletedAt == null) return;
      await _updateCard(id, const TaskCardsCompanion(deletedAt: Value(null)));
      await _carryOverIfPast(id);
    });
  }

  /// 物理删除回收站里的一张卡片，以及和它相关的所有连线和历史记录。
  ///
  /// 卡片不在回收站里时抛出 [InvalidState]；卡片不存在时抛出 [NotFound]。
  Future<void> deleteForever(String id) async {
    await _write(() async {
      final card = await _requireCard(id);
      if (card.deletedAt == null) {
        throw const InvalidState('只有回收站里的卡片可以永久删除');
      }
      await _purgeCards([id]);
    });
  }

  /// 物理删除回收站里的所有卡片，以及和它们相关的所有连线和历史记录。
  Future<void> emptyTrash() async {
    await _write(() async {
      final trashedIds =
          await (_db.selectOnly(_db.taskCards)
                ..addColumns([_db.taskCards.id])
                ..where(_db.taskCards.deletedAt.isNotNull()))
              .map((row) => row.read(_db.taskCards.id)!)
              .get();
      await _purgeCards(trashedIds);
    });
  }

  /// 物理删除 [cardIds] 这些卡片，以及和它们相关的所有连线和历史记录。
  ///
  /// 先删连线和历史记录，再删卡片（外键约束要求）。回收站测试按这 3 次写入
  /// 模拟中途失败，改动写入次数或顺序时要同步修改测试。
  Future<void> _purgeCards(List<String> cardIds) async {
    await (_db.delete(_db.links)
          ..where((l) => l.fromCardId.isIn(cardIds) | l.toCardId.isIn(cardIds)))
        .go();
    await (_db.delete(
      _db.carryOverRecords,
    )..where((r) => r.cardId.isIn(cardIds))).go();
    await (_db.delete(_db.taskCards)..where((c) => c.id.isIn(cardIds))).go();
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

  /// 打开存储：建立连接，并完成建表或结构升级。打不开时抛出 [StorageFailure]。
  ///
  /// App 启动时先调用它，确认存储可用后再显示画布。
  Future<void> open() async {
    try {
      await _db.customSelect('SELECT 1').get();
    } on Exception catch (e) {
      throw StorageFailure('数据库打不开', e);
    }
  }

  /// 关闭存储连接。连接没有打开成功时，关闭会再抛出一次打开时的错误。
  Future<void> close() => _db.close();

  /// 每日维护：先永久删除回收站里过期的卡片（每次都执行）；今天比上次维护的
  /// 日期晚时，再把今天以前没完成的卡片顺延到今天，并记下今天为维护日期。
  ///
  /// 幂等：同一天再执行不再顺延。系统时钟被调回过去时跳过顺延，
  /// 也不把维护日期改小。所有修改在一个事务里。
  Future<MaintenanceSummary> runDailyMaintenance() {
    return _write(() async {
      final cleanedCount = await _purgeExpiredTrash();
      final today = _today;
      final lastDay = await _lastMaintenanceDay();
      if (lastDay != null && today <= lastDay) {
        return MaintenanceSummary(carriedCount: 0, cleanedCount: cleanedCount);
      }
      final pastCards =
          await (_db.select(_db.taskCards)..where(
                (c) =>
                    c.dayKey.isSmallerThanValue(today.toString()) &
                    c.status.equalsValue(CardStatus.active) &
                    c.deletedAt.isNull(),
              ))
              .get();
      await _carryOver(pastCards, today);
      await _db
          .into(_db.appMeta)
          .insertOnConflictUpdate(
            AppMetaCompanion.insert(
              key: _lastMaintenanceDayKey,
              value: today.toString(),
            ),
          );
      return MaintenanceSummary(
        carriedCount: pastCards.length,
        cleanedCount: cleanedCount,
      );
    });
  }

  /// 永久删除在回收站里放了超过 [trashRetention] 的卡片，返回删除了几张。
  ///
  /// 按从删除时间起实际经过的时间算（和 [watchTrash] 的剩余天数同一个基准），
  /// 恰好满 [trashRetention] 时还保留。没有过期卡片时不写入。
  /// 要在调用方的事务里执行。
  Future<int> _purgeExpiredTrash() async {
    final expiredBefore = _nowMillis - trashRetention.inMilliseconds;
    final expiredIds =
        await (_db.selectOnly(_db.taskCards)
              ..addColumns([_db.taskCards.id])
              ..where(
                _db.taskCards.deletedAt.isSmallerThanValue(expiredBefore),
              ))
            .map((row) => row.read(_db.taskCards.id)!)
            .get();
    if (expiredIds.isNotEmpty) await _purgeCards(expiredIds);
    return expiredIds.length;
  }

  static const _lastMaintenanceDayKey = 'lastMaintenanceDay';

  /// 上次执行每日维护的日期；从来没执行过时为 null。
  Future<DayKey?> _lastMaintenanceDay() async {
    final entry = await (_db.select(
      _db.appMeta,
    )..where((m) => m.key.equals(_lastMaintenanceDayKey))).getSingleOrNull();
    return entry == null ? null : DayKey.parse(entry.value);
  }

  /// 卡片 [id] 未完成、日期早于有效的今天（见 [_effectiveToday]）时，把它
  /// 单独顺延到有效的今天。取消完成和恢复卡片在改完状态后调用，
  /// 要在调用方的事务里执行。
  Future<void> _carryOverIfPast(String id) async {
    final today = await _effectiveToday();
    final row = await (_db.select(
      _db.taskCards,
    )..where((c) => c.id.equals(id))).getSingle();
    if (row.status == CardStatus.active && DayKey.parse(row.dayKey) < today) {
      await _carryOver([row], today);
    }
  }

  /// 用户操作触发立即顺延时的"今天"：时钟的今天和上次维护日期中较晚的一个。
  ///
  /// 系统时钟被调回过去时，按时钟的今天顺延会把卡片搬到比维护日期还早的
  /// 日子；时钟恢复到维护日期那天不再维护，卡片就留在了过去。见 spec
  /// 「系统时钟回拨时的例外」。
  Future<DayKey> _effectiveToday() async {
    final today = _today;
    final lastDay = await _lastMaintenanceDay();
    return lastDay != null && lastDay > today ? lastDay : today;
  }

  /// 按 spec「顺延排布算法」把 [cards] 顺延到 [toDay]：每张卡片在出发的那天
  /// 留一条历史记录，[toDay] 已有的卡片右移腾出左上角，顺延卡片按
  /// [layoutCarryOver] 摆好并标记为顺延过。[cards] 为空时什么都不改。
  ///
  /// 要在调用方的事务里执行。每日维护和单张卡片立即顺延共用这个方法。
  Future<void> _carryOver(List<TaskCardRow> cards, DayKey toDay) async {
    if (cards.isEmpty) return;
    final isOnToDay = _db.taskCards.dayKey.equals(toDay.toString());
    final minX = _db.taskCards.x.min();
    final toDayMinX =
        (await (_db.selectOnly(_db.taskCards)
                  ..addColumns([minX])
                  ..where(isOnToDay))
                .getSingle())
            .read(minX);
    final layout = layoutCarryOver(
      [
        for (final card in cards)
          (
            id: card.id,
            dayKey: DayKey.parse(card.dayKey),
            x: card.x,
            y: card.y,
            width: card.width,
            height: card.height,
            zIndex: card.zIndex,
          ),
      ],
      todayMinX: toDayMinX,
      todayMaxZIndex: await _maxZIndex(toDay),
    );
    final now = _nowMillis;
    // 先移今天已有的卡片（包括已完成和回收站里的），再把顺延卡片搬过来。
    if (layout.todayShift != 0) {
      await (_db.update(_db.taskCards)..where((_) => isOnToDay)).write(
        TaskCardsCompanion.custom(
          x: _db.taskCards.x + Constant(layout.todayShift),
          updatedAt: Constant(now),
        ),
      );
    }
    for (final card in cards) {
      await _db
          .into(_db.carryOverRecords)
          .insert(
            CarryOverRecordsCompanion.insert(
              id: _generateId(),
              cardId: card.id,
              fromDayKey: card.dayKey,
              toDayKey: toDay.toString(),
              x: card.x,
              y: card.y,
              width: card.width,
              height: card.height,
              titleSnapshot: card.title,
              colorArgb: card.colorArgb,
              carriedAt: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      final placement = layout.placements[card.id]!;
      await (_db.update(
        _db.taskCards,
      )..where((c) => c.id.equals(card.id))).write(
        TaskCardsCompanion(
          dayKey: Value(toDay.toString()),
          x: Value(placement.x),
          y: Value(placement.y),
          zIndex: Value(placement.zIndex),
          carriedOver: const Value(true),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// 持续推送 [dayKey] 这一天画布上要显示的内容。卡片、连线或历史记录变化时
  /// 都会推送。
  Stream<DayBoard> watchDay(DayKey dayKey) {
    // 画布内容来自卡片、连线、历史记录三张表，用一个只声明 readsFrom 的查询
    // 监听三张表的变化，每次变化时在一个事务里重新读出完整的画布，保证一致。
    final changes = _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.taskCards, _db.links, _db.carryOverRecords},
        )
        .watch();
    return changes.asyncMap((_) => _db.transaction(() => _loadBoard(dayKey)));
  }

  /// 持续推送 [dayKey] 这一天的已完成卡片，按完成时间倒序。
  Stream<List<TaskCard>> watchCompleted(DayKey dayKey) {
    final query = _db.select(_db.taskCards)
      ..where((c) => _completedOn(c, dayKey))
      // 同一毫秒完成的卡片按 id 排，保证顺序稳定。
      ..orderBy([
        (c) => OrderingTerm.desc(c.completedAt),
        (c) => OrderingTerm.asc(c.id),
      ]);
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

  /// 持续推送回收站里的卡片，按删除时间倒序，每张带剩余天数。
  ///
  /// 剩余天数在每次推送时按当时的时钟计算；只有时间流逝、数据没变时不会推送。
  Stream<List<TrashedCard>> watchTrash() {
    final query = _db.select(_db.taskCards)
      ..where((c) => c.deletedAt.isNotNull())
      // 同一毫秒删除的卡片按 id 排，保证顺序稳定。
      ..orderBy([
        (c) => OrderingTerm.desc(c.deletedAt),
        (c) => OrderingTerm.asc(c.id),
      ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          TrashedCard(card: _toCard(row), daysLeft: _daysLeft(row.deletedAt!)),
      ],
    );
  }

  /// [trashRetention] 减去已删除的时间，按天计，不满一天的部分向上取整，
  /// 限制在 0 到 [trashRetention] 的天数之间（系统时钟被调回删除时间以前时不超过上限）。
  int _daysLeft(int deletedAtMillis) {
    const dayMillis = Duration.millisecondsPerDay;
    final leftMillis =
        trashRetention.inMilliseconds - (_nowMillis - deletedAtMillis);
    final days = leftMillis <= 0
        ? 0
        : (leftMillis + dayMillis - 1) ~/ dayMillis;
    return min(days, trashRetention.inDays);
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
    final recordRows =
        await (_db.select(_db.carryOverRecords)
              ..where((r) => r.fromDayKey.equals(dayKey.toString()))
              // 同一毫秒顺延的记录按 id 排，保证顺序稳定。
              ..orderBy([
                (r) => OrderingTerm.asc(r.carriedAt),
                (r) => OrderingTerm.asc(r.id),
              ]))
            .get();
    final count = _db.taskCards.id.count();
    final countQuery = _db.selectOnly(_db.taskCards)
      ..addColumns([count])
      ..where(_completedOn(_db.taskCards, dayKey));
    return DayBoard(
      cards: cardRows.map(_toCard).toList(),
      links: linkRows.map(_toLink).toList(),
      carryOverRecords: recordRows.map(_toRecord).toList(),
      completedCount: (await countQuery.getSingle()).read(count)!,
    );
  }

  /// [dayKey] 这一天"已完成"列表里的卡片：已完成、不在回收站。
  static Expression<bool> _completedOn($TaskCardsTable c, DayKey dayKey) =>
      c.dayKey.equals(dayKey.toString()) &
      c.status.equalsValue(CardStatus.completed) &
      c.deletedAt.isNull();

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

  static CarryOverRecord _toRecord(CarryOverRecordRow row) => CarryOverRecord(
    id: row.id,
    cardId: row.cardId,
    fromDayKey: DayKey.parse(row.fromDayKey),
    toDayKey: DayKey.parse(row.toDayKey),
    x: row.x,
    y: row.y,
    width: row.width,
    height: row.height,
    titleSnapshot: row.titleSnapshot,
    colorArgb: row.colorArgb,
    carriedAt: _fromMillis(row.carriedAt)!,
    createdAt: _fromMillis(row.createdAt)!,
    updatedAt: _fromMillis(row.updatedAt)!,
  );

  static DateTime? _fromMillis(int? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
