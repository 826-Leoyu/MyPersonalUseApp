/// 某一天的任务数量，给日期抽屉用。都不包含回收站里的卡片和历史记录。
class DayCounts {
  const DayCounts({required this.activeCount, required this.completedCount});

  /// 未完成的卡片数。
  final int activeCount;

  /// 已完成的卡片数。
  final int completedCount;
}
