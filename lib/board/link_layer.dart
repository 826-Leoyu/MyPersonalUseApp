import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/planner_theme.dart';
import '../planner/link.dart';
import '../planner/link_geometry.dart';

/// 连线层：在卡片下面画出 [links]，每条线连在两张卡片 [boxes] 最近的边上。
class LinkLayer extends StatelessWidget {
  const LinkLayer({
    super.key,
    required this.links,
    required this.boxes,
    this.selectedLinkId,
  });

  /// 画连线的 [CustomPaint] 的 key。
  static const paintKey = ValueKey('link-layer');

  /// 要显示的连线。
  final List<Link> links;

  /// 卡片 ID → 卡片现在在画布上占的矩形，包括拖动、调整大小时的临时位置和大小。
  final Map<String, CardBox> boxes;

  /// 选中的连线，画粗一点、用强调色。点击连线由后续任务接上，现在总是 null。
  final String? selectedLinkId;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: paintKey,
      painter: LinkPainter([
        for (final link in links)
          if ((boxes[link.fromCardId], boxes[link.toCardId]) case (
            final from?,
            final to?,
          ))
            PaintedLink(
              id: link.id,
              curve: linkCurve(from, to),
              selected: link.id == selectedLinkId,
            ),
      ]),
    );
  }
}

/// 连线层上的一条线，以及它现在的绘制进度和透明度。
class PaintedLink {
  const PaintedLink({
    required this.id,
    required this.curve,
    this.progress = 1,
    this.opacity = 1,
    this.selected = false,
  });

  final String id;
  final LinkCurve curve;

  /// 从起点画到哪里了：0 是还没画，1 是画完整条线。
  final double progress;

  /// 1 是不透明，0 是完全透明。
  final double opacity;

  final bool selected;
}

/// 画连线：三次贝塞尔曲线，终点（画到哪里就在哪里）画一个细箭头。
class LinkPainter extends CustomPainter {
  LinkPainter(this.links);

  final List<PaintedLink> links;

  /// 箭头两条边的长度和张开的半角。
  static const _arrowLength = 8.0;
  static const _arrowAngle = math.pi / 7;

  @override
  void paint(Canvas canvas, Size size) {
    for (final link in links) {
      _paintLink(canvas, link);
    }
  }

  void _paintLink(Canvas canvas, PaintedLink link) {
    final c = link.curve;
    final full = Path()
      ..moveTo(c.start.x, c.start.y)
      ..cubicTo(
        c.control1.x,
        c.control1.y,
        c.control2.x,
        c.control2.y,
        c.end.x,
        c.end.y,
      );
    final metric = full.computeMetrics().firstOrNull;
    // 两张卡片重叠时曲线缩成一个点，没有可画的。
    if (metric == null || metric.length == 0 || link.progress <= 0) return;
    final drawn = metric.length * link.progress.clamp(0, 1);
    final tip = metric.getTangentForOffset(drawn);
    if (tip == null) return;

    final color = link.selected ? PlannerTheme.accent : PlannerTheme.linkColor;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = link.selected ? 3 : 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color.withValues(alpha: color.a * link.opacity);
    canvas.drawPath(metric.extractPath(0, drawn), paint);

    // 箭头沿笔尖处的切线方向，两条边往回张开。
    final back = -tip.vector;
    Offset wing(double angle) {
      final rotated = Offset(
        back.dx * math.cos(angle) - back.dy * math.sin(angle),
        back.dx * math.sin(angle) + back.dy * math.cos(angle),
      );
      return tip.position + rotated * _arrowLength;
    }

    canvas.drawPath(
      Path()
        ..moveTo(wing(_arrowAngle).dx, wing(_arrowAngle).dy)
        ..lineTo(tip.position.dx, tip.position.dy)
        ..lineTo(wing(-_arrowAngle).dx, wing(-_arrowAngle).dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(LinkPainter oldDelegate) => oldDelegate.links != links;
}
