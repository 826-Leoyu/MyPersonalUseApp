import 'package:flutter/material.dart';

import '../app/planner_theme.dart';

/// 画布背景的点阵，像 iPhone 备忘录、无边记那样：画布坐标上每隔 [spacing]
/// 一个点，跟着 [transform] 平移和缩放，看起来点是画在画布上的。只画可视
/// 区域里的点，不接收点击。
class DotGrid extends StatelessWidget {
  const DotGrid({super.key, required this.transform});

  /// 点的间距（画布坐标）。
  static const spacing = 24.0;

  /// 画布的平移和缩放。
  final TransformationController transform;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      painter: _DotGridPainter(transform),
      size: Size.infinite,
    ),
  );
}

/// 可视区域 [size] 里每个点的位置（屏幕坐标），一行一行从左上往右下排。
/// [transform] 是画布坐标到屏幕坐标的变换，只用平移和统一的缩放。
Iterable<Offset> dotGridPositions(Size size, Matrix4 transform) sync* {
  final scale = transform.getMaxScaleOnAxis();
  final step = DotGrid.spacing * scale;
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
  _DotGridPainter(this.transform) : super(repaint: transform);

  final TransformationController transform;

  /// 点的半径（屏幕上的逻辑像素），缩放时不变。
  static const _radius = 1.25;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = PlannerTheme.dot;
    for (final dot in dotGridPositions(size, transform.value)) {
      canvas.drawCircle(dot, _radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter oldDelegate) =>
      oldDelegate.transform != transform;
}
