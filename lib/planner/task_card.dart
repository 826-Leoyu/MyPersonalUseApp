import 'day_key.dart';

/// 卡片状态：未完成或已完成。在回收站里由 [TaskCard.deletedAt] 表示。
enum CardStatus { active, completed }

/// 一张任务卡片。这是全局唯一的有效任务；时间都是 UTC。
class TaskCard {
  const TaskCard({
    required this.id,
    required this.dayKey,
    required this.title,
    required this.note,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.zIndex,
    required this.colorArgb,
    required this.status,
    required this.completedAt,
    required this.carriedOver,
    required this.originalDayKey,
    required this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  static const defaultColorArgb = 0xFFFFF3B0;
  static const defaultWidth = 180.0;
  static const defaultHeight = 88.0;
  static const minWidth = 120.0;
  static const minHeight = 60.0;
  static const maxWidth = 600.0;
  static const maxHeight = 400.0;

  final String id;

  /// 卡片现在属于哪一天。
  final DayKey dayKey;
  final String title;
  final String? note;
  final double x;
  final double y;
  final double width;
  final double height;
  final int zIndex;
  final int colorArgb;
  final CardStatus status;
  final DateTime? completedAt;
  final bool carriedOver;

  /// 卡片最初被创建在哪一天，顺延后不变。
  final DayKey originalDayKey;

  /// 有值就表示在回收站里。
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// 卡片现在在哪里：给点击历史记录跳转用。
class CardLocation {
  const CardLocation({
    required this.dayKey,
    required this.status,
    required this.inTrash,
  });

  final DayKey dayKey;
  final CardStatus status;
  final bool inTrash;
}
