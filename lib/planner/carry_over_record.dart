import 'day_key.dart';

/// 卡片顺延时在出发那一天留下的只读快照；时间都是 UTC。
///
/// 它不是有效任务：不计入任何数量，也不能完成、删除或连线。
class CarryOverRecord {
  const CarryOverRecord({
    required this.id,
    required this.cardId,
    required this.fromDayKey,
    required this.toDayKey,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.titleSnapshot,
    required this.colorArgb,
    required this.carriedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// 被顺延的卡片。点击记录时跳到这张卡片当前的日期，而不是 [toDayKey]。
  final String cardId;

  /// 顺延前卡片所在的日期，也就是这条记录显示在哪一天。
  final DayKey fromDayKey;

  /// 这次顺延到了哪一天。
  final DayKey toDayKey;

  /// 顺延前在原画布上的位置和大小。
  final double x;
  final double y;
  final double width;
  final double height;

  /// 顺延时的标题和颜色。
  final String titleSnapshot;
  final int colorArgb;
  final DateTime carriedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}
