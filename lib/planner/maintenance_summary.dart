/// 一次每日维护做了什么。
class MaintenanceSummary {
  const MaintenanceSummary({
    required this.carriedCount,
    required this.cleanedCount,
  });

  /// 这次顺延到今天的卡片数。
  final int carriedCount;

  /// 这次从回收站永久删除的卡片数。
  // TODO(#12): 实现回收站自动清理后填写真实数量。
  final int cleanedCount;
}
