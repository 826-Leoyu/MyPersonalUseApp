/// [PlannerService] 抛出的所有业务错误。
sealed class PlannerException implements Exception {
  const PlannerException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// 找不到要操作的对象。
class NotFound extends PlannerException {
  const NotFound(super.message);
}

/// 输入不合法，例如标题为空。
class InvalidInput extends PlannerException {
  const InvalidInput(super.message);
}

/// 当前状态不允许这个操作，例如在过去的日期新建卡片。
class InvalidState extends PlannerException {
  const InvalidState(super.message);
}

/// 存储读写失败。写操作失败时事务已整体回滚，数据保持不变。
class StorageFailure extends PlannerException {
  const StorageFailure(super.message, [this.cause]);

  final Object? cause;
}
