import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/planner_service.dart';
import 'package:my_personal_use_app/storage/planner_database.dart';
import 'package:sqlite3/sqlite3.dart';

/// 切入点 1 的测试环境：真实的 [PlannerService] + 内存 SQLite + 假时钟。
///
/// 底层的内存数据库在 [reopen] 之后仍然保留，用来模拟"重启 App"。
class PlannerHarness {
  PlannerHarness() : _sqlite = sqlite3.openInMemory() {
    _open();
  }

  final Database _sqlite;
  final _failingWrites = _FailingWrites();
  late PlannerDatabase _database;
  late PlannerService service;

  /// 假时钟的当前时间（本地时间），可以直接修改来模拟时间流逝。
  DateTime now = DateTime(2026, 10, 20, 9);

  DayKey get today => DayKey.fromDateTime(now);

  /// 打开后，所有写入都会报错；读取不受影响。
  set failWrites(bool value) =>
      _failingWrites.writesBeforeFailure = value ? 0 : null;

  /// 之后的 [count] 次写入成功，再往后的写入都报错，用来模拟事务中途失败。
  void failWritesAfter(int count) => _failingWrites.writesBeforeFailure = count;

  void _open() {
    _database = PlannerDatabase(
      NativeDatabase.opened(
        _sqlite,
        closeUnderlyingOnClose: false,
      ).interceptWith(_failingWrites),
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
  // 直接改数据库来准备 PlannerService 还没有公开接口的卡片状态和历史记录。
  // 只用来准备数据，检查结果一律通过 service 的公开接口。
  // TODO(#11, #12): 对应的公开接口完成后，补充走公开接口的端到端测试。

  /// 把卡片搬到 [dayKey] 那一天，相当于顺延（#12）。
  Future<void> markMovedToDay(String cardId, DayKey dayKey) => _updateCardRow(
    cardId,
    TaskCardsCompanion(dayKey: Value(dayKey.toString())),
  );

  /// 把卡片标成顺延过，相当于顺延（#11）。
  Future<void> markCarriedOver(String cardId) => _updateCardRow(
    cardId,
    const TaskCardsCompanion(carriedOver: Value(true)),
  );

  /// 给卡片留一条顺延历史记录，相当于顺延（#11）。
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

/// 只用来模拟存储失败，不用来验证调用次数。
class _FailingWrites extends QueryInterceptor {
  /// 还允许成功的写入次数；为 null 时不模拟失败。
  int? writesBeforeFailure;

  void _countWriteOrThrow() {
    final remaining = writesBeforeFailure;
    if (remaining == null) return;
    if (remaining == 0) throw Exception('模拟的写入失败');
    writesBeforeFailure = remaining - 1;
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _countWriteOrThrow();
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _countWriteOrThrow();
    return super.runUpdate(executor, statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _countWriteOrThrow();
    return super.runDelete(executor, statement, args);
  }
}
