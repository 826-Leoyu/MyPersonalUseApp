import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/planner_service.dart';
import 'package:my_personal_use_app/storage/planner_database.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/failing_storage.dart';

/// 切入点 1 的测试环境：真实的 [PlannerService] + 内存 SQLite + 假时钟。
///
/// 底层的内存数据库在 [reopen] 之后仍然保留，用来模拟"重启 App"。
class PlannerHarness {
  PlannerHarness() : _sqlite = sqlite3.openInMemory() {
    _open();
  }

  final Database _sqlite;
  final _failingStorage = FailingStorage();
  late PlannerDatabase _database;
  late PlannerService service;

  /// 假时钟的当前时间（本地时间），可以直接修改来模拟时间流逝。
  DateTime now = DateTime(2026, 10, 20, 9);

  DayKey get today => DayKey.fromDateTime(now);

  /// 打开后，所有写入都会报错；读取不受影响。
  set failWrites(bool value) =>
      _failingStorage.writesBeforeFailure = value ? 0 : null;

  /// 打开后所有读取都会报错。
  set failReads(bool value) => _failingStorage.failReads = value;

  /// 之后的 [count] 次写入成功，再往后的写入都报错，用来模拟事务中途失败。
  void failWritesAfter(int count) =>
      _failingStorage.writesBeforeFailure = count;

  void _open() {
    _database = PlannerDatabase(
      NativeDatabase.opened(
        _sqlite,
        closeUnderlyingOnClose: false,
      ).interceptWith(_failingStorage),
    );
    service = PlannerService(database: _database, clock: Clock(() => now));
  }

  /// 关闭当前连接，在同一个内存数据库上重新建立数据库连接和 service。
  Future<void> reopen() async {
    await _database.close();
    _open();
  }

  // ---- 测试夹具 ----
  //
  // 直接改数据库，快速准备卡片状态和历史记录（比如把卡片放到公开接口
  // 做不到的日期上）。只用来准备数据，检查结果一律通过 service 的公开接口。
  // 走真实顺延的端到端测试见 carry_over_test.dart（每日维护）、
  // completion_test.dart 和 trash_test.dart（取消完成、恢复时的立即顺延）。

  /// 把卡片搬到 [dayKey] 那一天，相当于顺延。
  Future<void> markMovedToDay(String cardId, DayKey dayKey) => _updateCardRow(
    cardId,
    TaskCardsCompanion(dayKey: Value(dayKey.toString())),
  );

  /// 把卡片标成顺延过，相当于顺延。
  Future<void> markCarriedOver(String cardId) => _updateCardRow(
    cardId,
    const TaskCardsCompanion(carriedOver: Value(true)),
  );

  /// 给卡片留一条顺延历史记录，相当于顺延。
  Future<void> addCarryOverRecord(String cardId) async {
    final millis = _nowMillis;
    await _database
        .into(_database.carryOverRecords)
        .insert(
          CarryOverRecordsCompanion.insert(
            id: 'record-$cardId-$millis',
            cardId: cardId,
            fromDayKey: today.addDays(-1).toString(),
            toDayKey: today.toString(),
            x: 0,
            y: 0,
            width: 180,
            height: 88,
            titleSnapshot: '历史',
            colorArgb: 0xFFFFF3B0,
            carriedAt: millis,
            createdAt: millis,
            updatedAt: millis,
          ),
        );
  }

  Future<void> _updateCardRow(String cardId, TaskCardsCompanion changes) async {
    final updated = await (_database.update(
      _database.taskCards,
    )..where((c) => c.id.equals(cardId))).write(changes);
    if (updated != 1) throw StateError('夹具找不到卡片 $cardId');
  }

  int get _nowMillis => now.toUtc().millisecondsSinceEpoch;

  Future<void> dispose() async {
    await _database.close();
    _sqlite.close();
  }
}
