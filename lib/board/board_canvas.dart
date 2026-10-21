import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/planner_theme.dart';
import '../app/providers.dart';
import '../planner/card_colors.dart';
import '../planner/day_board.dart';
import '../planner/link_geometry.dart';
import '../planner/planner_exceptions.dart';
import '../planner/planner_service.dart';
import '../planner/task_card.dart';
import 'board_selection.dart';
import 'card_color_dialog.dart';
import 'card_drag.dart';
import 'link_layer.dart';

/// 一天的画布：卡片按坐标绝对定位显示。
///
/// 按住卡片拖动移动它，在空白处拖动平移；双指捏合（Android）或 Ctrl+鼠标滚轮（Windows）缩放，
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

  /// 拖着卡片停在另一张没连上的卡片上时，虚线连线预览的 key。
  static const linkPreviewKey = ValueKey('link-preview');

  /// 拖着卡片停在另一张已连上的卡片上时，✂️ 断开预览的 key。
  static const unlinkPreviewKey = ValueKey('unlink-preview');

  /// 连线或断开后，被拖的卡片弹回起点的时长。
  static const bounceDuration = Duration(milliseconds: 250);

  /// 缩放比例的下限和上限（暂定）。
  static const minScale = 0.5;
  static const maxScale = 3.0;

  final DayBoard board;

  /// 能不能在这一天新建卡片。过去的日期不能。
  final bool canCreateCards;

  @override
  ConsumerState<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends ConsumerState<BoardCanvas>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();

  /// 卡片最远处之外再留出的空白，让画布内容区比卡片大一圈。
  static const _canvasPadding = 1000.0;

  /// Ctrl+滚轮缩放的灵敏度：滚动这么多逻辑像素，缩放比例变为 e 倍。
  /// 和 InteractiveViewer 自带的滚轮缩放默认值一样。
  static const _wheelZoomScrollExtent = 200.0;

  /// 最近一次双击空白处的位置（画布可视区域里的坐标）。
  Offset? _doubleTapPosition;

  /// 拖动卡片的状态机，和正在拖卡片的指针。
  final _drag = CardDragMachine();
  int? _dragPointerId;

  /// 给拖动状态机计时。测试里跟着假时间走。
  final _dragClock = clock.stopwatch()..start();

  /// 指针停在另一张卡片上时，到 400ms 把拖动状态机推进到 armed 的计时器，
  /// 和它对应的开始悬停的时间。
  Timer? _armTimer;
  Duration? _armTimerSince;

  /// 连线或断开后弹回起点的卡片：从松手的位置 [from] 弹回 [to]。
  ({String cardId, Offset from, Offset to})? _bounce;
  late final _bounceAnimation =
      AnimationController(vsync: this, duration: BoardCanvas.bounceDuration)
        ..addListener(() => setState(() {}))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() => _bounce = null);
          }
        });

  /// 松手后正在保存的新位置；保存好的位置从数据库回来后清掉。
  CardDrop? _dropping;

  /// 正在拖手柄、或者刚拖完还没保存好的卡片的临时大小；保存好的大小从数据库
  /// 回来后清掉。连线也跟着这个大小。
  final _resizing = <String, Size>{};

  /// 正按着手柄在拖的卡片。
  String? _resizeHandleCardId;

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

  /// 长按卡片（Windows 上也可以右键）：在 [global] 处弹出卡片菜单。
  Future<void> _openCardMenu(TaskCard card, Offset global) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final at = overlay.globalToLocal(global);
    final action = await showMenu<_CardMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        at & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem(value: _CardMenuAction.recolor, child: Text('改颜色')),
        PopupMenuItem(value: _CardMenuAction.edit, child: Text('编辑')),
        PopupMenuItem(value: _CardMenuAction.delete, child: Text('删除')),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _CardMenuAction.recolor:
        await showCardColorDialog(
          context,
          currentArgb: card.colorArgb,
          onPick: (argb) => _save(() async {
            final service = await ref.read(plannerServiceProvider.future);
            await service.setCardColor(card.id, argb);
          }),
        );
      case _CardMenuAction.edit:
        await _save(() => _selection.editCard(card));
      case _CardMenuAction.delete:
        await _save(() => _selection.deleteCard(card.id));
    }
  }

  void _onResizeUpdate(TaskCard card, Size size) =>
      setState(() => _resizing[card.id] = size);

  /// 松开手柄：保存新的大小。保存失败时回到原来的大小。
  Future<void> _onResizeEnd(TaskCard card) async {
    _resizeHandleCardId = null;
    final size = _resizing[card.id];
    if (size == null) return;
    final saved = await _save(() async {
      final service = await ref.read(plannerServiceProvider.future);
      await service.resizeCard(card.id, width: size.width, height: size.height);
    });
    if (!saved && mounted) setState(() => _resizing.remove(card.id));
  }

  /// 按在卡片上的指针事件交给拖动状态机。同一时间只跟踪一个指针。
  void _onCardPointer(TaskCard card, PointerEvent event) {
    switch (event) {
      case PointerDownEvent() when _dragPointerId == null:
        // 桌面上只有鼠标左键能拖；触摸也算左键。
        if (event.buttons != kPrimaryButton) return;
        _dragPointerId = event.pointer;
        _drag.down(
          card.id,
          origin: Offset(card.x, card.y),
          pointer: _globalToCanvas(event.position),
          // 判定距离是屏幕上的距离，换算成画布上的距离。
          slop:
              computePanSlop(
                event.kind,
                MediaQuery.maybeGestureSettingsOf(context),
              ) /
              _transform.value.getMaxScaleOnAxis(),
        );
      case PointerMoveEvent() when event.pointer == _dragPointerId:
        setState(
          () => _drag.move(
            _globalToCanvas(event.position),
            cards: _cardBoxes(),
            now: _dragClock.elapsed,
          ),
        );
        _syncArmTimer();
      case PointerUpEvent() when event.pointer == _dragPointerId:
        _dragPointerId = null;
        final release = _drag.up();
        _syncArmTimer();
        switch (release) {
          case CardMoved(:final drop):
            _moveCard(drop);
          case final CardLinkToggled toggled:
            _toggleLink(toggled);
          case null:
            setState(() {});
        }
      case PointerCancelEvent() when event.pointer == _dragPointerId:
        _onCardDragCancel();
    }
  }

  /// 卡片的手势被别的操作抢走（比如捏合缩放画布）：卡片回到原处。
  void _onCardDragCancel() {
    _dragPointerId = null;
    setState(_drag.cancel);
    _syncArmTimer();
  }

  /// 让计时器跟上拖动状态：开始悬停时计时，到 400ms 推进到 armed；
  /// 不再悬停（离开、armed、松手）时停掉。
  void _syncArmTimer() {
    final since = switch (_drag.state) {
      CardHovering(:final since) => since,
      _ => null,
    };
    if (since == _armTimerSince) return;
    _armTimer?.cancel();
    _armTimer = null;
    _armTimerSince = since;
    if (since == null) return;
    _armTimer = Timer(
      CardDragMachine.armDelay - (_dragClock.elapsed - since),
      () {
        setState(() => _drag.tick(_dragClock.elapsed));
        _syncArmTimer();
      },
    );
  }

  /// 在另一张卡片上松手：切换两张卡片之间的连线，被拖的卡片弹回起点。
  /// 成功时 Android 手机轻微振动。
  Future<void> _toggleLink(CardLinkToggled release) async {
    setState(
      () => _bounce = (
        cardId: release.cardId,
        from: release.releasedAt,
        to: release.origin,
      ),
    );
    _bounceAnimation.forward(from: 0);
    final saved = await _save(() async {
      final service = await ref.read(plannerServiceProvider.future);
      await service.toggleLink(release.cardId, release.targetId);
    });
    if (saved && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  /// 卡片现在显示的位置和它们的 ID：正在拖、正在保存新位置、正在弹回的卡片
  /// 用临时位置，其余的不在这里。
  Map<String, Offset> _liftedPositions() {
    final bounce = _bounce;
    return {
      if (bounce != null)
        bounce.cardId: Offset.lerp(
          bounce.from,
          bounce.to,
          Curves.easeOutCubic.transform(_bounceAnimation.value),
        )!,
      if (_dropping case (:final cardId, :final position)) cardId: position,
      if (_drag.dragged case (:final cardId, :final position)) cardId: position,
    };
  }

  /// 卡片现在在画布上占的矩形，算上临时的位置和大小，按从下到上的顺序。
  /// 卡片、连线和碰撞判断都按它来。
  Map<String, CardBox> _cardBoxes() {
    final lifted = _liftedPositions();
    final cards = widget.board.cards;
    return {
      for (final card in [
        ...cards.where((c) => !lifted.containsKey(c.id)),
        ...cards.where((c) => lifted.containsKey(c.id)),
      ])
        card.id: (
          x: lifted[card.id]?.dx ?? card.x,
          y: lifted[card.id]?.dy ?? card.y,
          width: _resizing[card.id]?.width ?? card.width,
          height: _resizing[card.id]?.height ?? card.height,
        ),
    };
  }

  /// 保存拖动后的位置。保存好之前卡片停在新位置；保存失败时回到原处。
  Future<void> _moveCard(CardDrop drop) async {
    final (:cardId, :position) = drop;
    setState(() => _dropping = drop);
    final saved = await _save(() async {
      final service = await ref.read(plannerServiceProvider.future);
      await service.moveCard(cardId, x: position.dx, y: position.dy);
    });
    // 只清自己这张；保存期间可能又拖了另一张卡片。
    if (!saved && mounted && _dropping?.cardId == cardId) {
      setState(() => _dropping = null);
    }
  }

  @override
  void didUpdateWidget(BoardCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cards = {for (final c in widget.board.cards) c.id: c};
    final oldCards = {for (final c in oldWidget.board.cards) c.id: c};
    // 保存好的位置从数据库回来了，不再需要临时的位置。
    if (_dropping case (:final cardId, :final position)) {
      final card = cards[cardId];
      if (card == null || Offset(card.x, card.y) == position) _dropping = null;
    }
    // 保存好的大小从数据库回来了，不再需要临时的大小。正按着手柄的卡片除外。
    _resizing.removeWhere((cardId, _) {
      if (cardId == _resizeHandleCardId) return false;
      final card = cards[cardId];
      return card == null || !identical(card, oldCards[cardId]);
    });
  }

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

  /// 准备连线时的预览，画在卡片上面：没连上时是一条虚线，已经连上时在两张
  /// 卡片之间显示 ✂️。
  List<Widget> _armedPreview(CardArmed armed, Map<String, CardBox> boxes) {
    final (from, to) = (boxes[armed.cardId], boxes[armed.targetId]);
    if (from == null || to == null) return const [];
    final curve = linkCurve(from, to);
    final linked = widget.board.links.any(
      (l) =>
          (l.fromCardId == armed.cardId && l.toCardId == armed.targetId) ||
          (l.fromCardId == armed.targetId && l.toCardId == armed.cardId),
    );
    if (!linked) {
      return [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              key: BoardCanvas.linkPreviewKey,
              painter: LinkPreviewPainter(curve),
            ),
          ),
        ),
      ];
    }
    final middle = linkCurveMidpoint(curve);
    const size = 32.0;
    return [
      Positioned(
        key: BoardCanvas.unlinkPreviewKey,
        left: middle.x - size / 2,
        top: middle.y - size / 2,
        width: size,
        height: size,
        child: const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: PlannerTheme.accent,
              shape: BoxShape.circle,
              boxShadow: PlannerTheme.cardShadow,
            ),
            child: Icon(Icons.content_cut, size: 18, color: Colors.white),
          ),
        ),
      ),
    ];
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    _bounceAnimation.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.board.cards;
    final selection = ref.watch(boardSelectionProvider);
    // 正在拖动、刚松手还在保存、或者正在弹回的卡片显示在临时位置，画在所有
    // 卡片上面。
    final boxes = _cardBoxes();
    final cardsById = {for (final c in cards) c.id: c};
    final ordered = [for (final id in boxes.keys) cardsById[id]!];
    final armed = switch (_drag.state) {
      final CardArmed armed => armed,
      _ => null,
    };
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
                // 连线画在所有卡片下面，不参与点击。
                Positioned.fill(
                  child: IgnorePointer(
                    child: LinkLayer(links: widget.board.links, boxes: boxes),
                  ),
                ),
                for (final card in ordered)
                  _CardView(
                    key: ValueKey(card.id),
                    card: card,
                    armedTarget: card.id == armed?.targetId,
                    selected:
                        selection is CardSelected &&
                        selection.cardId == card.id,
                    editing:
                        selection is EditingCard && selection.cardId == card.id
                        ? selection
                        : null,
                    box: boxes[card.id]!,
                    onTap: () => _save(() => _selection.tapCard(card)),
                    onDragPointer: (event) => _onCardPointer(card, event),
                    onDragCancel: _onCardDragCancel,
                    onMenu: (global) => _openCardMenu(card, global),
                    globalToCanvas: _globalToCanvas,
                    onResizeStart: () => _resizeHandleCardId = card.id,
                    onResizeUpdate: (size) => _onResizeUpdate(card, size),
                    onResizeEnd: () => _onResizeEnd(card),
                  ),
                if (armed != null) ..._armedPreview(armed, boxes),
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
                        builder: (textColor) =>
                            _CardEditor(editing: draft, textColor: textColor),
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

/// 卡片菜单里的操作。
enum _CardMenuAction { recolor, edit, delete }

class _CardView extends StatefulWidget {
  const _CardView({
    super.key,
    required this.card,
    required this.armedTarget,
    required this.selected,
    required this.editing,
    required this.box,
    required this.onTap,
    required this.onDragPointer,
    required this.onDragCancel,
    required this.onMenu,
    required this.globalToCanvas,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
  });

  final TaskCard card;

  /// 拖着另一张卡片停在这张上面、松手就会连线或断开：放大并发光。
  final bool armedTarget;

  final bool selected;

  /// 正在编辑这张卡片时不为 null，卡片上显示编辑框。
  final EditingCard? editing;

  /// 卡片现在在画布上占的矩形，包括拖动、调整大小时的临时位置和大小。
  final CardBox box;

  final VoidCallback onTap;

  /// 按在卡片上的指针事件，交给画布的拖动状态机。
  final void Function(PointerEvent event) onDragPointer;

  /// 卡片的手势被别的操作抢走了。
  final VoidCallback onDragCancel;

  /// 长按或右键卡片，[global] 是按下的位置（屏幕坐标）。
  final void Function(Offset global) onMenu;

  /// 把屏幕坐标换算成画布坐标。
  final Offset Function(Offset global) globalToCanvas;

  /// 按下手柄、拖动手柄（[size] 是新的大小，已经限制在上下限以内）、松开手柄。
  final VoidCallback onResizeStart;
  final void Function(Size size) onResizeUpdate;
  final VoidCallback onResizeEnd;

  @override
  State<_CardView> createState() => _CardViewState();
}

class _CardViewState extends State<_CardView> {
  /// 按下手柄时，指针离卡片右下角的距离（画布坐标）。
  Offset _grabOffset = Offset.zero;

  Offset get _corner {
    final box = widget.box;
    return Offset(box.x + box.width, box.y + box.height);
  }

  void _onResizeStart(DragStartDetails details) {
    _grabOffset = widget.globalToCanvas(details.globalPosition) - _corner;
    widget.onResizeStart();
  }

  void _onResizeUpdate(DragUpdateDetails details) {
    final box = widget.box;
    final corner = widget.globalToCanvas(details.globalPosition) - _grabOffset;
    widget.onResizeUpdate(
      Size(
        (corner.dx - box.x).clamp(TaskCard.minWidth, TaskCard.maxWidth),
        (corner.dy - box.y).clamp(TaskCard.minHeight, TaskCard.maxHeight),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final editing = widget.editing;
    // 正在编辑的卡片不能拖。
    final onDragPointer = editing == null ? widget.onDragPointer : null;
    // 长按（Windows 上也可以右键）弹出菜单。正在编辑的卡片不弹，
    // 在编辑框里长按、右键是选文字和文字菜单。
    final onMenu = editing == null ? widget.onMenu : null;
    return Positioned(
      key: BoardCanvas.cardKey(card.id),
      left: widget.box.x,
      top: widget.box.y,
      width: widget.box.width,
      height: widget.box.height,
      child: AnimatedScale(
        scale: widget.armedTarget ? 1.05 : 1,
        duration: const Duration(milliseconds: 120),
        child: GestureDetector(
          onTap: widget.onTap,
          // 双击卡片是「完成」，由 #20 接上。现在就注册双击，单击从一开始
          // 就和最终版本一样，等双击判定时间过了才生效。
          onDoubleTap: () {},
          onLongPressStart: onMenu == null
              ? null
              : (details) => onMenu(details.globalPosition),
          onSecondaryTapUp: onMenu == null
              ? null
              : (details) => onMenu(details.globalPosition),
          // 拖动由拖动状态机处理，这里只用来抢下手势，画布不跟着平移。
          // 正在编辑的卡片不能拖，在编辑框里拖动是选文字。
          onPanStart: editing == null ? (_) {} : null,
          onPanCancel: editing == null ? widget.onDragCancel : null,
          child: Stack(
            children: [
              Positioned.fill(
                // 手柄盖在卡片上面，按在手柄上不会走到这里。
                child: Listener(
                  onPointerDown: onDragPointer,
                  onPointerMove: onDragPointer,
                  onPointerUp: onDragPointer,
                  onPointerCancel: onDragPointer,
                  child: _CardFrame(
                    colorArgb: card.colorArgb,
                    glow: widget.armedTarget,
                    builder: (textColor) => switch (editing) {
                      final editing? => _CardEditor(
                        editing: editing,
                        textColor: textColor,
                      ),
                      null => _CardContent(card: card, textColor: textColor),
                    },
                  ),
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
                    onPanEnd: (_) => widget.onResizeEnd(),
                    child: const _ResizeHandle(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 卡片上显示的内容：标题自动换行，超出卡片高度时省略；下面是备注的
/// 第一个非空行，单行省略，字号小一号、颜色淡一些；没有备注时不显示。
class _CardContent extends StatelessWidget {
  const _CardContent({required this.card, required this.textColor});

  final TaskCard card;
  final Color textColor;

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
            style: textTheme.bodyLarge?.copyWith(color: textColor),
          ),
        ),
        if (noteLine != null)
          Text(
            noteLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: textColor.withValues(alpha: 0.6),
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
  const _CardFrame({
    required this.colorArgb,
    required this.builder,
    this.glow = false,
  });

  final int colorArgb;

  /// 外面加一圈强调色的光晕。
  final bool glow;

  /// 卡片里的内容，拿到按底色决定的文字颜色（见 [cardTextColorArgb]）。
  final Widget Function(Color textColor) builder;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color(colorArgb),
        borderRadius: PlannerTheme.cardRadius,
        boxShadow: glow
            ? [
                ...PlannerTheme.cardShadow,
                BoxShadow(
                  color: PlannerTheme.accent.withValues(alpha: 0.6),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ]
            : PlannerTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: builder(Color(cardTextColorArgb(colorArgb))),
      ),
    );
  }
}

/// 卡片上的标题和备注编辑框。输入的内容随时写回 [editing]。
class _CardEditor extends StatefulWidget {
  const _CardEditor({required this.editing, required this.textColor});

  final Editing editing;
  final Color textColor;

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
    final textColor = widget.textColor;
    final hintStyle = TextStyle(color: textColor.withValues(alpha: 0.5));
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
            style: textTheme.bodyLarge?.copyWith(color: textColor),
            decoration: InputDecoration.collapsed(
              hintText: '标题',
              hintStyle: hintStyle,
            ),
            onChanged: (value) => widget.editing.title = value,
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _note,
            maxLines: null,
            inputFormatters: [
              LengthLimitingTextInputFormatter(PlannerService.maxNoteLength),
            ],
            style: textTheme.bodyMedium?.copyWith(color: textColor),
            decoration: InputDecoration.collapsed(
              hintText: '备注',
              hintStyle: hintStyle,
            ),
            onChanged: (value) => widget.editing.note = value,
          ),
        ],
      ),
    );
  }
}
