import 'package:characters/characters.dart';
import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../storage/planner_database.dart';
import 'day_board.dart';
import 'day_key.dart';
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

  /// 持续推送 [dayKey] 这一天画布上要显示的内容。
  Stream<DayBoard> watchDay(DayKey dayKey) {
    final query = _db.select(_db.taskCards)
      ..where(
        (c) =>
            c.dayKey.equals(dayKey.toString()) &
            c.status.equalsValue(CardStatus.active) &
            c.deletedAt.isNull(),
      )
      ..orderBy([(c) => OrderingTerm(expression: c.zIndex)]);
    return query.watch().map(
      (rows) => DayBoard(cards: rows.map(_toCard).toList()),
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

  static DateTime? _fromMillis(int? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
