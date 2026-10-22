import 'package:flutter/material.dart';

import '../app/planner_theme.dart';
import '../formatting/date_format.dart';
import '../planner/card_colors.dart';
import '../planner/carry_over_record.dart';

/// 画布上的一条顺延历史记录：按顺延前的位置和大小、当时的颜色画出来，
/// 不透明度 40%，虚线边框。只读：只接单击和双击（都是跳到卡片现在所在的
/// 日期），不能拖动、编辑、完成、删除或连线。
class CarryOverRecordView extends StatelessWidget {
  const CarryOverRecordView({
    super.key,
    required this.record,
    required this.onTap,
    required this.onPointerDown,
  });

  final CarryOverRecord record;

  /// 单击或双击这条记录。
  final VoidCallback onTap;

  /// 指针在这条记录上按下。
  final VoidCallback onPointerDown;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textColor = Color(cardTextColorArgb(record.colorArgb));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // 双击和单击一样。记录自己接住双击，外面的画布才不会当成双击空白处。
      onDoubleTap: onTap,
      // 长按什么都不做；接住它，松手时才不会被当成单击。
      onLongPress: () {},
      child: Listener(
        onPointerDown: (_) => onPointerDown(),
        child: Opacity(
          opacity: 0.4,
          child: CustomPaint(
            foregroundPainter: _DashedBorderPainter(color: textColor),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(record.colorArgb),
                borderRadius: PlannerTheme.cardRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      record.titleSnapshot,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyLarge?.copyWith(color: textColor),
                    ),
                    Text(
                      '→ 已顺延至 ${formatShortDate(record.toDayKey)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(color: textColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 沿着卡片圆角矩形画的虚线边框。
class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final outline = Path()
      ..addRRect(PlannerTheme.cardRadius.toRRect(Offset.zero & size));
    for (final metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
