import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// 「显示全部卡片」后卡片离可视区域边缘的距离。
const showAllMargin = 24.0;

/// 「显示全部卡片」后画布的平移和缩放：把画布坐标上的 [content] 缩放到正好
/// 放进 [viewport]（四周留出 [showAllMargin]），放在中间。只缩小不放大：
/// 本来放得下时按原大小显示。缩到 [minScale] 也放不下时停在 [minScale]，
/// 放不下的那个方向让开头（左边、上边）对齐。
Matrix4 showAllTransform({
  required Rect content,
  required Size viewport,
  required double minScale,
}) {
  final scale = math.max(
    minScale,
    [
      1.0,
      (viewport.width - 2 * showAllMargin) / content.width,
      (viewport.height - 2 * showAllMargin) / content.height,
    ].reduce(math.min),
  );
  final dx = _place(content.left, content.right, scale, viewport.width);
  final dy = _place(content.top, content.bottom, scale, viewport.height);
  return Matrix4.translationValues(dx, dy, 0)
    ..scaleByDouble(scale, scale, scale, 1);
}

/// 缩放 [scale] 以后，把 [start] 到 [end] 这一段放进 0 到 [extent] 里要平移
/// 多少：放得下时放在中间，放不下时让开头对齐。
double _place(double start, double end, double scale, double extent) {
  final length = (end - start) * scale;
  if (length + 2 * showAllMargin > extent) return showAllMargin - start * scale;
  return (extent - length) / 2 - start * scale;
}
