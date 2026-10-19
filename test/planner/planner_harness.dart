import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/planner_service.dart';
import 'package:my_personal_use_app/planner/task_card.dart';
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
  set failWrites(bool value) => _failingWrites.enabled = value;

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
  // 直接改数据库来准备 PlannerService 还没有公开接口的卡片状态。
  // 只用来准备数据，检查结果一律通过 service 的公开接口。
  // TODO(#9, #10, #12): 对应的公开接口完成后，补充走公开接口的端到端测试。

  /// 把卡片标成已完成，相当于 `completeCard`（#9）。
  Future<void> markCompleted(String cardId) => _updateCardRow(
    cardId,
    TaskCardsCompanion(
      status: const Value(CardStatus.completed),
      completedAt: Value(_nowMillis),
    ),
  );

  /// 把卡片标回未完成，相当于 `uncompleteCard`（#9）。
  Future<void> markActive(String cardId) => _updateCardRow(
    cardId,
    const TaskCardsCompanion(
      status: Value(CardStatus.active),
      completedAt: Value(null),
    ),
  );

  /// 把卡片放进回收站，相当于 `deleteCard`（#10）。
  Future<void> markDeleted(String cardId) =>
      _updateCardRow(cardId, TaskCardsCompanion(deletedAt: Value(_nowMillis)));

  /// 把卡片从回收站拿出来，相当于 `restoreCard`（#10）。
  Future<void> markRestored(String cardId) =>
      _updateCardRow(cardId, const TaskCardsCompanion(deletedAt: Value(null)));

  /// 把卡片搬到 [dayKey] 那一天，相当于顺延（#12）。
  Future<void> markMovedToDay(String cardId, DayKey dayKey) => _updateCardRow(
    cardId,
    TaskCardsCompanion(dayKey: Value(dayKey.toString())),
  );

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
  bool enabled = false;

  void _throwIfEnabled() {
    if (enabled) throw Exception('模拟的写入失败');
  }

  @override
  Future<int> runInsert(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _throwIfEnabled();
    return super.runInsert(executor, statement, args);
  }

  @override
  Future<int> runUpdate(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _throwIfEnabled();
    return super.runUpdate(executor, statement, args);
  }

  @override
  Future<int> runDelete(
    QueryExecutor executor,
    String statement,
    List<Object?> args,
  ) {
    _throwIfEnabled();
    return super.runDelete(executor, statement, args);
  }
}
