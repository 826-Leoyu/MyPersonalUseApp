import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/planner_theme.dart';
import '../planner/day_board.dart';
import '../planner/task_card.dart';

/// 一天的画布：卡片按坐标绝对定位显示。只读，卡片的交互由后续任务加。
///
/// 在空白处拖动平移；双指捏合（Android）或 Ctrl+鼠标滚轮（Windows）缩放，
/// 不按 Ctrl 滚动滚轮不缩放。
class BoardCanvas extends StatefulWidget {
  const BoardCanvas({super.key, required this.board});

  /// 卡片组件的 key。
  static Key cardKey(String cardId) => ValueKey('card-$cardId');

  /// 缩放比例的下限和上限（暂定）。
  static const minScale = 0.5;
  static const maxScale = 3.0;

  final DayBoard board;

  @override
  State<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends State<BoardCanvas> {
  final _transform = TransformationController();

  /// 卡片最远处之外再留出的空白，让画布内容区比卡片大一圈。
  static const _canvasPadding = 1000.0;

  /// Ctrl+滚轮缩放的灵敏度：滚动这么多逻辑像素，缩放比例变为 e 倍。
  /// 和 InteractiveViewer 自带的滚轮缩放默认值一样。
  static const _wheelZoomScrollExtent = 200.0;

  /// Ctrl+滚轮：以指针位置为中心缩放，缩放比例限制在上下限以内。
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dy == 0 ||
        !HardwareKeyboard.instance.isControlPressed) {
      return;
    }
    final current = _transform.value.getMaxScaleOnAxis();
    final target =
        (current * math.exp(-event.scrollDelta.dy / _wheelZoomScrollExtent))
            .clamp(BoardCanvas.minScale, BoardCanvas.maxScale);
    final change = target / current;
    final focal = event.localPosition;
    _transform.value = Matrix4.identity()
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(change, change, change, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1)
      ..multiply(_transform.value);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.board.cards;
    final width = cards.fold(0.0, (w, c) => math.max(w, c.x + c.width));
    final height = cards.fold(0.0, (h, c) => math.max(h, c.y + c.height));
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: InteractiveViewer(
        transformationController: _transform,
        constrained: false,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        minScale: BoardCanvas.minScale,
        maxScale: BoardCanvas.maxScale,
        // 关掉 InteractiveViewer 自带的滚轮缩放（每次滚动的缩放倍数变成 1），
        // 改由 _onPointerSignal 只在按住 Ctrl 时缩放。捏合缩放不受影响。
        scaleFactor: double.infinity,
        child: SizedBox(
          width: width + _canvasPadding,
          height: height + _canvasPadding,
          child: Stack(
            children: [for (final card in cards) _CardView(card: card)],
          ),
        ),
      ),
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card});

  final TaskCard card;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      key: BoardCanvas.cardKey(card.id),
      left: card.x,
      top: card.y,
      width: card.width,
      height: card.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(card.colorArgb),
          borderRadius: PlannerTheme.cardRadius,
          boxShadow: PlannerTheme.cardShadow,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            card.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: PlannerTheme.ink),
          ),
        ),
      ),
    );
  }
}
