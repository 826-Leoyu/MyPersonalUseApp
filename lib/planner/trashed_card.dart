import 'task_card.dart';

/// 回收站里的一张卡片。
class TrashedCard {
  const TrashedCard({required this.card, required this.daysLeft});

  final TaskCard card;

  /// 还剩几天会被永久删除。
  final int daysLeft;
}
