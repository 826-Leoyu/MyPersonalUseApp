import 'carry_over_record.dart';
import 'link.dart';
import 'task_card.dart';

/// 某一天画布上要显示的内容。
class DayBoard {
  const DayBoard({
    required this.cards,
    required this.links,
    required this.carryOverRecords,
    required this.completedCount,
  });

  /// 显示在画布上的卡片：未完成、不在回收站，按 zIndex 从下到上排列。
  final List<TaskCard> cards;

  /// 显示在画布上的连线，按建立时间排列，也就是从下到上画的顺序。
  final List<Link> links;

  /// 从这一天顺延走的卡片留下的历史记录，按顺延时间排列。
  final List<CarryOverRecord> carryOverRecords;

  /// 这一天已完成、不在回收站的卡片数。
  final int completedCount;
}
