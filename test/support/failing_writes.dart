import 'package:drift/drift.dart';

/// 只用来模拟存储失败，不用来验证调用次数；计数只用来决定从第几次写入开始失败。
class FailingWrites extends QueryInterceptor {
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
