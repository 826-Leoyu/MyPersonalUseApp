import 'task_card.dart';

/// 某一天画布上要显示的内容。
class DayBoard {
  const DayBoard({required this.cards});

  /// 显示在画布上的卡片：未完成、不在回收站，按 zIndex 从下到上排列。
  final List<TaskCard> cards;
}
