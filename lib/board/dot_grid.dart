import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../app/planner_theme.dart';

/// 画布背景的点阵，像 iPhone 备忘录、无边记那样：画布坐标上每隔
/// [PlannerTheme.dotSpacing] 一个点，跟着 [transform] 平移和缩放，看起来点是
/// 画在画布上的；点的大小不随缩放变（[PlannerTheme.dotRadius]）。只画可视
/// 区域里的点，不接收点击。
class DotGrid extends StatelessWidget {
  const DotGrid({super.key, required this.transform});

  /// 画布的平移和缩放。
  final TransformationController transform;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _DotGridPainter(transform, PlannerColors.of(context).gridDot),
      size: Size.infinite,
    ),
  );
}

/// 可视区域 [size] 里每个点的位置（屏幕坐标），一行一行从左上往右下排。
/// [transform] 是画布坐标到屏幕坐标的变换，只用平移和统一的缩放。
Iterable<Offset> dotGridPositions(Size size, Matrix4 transform) sync* {
  final scale = transform.getMaxScaleOnAxis();
  final step = PlannerTheme.dotSpacing * scale;
  final translation = transform.getTranslation();
  // 第一个点：原点那个点往左上挪整数个间距，挪到不小于 0 的最小位置。
  final startX = translation.x % step;
  final startY = translation.y % step;
  for (var y = startY; y < size.height; y += step) {
    for (var x = startX; x < size.width; x += step) {
      yield Offset(x, y);
    }
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.transform, this.color) : super(repaint: transform);

  final TransformationController transform;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // 缩小时一屏有上万个点，一次 drawPoints 画完，不逐个 drawCircle；圆头的
    // 线宽就是点的直径。
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2 * PlannerTheme.dotRadius
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(
      PointMode.points,
      dotGridPositions(size, transform.value).toList(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) =>
      oldDelegate.transform != transform || oldDelegate.color != color;
}
