import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/planner_theme.dart';
import '../app/providers.dart';
import '../planner/day_board.dart';
import '../planner/planner_exceptions.dart';
import '../planner/planner_service.dart';
import '../planner/task_card.dart';
import 'board_selection.dart';

/// 一天的画布：卡片按坐标绝对定位显示。
///
/// 在空白处拖动平移；双指捏合（Android）或 Ctrl+鼠标滚轮（Windows）缩放，
/// 不按 Ctrl 滚动滚轮不缩放。双击空白处新建卡片，单击空白处退出编辑、
/// 取消选中。
class BoardCanvas extends ConsumerStatefulWidget {
  const BoardCanvas({
    super.key,
    required this.board,
    required this.canCreateCards,
  });

  /// 卡片组件的 key。
  static Key cardKey(String cardId) => ValueKey('card-$cardId');

  /// 选中的卡片右下角调整大小的手柄的 key。
  static Key resizeHandleKey(String cardId) =>
      ValueKey('resize-handle-$cardId');

  /// 缩放比例的下限和上限（暂定）。
  static const minScale = 0.5;
  static const maxScale = 3.0;

  final DayBoard board;

  /// 能不能在这一天新建卡片。过去的日期不能。
  final bool canCreateCards;

  @override
  ConsumerState<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends ConsumerState<BoardCanvas> {
  final _transform = TransformationController();

  /// 卡片最远处之外再留出的空白，让画布内容区比卡片大一圈。
  static const _canvasPadding = 1000.0;

  /// Ctrl+滚轮缩放的灵敏度：滚动这么多逻辑像素，缩放比例变为 e 倍。
  /// 和 InteractiveViewer 自带的滚轮缩放默认值一样。
  static const _wheelZoomScrollExtent = 200.0;

  /// 最近一次双击空白处的位置（画布可视区域里的坐标）。
  Offset? _doubleTapPosition;

  BoardSelectionController get _selection =>
      ref.read(boardSelectionProvider.notifier);

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

  void _onDoubleTapBlank() {
    final position = _doubleTapPosition;
    if (position == null) return;
    _save(() => _selection.newCardAt(_transform.toScene(position)));
  }

  /// 「＋」：在可视区域中间新建卡片。
  void _onAddCard() {
    final viewport = context.size!;
    final center = viewport.center(Offset.zero);
    _save(() => _selection.newCardAt(_transform.toScene(center)));
  }

  /// 画布内容区，用来把屏幕坐标换算成画布坐标。
  final _contentKey = GlobalKey();

  /// 屏幕上的 [global] 在画布上的坐标，已经算上平移和缩放。
  Offset _globalToCanvas(Offset global) =>
      (_contentKey.currentContext!.findRenderObject()! as RenderBox)
          .globalToLocal(global);

  Future<bool> _resizeCard(TaskCard card, Size size) => _save(() async {
    final service = await ref.read(plannerServiceProvider.future);
    await service.resizeCard(card.id, width: size.width, height: size.height);
  });

  /// 执行一个要保存的操作；保存失败时提示，返回 false。
  Future<bool> _save(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on PlannerException catch (e) {
      if (mounted) {
        final message = e is InvalidInput ? e.message : '保存失败，请重试';
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(message)));
      }
      return false;
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.board.cards;
    final selection = ref.watch(boardSelectionProvider);
    final width = cards.fold(0.0, (w, c) => math.max(w, c.x + c.width));
    final height = cards.fold(0.0, (h, c) => math.max(h, c.y + c.height));
    final canvas = Listener(
      onPointerSignal: _onPointerSignal,
      // 卡片和编辑框在里层，点在它们上面时由它们处理，不算点空白处。
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _save(_selection.tapBlank),
        onDoubleTapDown: widget.canCreateCards
            ? (details) => _doubleTapPosition = details.localPosition
            : null,
        onDoubleTap: widget.canCreateCards ? _onDoubleTapBlank : null,
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
            key: _contentKey,
            width: width + _canvasPadding,
            height: height + _canvasPadding,
            child: Stack(
              children: [
                for (final card in cards)
                  _CardView(
                    key: ValueKey(card.id),
                    card: card,
                    selected:
                        selection is CardSelected &&
                        selection.cardId == card.id,
                    editing:
                        selection is EditingCard && selection.cardId == card.id
                        ? selection
                        : null,
                    onTap: () => _save(() => _selection.tapCard(card)),
                    globalToCanvas: _globalToCanvas,
                    onResize: (size) => _resizeCard(card, size),
                  ),
                if (selection case final EditingNewCard draft)
                  Positioned(
                    left: draft.x,
                    top: draft.y,
                    width: TaskCard.defaultWidth,
                    height: TaskCard.defaultHeight,
                    // 点在新卡片上（包括输入框以外的地方）不算点空白处。
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {},
                      onDoubleTap: () {},
                      child: _CardFrame(
                        colorArgb: TaskCard.defaultColorArgb,
                        child: _CardEditor(editing: draft),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    return Stack(
      children: [
        Positioned.fill(child: canvas),
        if (widget.canCreateCards)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              tooltip: '新建卡片',
              onPressed: _onAddCard,
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }
}

class _CardView extends StatefulWidget {
  const _CardView({
    super.key,
    required this.card,
    required this.selected,
    required this.editing,
    required this.onTap,
    required this.globalToCanvas,
    required this.onResize,
  });

  final TaskCard card;
  final bool selected;

  /// 正在编辑这张卡片时不为 null，卡片上显示编辑框。
  final EditingCard? editing;
  final VoidCallback onTap;

  /// 把屏幕坐标换算成画布坐标。
  final Offset Function(Offset global) globalToCanvas;

  /// 拖完手柄后保存新的大小；保存失败时返回 false。
  final Future<bool> Function(Size size) onResize;

  @override
  State<_CardView> createState() => _CardViewState();
}

class _CardViewState extends State<_CardView> {
  /// 正在拖手柄、或者刚拖完还没保存好时的大小；平时为 null，用卡片自己的大小。
  Size? _resizing;

  /// 按下手柄时，指针离卡片右下角的距离（画布坐标）。
  Offset _grabOffset = Offset.zero;

  /// 是不是正按着手柄在拖。
  bool _dragging = false;

  @override
  void didUpdateWidget(_CardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 保存好的大小从数据库回来了，不再需要临时的大小。
    if (!identical(oldWidget.card, widget.card) && !_dragging) {
      _resizing = null;
    }
  }

  Offset get _corner {
    final card = widget.card;
    final size = _resizing ?? Size(card.width, card.height);
    return Offset(card.x + size.width, card.y + size.height);
  }

  void _onResizeStart(DragStartDetails details) {
    _dragging = true;
    _grabOffset = widget.globalToCanvas(details.globalPosition) - _corner;
  }

  void _onResizeUpdate(DragUpdateDetails details) {
    final card = widget.card;
    final corner = widget.globalToCanvas(details.globalPosition) - _grabOffset;
    setState(() {
      _resizing = Size(
        (corner.dx - card.x).clamp(TaskCard.minWidth, TaskCard.maxWidth),
        (corner.dy - card.y).clamp(TaskCard.minHeight, TaskCard.maxHeight),
      );
    });
  }

  Future<void> _onResizeEnd(DragEndDetails details) async {
    _dragging = false;
    final size = _resizing;
    if (size == null) return;
    final saved = await widget.onResize(size);
    // 保存失败时回到原来的大小。
    if (!saved && mounted) setState(() => _resizing = null);
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final editing = widget.editing;
    return Positioned(
      key: BoardCanvas.cardKey(card.id),
      left: card.x,
      top: card.y,
      width: _resizing?.width ?? card.width,
      height: _resizing?.height ?? card.height,
      child: GestureDetector(
        onTap: widget.onTap,
        // 双击卡片是「完成」，由 #20 接上。现在就注册双击，单击从一开始
        // 就和最终版本一样，等双击判定时间过了才生效。
        onDoubleTap: () {},
        child: Stack(
          children: [
            Positioned.fill(
              child: _CardFrame(
                colorArgb: card.colorArgb,
                child: switch (editing) {
                  final editing? => _CardEditor(editing: editing),
                  null => _CardContent(card: card),
                },
              ),
            ),
            if (widget.selected)
              Positioned(
                right: 0,
                bottom: 0,
                // 拖手柄由手柄自己处理，画布不跟着平移。
                child: GestureDetector(
                  key: BoardCanvas.resizeHandleKey(card.id),
                  dragStartBehavior: DragStartBehavior.down,
                  onPanStart: _onResizeStart,
                  onPanUpdate: _onResizeUpdate,
                  onPanEnd: _onResizeEnd,
                  child: const _ResizeHandle(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 卡片上显示的内容：标题自动换行，超出卡片高度时省略；下面是备注的
/// 第一个非空行，单行省略，字号小一号、颜色淡一些；没有备注时不显示。
class _CardContent extends StatelessWidget {
  const _CardContent({required this.card});

  final TaskCard card;

  /// 备注的第一个非空行；没有时返回 null。
  static String? _firstNoteLine(String? note) {
    if (note == null) return null;
    for (final line in note.split('\n')) {
      if (line.trim().isNotEmpty) return line.trim();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final noteLine = _firstNoteLine(card.note);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: _HeightLimitedText(
            card.title,
            style: textTheme.bodyLarge?.copyWith(color: PlannerTheme.ink),
          ),
        ),
        if (noteLine != null)
          Text(
            noteLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: PlannerTheme.ink.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }
}

/// 自动换行的文字，行数以能放下的高度为限，超出的部分用省略号。
class _HeightLimitedText extends StatelessWidget {
  const _HeightLimitedText(this.text, {required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final line = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        );
        final lineHeight = line.preferredLineHeight;
        line.dispose();
        final maxLines = constraints.maxHeight.isFinite
            ? math.max(1, (constraints.maxHeight / lineHeight).floor())
            : null;
        return Text(
          text,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}

/// 选中的卡片右下角调整大小的手柄。
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle();

  /// 手柄的触摸范围。
  static const size = 28.0;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: size,
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.south_east, size: 16, color: PlannerTheme.accent),
        ),
      ),
    );
  }
}

/// 卡片的底色、圆角、阴影和内边距。
class _CardFrame extends StatelessWidget {
  const _CardFrame({required this.colorArgb, required this.child});

  final int colorArgb;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color(colorArgb),
        borderRadius: PlannerTheme.cardRadius,
        boxShadow: PlannerTheme.cardShadow,
      ),
      child: Padding(padding: const EdgeInsets.all(12), child: child),
    );
  }
}

/// 卡片上的标题和备注编辑框。输入的内容随时写回 [editing]。
class _CardEditor extends StatefulWidget {
  const _CardEditor({required this.editing});

  final Editing editing;

  @override
  State<_CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<_CardEditor> {
  late final _title = TextEditingController(text: widget.editing.title);
  late final _note = TextEditingController(text: widget.editing.note);

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            maxLines: null,
            inputFormatters: [
              LengthLimitingTextInputFormatter(PlannerService.maxTitleLength),
            ],
            style: textTheme.bodyLarge?.copyWith(color: PlannerTheme.ink),
            decoration: const InputDecoration.collapsed(hintText: '标题'),
            onChanged: (value) => widget.editing.title = value,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _note,
            maxLines: null,
            inputFormatters: [
              LengthLimitingTextInputFormatter(PlannerService.maxNoteLength),
            ],
            style: textTheme.bodyMedium?.copyWith(color: PlannerTheme.ink),
            decoration: const InputDecoration.collapsed(hintText: '备注'),
            onChanged: (value) => widget.editing.note = value,
          ),
        ],
      ),
    );
  }
}
