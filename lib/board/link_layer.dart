import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/planner_theme.dart';
import '../planner/link.dart';
import '../planner/link_geometry.dart';

/// 连线层：在卡片下面画出 [links]，每条线连在两张卡片 [boxes] 最近的边上。
///
/// 第一次显示时已经有的连线直接画好；之后新出现的连线用 [drawDuration] 从起点
/// 画到终点，不再显示的连线（断开、或者一端完成、删除了）停在最后的位置，用
/// [fadeDuration] 淡出。
class LinkLayer extends StatefulWidget {
  const LinkLayer({
    super.key,
    required this.links,
    required this.boxes,
    this.selectedLinkId,
  });

  /// 画连线的 [CustomPaint] 的 key。
  static const paintKey = ValueKey('link-layer');

  static const drawDuration = Duration(milliseconds: 300);
  static const fadeDuration = Duration(milliseconds: 200);

  /// 要显示的连线。
  final List<Link> links;

  /// 卡片 ID → 卡片现在在画布上占的矩形，包括拖动、调整大小时的临时位置和大小。
  final Map<String, CardBox> boxes;

  /// 选中的连线，画粗一点、用强调色。
  final String? selectedLinkId;

  @override
  State<LinkLayer> createState() => _LinkLayerState();
}

class _LinkLayerState extends State<LinkLayer> with TickerProviderStateMixin {
  /// 上一次显示的连线和它们的曲线。
  late Map<String, LinkCurve> _shown;

  /// 正在画出来的连线的动画，值从 0 到 1。画完就去掉。
  final _drawing = <String, AnimationController>{};

  /// 正在淡出的连线：最后一次显示时的样子，和淡出的动画（值从 0 到 1）。
  /// 淡出完就去掉。
  final _fading = <String, ({PaintedLink last, AnimationController fade})>{};

  Map<String, LinkCurve> _curves() => linkCurves(widget.links, widget.boxes);

  @override
  void initState() {
    super.initState();
    // 第一次显示时已经有的连线直接画好，不播动画。
    _shown = _curves();
  }

  @override
  void didUpdateWidget(LinkLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final curves = _curves();
    // 只有增减的连线播动画。画布内容重复推送、或者只是卡片动了，连线没有增减，
    // 不播动画。
    for (final id in _shown.keys.where((id) => !curves.containsKey(id))) {
      _startFading(id, _painted(id, _shown[id]!));
    }
    for (final id in curves.keys.where((id) => !_shown.containsKey(id))) {
      _startDrawing(id);
    }
    _shown = curves;
  }

  /// 一个跑完就自己去掉的动画，每一帧都重画连线层。
  AnimationController _selfDisposingAnimation(
    Duration duration,
    VoidCallback onDone,
  ) {
    final controller = AnimationController(vsync: this, duration: duration);
    controller
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) return;
        setState(onDone);
        controller.dispose();
      });
    return controller;
  }

  void _startDrawing(String id) {
    // 淡出到一半又回来了（比如撤销断开）：不再淡出，重新画出来。
    _fading.remove(id)?.fade.dispose();
    final controller = _selfDisposingAnimation(
      LinkLayer.drawDuration,
      () => _drawing.remove(id),
    );
    _drawing[id] = controller;
    controller.forward();
  }

  void _startFading(String id, PaintedLink last) {
    // 画到一半就不再显示了：停在画到的地方淡出。
    _drawing.remove(id)?.dispose();
    final controller = _selfDisposingAnimation(
      LinkLayer.fadeDuration,
      () => _fading.remove(id),
    );
    _fading[id] = (last: last, fade: controller);
    controller.forward();
  }

  /// 现在显示着的一条连线：画到哪里了、是不是选中。
  PaintedLink _painted(String id, LinkCurve curve) => PaintedLink(
    id: id,
    curve: curve,
    progress: switch (_drawing[id]) {
      final drawing? => Curves.easeOut.transform(drawing.value),
      null => 1,
    },
    selected: id == widget.selectedLinkId,
  );

  @override
  void dispose() {
    for (final controller in _drawing.values) {
      controller.dispose();
    }
    for (final (:fade, last: _) in _fading.values) {
      fade.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: LinkLayer.paintKey,
      painter: LinkPainter([
        for (final (:last, :fade) in _fading.values)
          last.withOpacity(1 - fade.value),
        for (final MapEntry(key: id, value: curve) in _shown.entries)
          _painted(id, curve),
      ]),
    );
  }
}

/// [links] 里两端卡片都在 [boxes] 里的连线，以及它们的曲线，按 [links] 的顺序，
/// 也就是从下到上的绘制顺序。
Map<String, LinkCurve> linkCurves(
  List<Link> links,
  Map<String, CardBox> boxes,
) => {
  for (final link in links)
    if ((boxes[link.fromCardId], boxes[link.toCardId]) case (
      final from?,
      final to?,
    ))
      link.id: linkCurve(from, to),
};

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

  /// 同一条线，换成 [opacity] 的透明度。
  PaintedLink withOpacity(double opacity) => PaintedLink(
    id: id,
    curve: curve,
    progress: progress,
    opacity: opacity,
    selected: selected,
  );
}

/// 连线曲线的路径。
Path _curvePath(LinkCurve curve) => Path()
  ..moveTo(curve.start.x, curve.start.y)
  ..cubicTo(
    curve.control1.x,
    curve.control1.y,
    curve.control2.x,
    curve.control2.y,
    curve.end.x,
    curve.end.y,
  );

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
    final curve = link.curve;
    final full = _curvePath(curve);
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

    final left = wing(_arrowAngle);
    final right = wing(-_arrowAngle);
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(tip.position.dx, tip.position.dy)
        ..lineTo(right.dx, right.dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(LinkPainter oldDelegate) => oldDelegate.links != links;
}

/// 碰撞连线的预览：一条从被拖卡片指向目标卡片的虚线。
class LinkPreviewPainter extends CustomPainter {
  LinkPreviewPainter(this.curve);

  final LinkCurve curve;

  /// 虚线每一段的长度和段间的空隙。
  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _curvePath(curve);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = PlannerTheme.accent;
    for (final metric in path.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += _dash + _gap) {
        canvas.drawPath(metric.extractPath(at, at + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(LinkPreviewPainter oldDelegate) =>
      oldDelegate.curve != curve;
}
