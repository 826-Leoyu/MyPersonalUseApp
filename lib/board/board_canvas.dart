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
import '../planner/carry_over_record.dart';
import '../planner/day_board.dart';
import '../planner/link_geometry.dart';
import '../planner/planner_exceptions.dart';
import '../planner/planner_service.dart';
import '../planner/task_card.dart';
import 'board_selection.dart';
import 'card_color_dialog.dart';
import 'card_drag.dart';
import 'carry_over_record_view.dart';
import 'completed_page.dart';
import 'date_bar.dart';
import 'drop_zones.dart';
import 'link_layer.dart';
import 'undo_delete_notice.dart';

/// 一天的画布：卡片按坐标绝对定位显示。
///
/// 按住卡片拖动移动它，在空白处拖动平移；双指捏合（Android）或 Ctrl+鼠标滚轮（Windows）缩放，
/// 不按 Ctrl 滚动滚轮不缩放。双击空白处新建卡片，单击空白处退出编辑、
/// 取消选中。
///
/// 画布带着页面的 Scaffold：「＋」放在 Scaffold 的悬浮按钮位置，提示出现时
/// 由 Scaffold 把它让到提示上面，两者不会互相遮挡。
class BoardCanvas extends ConsumerStatefulWidget {
  const BoardCanvas({
    super.key,
    required this.appBar,
    required this.board,
    required this.canCreateCards,
    required this.transform,
  });

  /// 卡片组件的 key。
  static Key cardKey(String cardId) => ValueKey('card-$cardId');

  /// 顺延历史记录组件的 key。
  static Key carryOverRecordKey(String recordId) =>
      ValueKey('carry-over-record-$recordId');

  /// 顺延过的卡片右上角「顺延」标记的 key。
  static Key carriedOverTagKey(String cardId) =>
      ValueKey('carried-over-tag-$cardId');

  /// 选中的卡片右下角调整大小的手柄的 key。
  static Key resizeHandleKey(String cardId) =>
      ValueKey('resize-handle-$cardId');

  /// 拖着卡片停在另一张没连上的卡片上时，虚线连线预览的 key。
  static const linkPreviewKey = ValueKey('link-preview');

  /// 拖着卡片停在另一张已连上的卡片上时，✂️ 断开预览的 key。
  static const unlinkPreviewKey = ValueKey('unlink-preview');

  /// 选中的连线中点上 ✂️ 按钮的 key。
  static const linkScissorsKey = ValueKey('link-scissors');

  /// 连线或断开后，被拖的卡片弹回起点的时长。
  static const bounceDuration = Duration(milliseconds: 250);

  /// 完成时卡片打勾消失的时长。
  static const completeDuration = Duration(milliseconds: 200);

  /// 删除后撤销提示显示的时长。
  static const undoDuration = Duration(seconds: 4);

  /// 正在完成的卡片上的 ✓ 的 key。
  static const completeCheckKey = ValueKey('complete-check');

  /// 缩放比例的下限和上限（暂定）。
  static const minScale = 0.5;
  static const maxScale = 3.0;

  /// 页面顶部的标题栏。
  final PreferredSizeWidget appBar;

  final DayBoard board;

  /// 能不能在这一天新建卡片。过去的日期不能。
  final bool canCreateCards;

  /// 画布的平移和缩放。由页面持有，换一天时沿用，不跟着画布重建。
  final TransformationController transform;

  @override
  ConsumerState<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends ConsumerState<BoardCanvas>
    with SingleTickerProviderStateMixin {
  TransformationController get _transform => widget.transform;

  /// 卡片最远处之外再留出的空白，让画布内容区比卡片大一圈。
  static const _canvasPadding = 1000.0;

  /// ✂️ 按钮的点击范围（屏幕上的逻辑像素）。
  static const _scissorsHitSize = 44.0;

  /// Ctrl+滚轮缩放的灵敏度：滚动这么多逻辑像素，缩放比例变为 e 倍。
  /// 和 InteractiveViewer 自带的滚轮缩放默认值一样。
  static const _wheelZoomScrollExtent = 200.0;

  /// 最近一次双击空白处的位置（画布可视区域里的坐标）。
  Offset? _doubleTapPosition;

  /// 最近一次双击连线的位置（画布坐标）。
  Offset? _linkDoubleTapPosition;

  /// 按下时落在了连线、卡片、新卡片还是历史记录上：[_downOn] 是这一次按下，
  /// [_lastDownOn]、[_previousDownOn] 是最近一次和上一次按下；都没落在上面时
  /// 为 null。双击的第一下按在它们上面、第二下偏出去落在空白处时，外面的画布
  /// 会认成双击空白处，靠它们认出来，改成双击那条连线、那张卡片、新卡片或
  /// 历史记录。
  _DownTarget? _downOn;
  _DownTarget? _lastDownOn;
  _DownTarget? _previousDownOn;

  /// 拖动卡片的状态机，和正在拖卡片的指针。
  late final _drag = CardDragMachine(
    isLinked: (cardId, otherId) => widget.board.links.any(
      (l) =>
          (l.fromCardId == cardId && l.toCardId == otherId) ||
          (l.fromCardId == otherId && l.toCardId == cardId),
    ),
  );
  int? _dragPointerId;

  /// 拖动时底部的投放区，按屏幕坐标判断指针在哪个区里。
  final _dropZones = DropZoneLocator();

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

  /// 正在完成或删除、从画布上退场的卡片。保存失败时清掉，卡片回到原处；
  /// 保存成功后等卡片从数据库的画布内容里消失、退场动画也结束了再清掉。
  final _leaving = <String, _Leaving>{};

  /// 正在拖手柄、或者刚拖完还没保存好的卡片的临时大小；保存好的大小从数据库
  /// 回来后清掉。连线也跟着这个大小。
  final _resizing = <String, Size>{};

  /// 正按着手柄在拖的卡片。
  String? _resizeHandleCardId;

  BoardSelectionController get _selection =>
      ref.read(boardSelectionProvider.notifier);

  /// 不在编辑时接住快捷键的焦点。编辑时焦点在编辑框里，快捷键从编辑框
  /// 往上传到这里。
  final _keyboardFocus = FocusNode(debugLabel: '画布快捷键');

  /// 让画布接住快捷键：退出编辑后编辑框的焦点没了，要拿回来。上面盖着
  /// 别的页面或菜单时不抢它们的焦点。
  void _takeKeyboardFocus() {
    if (!mounted || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (!_keyboardFocus.hasFocus) _keyboardFocus.requestFocus();
  }

  /// Windows 上的快捷键。编辑时只留下 Esc、Ctrl+Enter 和 Ctrl+N，其余的
  /// 键交给编辑框打字。
  Map<ShortcutActivator, VoidCallback> _shortcuts(BoardSelection selection) {
    if (defaultTargetPlatform != TargetPlatform.windows) return const {};
    final selectedCard = switch (selection) {
      CardSelected(:final cardId) => _boardCard(cardId),
      _ => null,
    };
    return {
      if (selectedCard != null) ...{
        const SingleActivator(
          LogicalKeyboardKey.delete,
          includeRepeats: false,
        ): () =>
            _finishCard(selectedCard, _Finish.delete),
        const SingleActivator(
          LogicalKeyboardKey.backspace,
          includeRepeats: false,
        ): () =>
            _finishCard(selectedCard, _Finish.delete),
        const SingleActivator(
          LogicalKeyboardKey.enter,
          includeRepeats: false,
        ): () =>
            _save(() => _selection.editCard(selectedCard)),
        const SingleActivator(
          LogicalKeyboardKey.enter,
          control: true,
          includeRepeats: false,
        ): () =>
            _finishCard(selectedCard, _Finish.complete),
      },
      if (selection is Editing)
        const SingleActivator(
          LogicalKeyboardKey.enter,
          control: true,
          includeRepeats: false,
        ): _completeEditedCard,
      if (selection is! Editing) ...{
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            switchDay(context, ref, (s) => s.showDayOffset(-1)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            switchDay(context, ref, (s) => s.showDayOffset(1)),
        const SingleActivator(LogicalKeyboardKey.keyT, includeRepeats: false):
            _showToday,
        // 编辑时交给编辑框撤销输入的文字。
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): _undo,
      },
      // 编辑时保存并退出编辑，不在编辑时取消选中。
      const SingleActivator(
        LogicalKeyboardKey.escape,
        includeRepeats: false,
      ): () =>
          _save(_selection.leaveBoard),
      // 过去的日期不能新建卡片。
      if (widget.canCreateCards)
        const SingleActivator(
          LogicalKeyboardKey.keyN,
          control: true,
          includeRepeats: false,
        ): _onAddCard,
    };
  }

  /// Ctrl+Z：撤销最近的一条操作，撤销不了时提示「无法撤销」。被撤销动到的
  /// 卡片不再用临时的位置或退场状态，按数据库里的样子显示。
  Future<void> _undo() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    switch (await _selection.undo()) {
      case NothingToUndo():
        return;
      case Undone(:final cardId):
        if (cardId == null || !mounted) return;
        setState(() {
          _leaving.remove(cardId);
          if (_dropping?.cardId == cardId) _dropping = null;
        });
      case CannotUndo():
        messenger?.showSnackBar(const SnackBar(content: Text('无法撤销')));
    }
  }

  /// 按 T 回到今天。和「今天」按钮一样，已经在今天时什么都不做。
  void _showToday() {
    final today = ref.read(todayProvider);
    if (ref.read(displayedDayProvider) == today) return;
    switchDay(context, ref, (s) => s.showDay(today));
  }

  /// 编辑时按 Ctrl+Enter：先保存编辑的内容并退出编辑（新卡片先建好），保存
  /// 成功再完成卡片。标题为空的新卡片丢弃，不完成。
  Future<void> _completeEditedCard() async {
    String? cardId;
    if (!await _save(() async => cardId = await _selection.stopEditing())) {
      return;
    }
    final id = cardId;
    if (id == null || !mounted) return;
    // 刚建好的卡片还没出现在画布上，直接完成，不播退场动画。
    switch (_boardCard(id)) {
      case final card?:
        await _finishCard(card, _Finish.complete);
      case null:
        await _save(() => _selection.completeCard(id));
    }
  }

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

  /// 记下这一次按下落在了什么上。连线、卡片上的按下先到，画布上的后到。
  void _onCanvasPointerDown(PointerDownEvent event) {
    _previousDownOn = _lastDownOn;
    _lastDownOn = _downOn;
    _downOn = null;
  }

  void _onDoubleTapBlank() {
    switch (_previousDownOn) {
      // 第一下点在连线上：和双击连线一样，选中那条连线。
      case _DownOnLink(:final position):
        _onTapLink(position);
        return;
      // 第一下点在卡片上：和双击卡片一样，完成它；正在编辑的卡片什么都不做。
      case _DownOnCard(:final cardId):
        if (ref.read(boardSelectionProvider)
            case EditingCard(cardId: final editing) when editing == cardId) {
          return;
        }
        if (_boardCard(cardId) case final card?) {
          _finishCard(card, _Finish.complete);
        }
        return;
      // 第一下点在新卡片上：和双击新卡片一样，什么都不做。
      case _DownOnDraft():
        return;
      // 第一下点在历史记录上：和双击历史记录一样，跳到卡片所在的日期。
      case _DownOnRecord(:final record):
        _openCarryOverRecord(record);
        return;
      case null:
    }
    final position = _doubleTapPosition;
    // 过去的日期不能新建卡片。
    if (position == null || !widget.canCreateCards) return;
    _save(() => _selection.newCardAt(_transform.toScene(position)));
  }

  /// 画布的可视区域，不含标题栏。
  final _viewportKey = GlobalKey();

  /// 「＋」：在可视区域中间新建卡片。
  void _onAddCard() {
    final viewport = _viewportKey.currentContext!.size!;
    final center = viewport.center(Offset.zero);
    _save(() => _selection.newCardAt(_transform.toScene(center)));
  }

  /// 画布内容区，用来把屏幕坐标换算成画布坐标。
  final _contentKey = GlobalKey();

  /// 屏幕上的 [global] 在画布上的坐标，已经算上平移和缩放。
  Offset _globalToCanvas(Offset global) =>
      (_contentKey.currentContext!.findRenderObject()! as RenderBox)
          .globalToLocal(global);

  /// 弹出菜单的位置：屏幕上的 [global] 处。
  RelativeRect _menuPosition(Offset global) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final at = overlay.globalToLocal(global);
    return RelativeRect.fromRect(at & Size.zero, Offset.zero & overlay.size);
  }

  /// 长按卡片（Windows 上也可以右键）：在 [global] 处弹出卡片菜单。
  Future<void> _openCardMenu(TaskCard card, Offset global) async {
    final action = await showMenu<_CardMenuAction>(
      context: context,
      position: _menuPosition(global),
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
        await _finishCard(card, _Finish.delete);
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
            zone: _dropZones.zoneAt(event.position),
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
          case final CardDropped dropped:
            _dropCard(dropped);
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
    final saved = await _save(
      () => _selection.toggleLink(release.cardId, release.targetId),
    );
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
      for (final MapEntry(key: cardId, value: leaving) in _leaving.entries)
        cardId: ?leaving.at,
      if (_drag.dragged case (:final cardId, :final position)) cardId: position,
    };
  }

  /// 数据库的画布内容里 ID 为 [cardId] 的卡片；没有时为 null。
  TaskCard? _boardCard(String cardId) =>
      widget.board.cards.where((c) => c.id == cardId).firstOrNull;

  /// 画布上显示的卡片：去掉已经退场的，加上数据库里已经没有、退场动画还没
  /// 播完的。
  List<TaskCard> _shownCards() {
    final cards = widget.board.cards;
    final ids = {for (final c in cards) c.id};
    return [
      for (final card in cards)
        if (!(_leaving[card.id]?.gone ?? false)) card,
      for (final leaving in _leaving.values)
        if (!leaving.gone && !ids.contains(leaving.card.id)) leaving.card,
    ];
  }

  /// 完成卡片（[_Finish.complete]，先打勾消失）或移到回收站
  /// （[_Finish.delete]，立即消失），同时在后台保存。保存失败时卡片回到原处。
  /// 卡片已经在退场时什么都不做，不会重复保存。
  ///
  /// [dropped] 是拖进投放区松手的结果：卡片在松手的位置退场，保存失败时
  /// 从那里弹回起点。
  Future<void> _finishCard(
    TaskCard card,
    _Finish action, {
    CardDropped? dropped,
  }) async {
    if (_leaving.containsKey(card.id)) return;
    // 保存期间画布可能被换掉（比如切换了日期），撤销提示不依赖画布还在。
    final messenger = ScaffoldMessenger.maybeOf(context);
    final container = ProviderScope.containerOf(context, listen: false);
    setState(
      () =>
          _leaving[card.id] = _Leaving(card, at: dropped?.releasedAt)
            ..gone = action == _Finish.delete,
    );
    final saved = await _save(
      () => switch (action) {
        _Finish.complete => _selection.completeCard(card.id),
        _Finish.delete => _selection.deleteCard(card.id),
      },
    );
    if (!saved) {
      if (mounted) _returnCard(card.id, dropped);
      return;
    }
    if (action == _Finish.delete && messenger != null) {
      showUndoDeleteNotice(
        card,
        messenger,
        container,
        onRestored: () {
          if (mounted) setState(() => _leaving.remove(card.id));
        },
      );
    }
  }

  /// 保存失败：退场的卡片回到画布上原来的地方。拖进投放区的从松手的位置
  /// 弹回起点。
  void _returnCard(String cardId, CardDropped? dropped) {
    setState(() => _leaving.remove(cardId));
    if (dropped == null) return;
    setState(
      () => _bounce = (
        cardId: cardId,
        from: dropped.releasedAt,
        to: dropped.origin,
      ),
    );
    _bounceAnimation.forward(from: 0);
  }

  /// 在投放区里松手：完成或删除卡片。
  void _dropCard(CardDropped dropped) {
    final card = _boardCard(dropped.cardId);
    if (card == null) return setState(() {});
    final action = switch (dropped.zone) {
      DropZone.complete => _Finish.complete,
      DropZone.trash => _Finish.delete,
    };
    _finishCard(card, action, dropped: dropped);
  }

  /// 卡片的退场动画播完了：不再显示它。
  void _onLeft(String cardId) {
    final leaving = _leaving[cardId];
    if (leaving == null) return;
    setState(() {
      leaving.gone = true;
      if (_boardCard(cardId) == null) {
        _leaving.remove(cardId);
      }
    });
  }

  /// 卡片现在在画布上占的矩形，算上临时的位置和大小，按从下到上的顺序。
  /// 卡片、连线和碰撞判断都按它来。
  Map<String, CardBox> _cardBoxes() {
    final lifted = _liftedPositions();
    final cards = _shownCards();
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

  /// 画布当前的缩放比例。
  double get _scale => _transform.value.getMaxScaleOnAxis();

  /// 画布上显示着的连线和它们现在的曲线，按从下到上的绘制顺序。
  Map<String, LinkCurve> _linkCurves() =>
      linkCurves(widget.board.links, _cardBoxes());

  /// 画布上的 [position] 点中的连线；没点中时返回 null。
  String? _linkAt(Offset position) =>
      linkAt(_linkCurves(), (x: position.dx, y: position.dy), scale: _scale);

  /// 单击连线附近：选中点中的那条。
  void _onTapLink(Offset position) {
    final linkId = _linkAt(position);
    if (linkId == null) return;
    _save(() => _selection.tapLink(linkId));
  }

  /// 右键连线附近：在 [global] 处弹出「断开连线」菜单。不改变选中。
  Future<void> _openLinkMenu(Offset position, Offset global) async {
    final linkId = _linkAt(position);
    if (linkId == null) return;
    final action = await showMenu<_LinkMenuAction>(
      context: context,
      position: _menuPosition(global),
      items: const [
        PopupMenuItem(value: _LinkMenuAction.remove, child: Text('断开连线')),
      ],
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _LinkMenuAction.remove:
        await _save(() => _selection.removeLink(linkId));
    }
  }

  /// 选中的连线中点上的 ✂️，盖在画布上面，不随缩放变大变小。
  Widget _linkScissors(String linkId, LinkCurve curve) {
    final middle = linkCurveMidpoint(curve);
    return ListenableBuilder(
      listenable: _transform,
      builder: (context, _) {
        final center = MatrixUtils.transformPoint(
          _transform.value,
          Offset(middle.x, middle.y),
        );
        return Positioned(
          key: BoardCanvas.linkScissorsKey,
          left: center.dx - _scissorsHitSize / 2,
          top: center.dy - _scissorsHitSize / 2,
          width: _scissorsHitSize,
          height: _scissorsHitSize,
          // 立即响应，不等双击判定；整个点击范围都接住点击，不落到下面。
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _save(() => _selection.removeLink(linkId)),
            child: const Center(child: _Scissors()),
          ),
        );
      },
    );
  }

  /// 保存拖动后的位置。保存好之前卡片停在新位置；保存失败时回到原处。
  Future<void> _moveCard(CardDrop drop) async {
    final (:cardId, :position) = drop;
    final card = _boardCard(cardId);
    if (card == null) return;
    // 上一次松手的位置还没保存好就又拖了一次：从那个位置开始算。
    final from = switch (_dropping) {
      (cardId: final dropped, :final position) when dropped == cardId =>
        position,
      _ => Offset(card.x, card.y),
    };
    setState(() => _dropping = drop);
    final saved = await _save(
      () => _selection.moveCard(cardId, from: from, to: position),
    );
    // 只清自己这张；保存期间可能又拖了另一张卡片。
    if (!saved && mounted && _dropping?.cardId == cardId) {
      setState(() => _dropping = null);
    }
  }

  @override
  void initState() {
    super.initState();
    // 换一天时画布重建，快捷键的焦点跟着换到新画布上。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(boardSelectionProvider) is! Editing) _takeKeyboardFocus();
    });
    // 点历史记录跳到另一天时，画布按 ValueKey(day) 重建，这时卡片已经选中了：
    // 等画布排好版，让它露出来。
    if (ref.read(boardSelectionProvider) case CardSelected(:final cardId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealCard(cardId);
      });
    }
  }

  /// 卡片露出来时离可视区域边缘的距离。
  static const _revealMargin = 24.0;

  /// 卡片已经完整地在可视区域里时什么都不做；不然最少地平移画布，让它完整
  /// 出现（留出 [_revealMargin]）。不改变缩放比例。
  void _revealCard(String cardId) {
    final card = _boardCard(cardId);
    final viewport = _viewportKey.currentContext?.size;
    if (card == null || viewport == null) return;
    final topLeft = MatrixUtils.transformPoint(
      _transform.value,
      Offset(card.x, card.y),
    );
    final shown = topLeft & Size(card.width, card.height) * _scale;
    final dx = _revealShift(shown.left, shown.right, viewport.width);
    final dy = _revealShift(shown.top, shown.bottom, viewport.height);
    if (dx == 0 && dy == 0) return;
    _transform.value = Matrix4.translationValues(dx, dy, 0)
      ..multiply(_transform.value);
  }

  /// 把 [start] 到 [end] 这一段移进 0 到 [extent] 里要平移多少。已经在里面
  /// 时为 0；放不下时让开头对齐。
  static double _revealShift(double start, double end, double extent) {
    if (start >= 0 && end <= extent) return 0;
    if (start < 0 || end - start + 2 * _revealMargin > extent) {
      return _revealMargin - start;
    }
    return extent - _revealMargin - end;
  }

  @override
  void didUpdateWidget(BoardCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    final cards = {for (final c in widget.board.cards) c.id: c};
    final oldCards = {for (final c in oldWidget.board.cards) c.id: c};
    // 退场的卡片已经从数据库的画布内容里消失、动画也播完了。
    _leaving.removeWhere(
      (cardId, leaving) => leaving.gone && !cards.containsKey(cardId),
    );
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
    // 选中的连线不再显示了：取消选中。刷新画布的过程中不能改选中状态，
    // 等这一帧画完。
    if (ref.read(boardSelectionProvider) case LinkSelected(:final linkId)
        when !widget.board.links.any((l) => l.id == linkId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selection.forgetLink(linkId);
      });
    }
  }

  /// 单击历史记录：跳到卡片现在所在的日期；卡片已完成时再打开那一天的
  /// 「已完成」列表。跳转以后这个画布就换掉了，所以提示和打开列表用的是
  /// 跳转前拿到的 messenger、navigator 和 provider 容器。
  Future<void> _openCarryOverRecord(CarryOverRecord record) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    late final CarryOverJump jump;
    if (!await _save(
      () async => jump = await _selection.openCarryOverRecord(record.cardId),
    )) {
      return;
    }
    // 卡片就在这一天时画布不会重建，在这里让它露出来；换了一天的由新画布
    // 的 initState 处理。
    if (jump == CarryOverJump.selected && mounted) _revealCard(record.cardId);
    final message = switch (jump) {
      CarryOverJump.selected => null,
      CarryOverJump.completed => null,
      CarryOverJump.inTrash => '该任务在回收站中',
      CarryOverJump.missing => '该任务已不存在',
      CarryOverJump.unreadable => '读取失败，请重试',
    };
    if (message != null) {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
    if (jump == CarryOverJump.completed) {
      await CompletedPage.open(navigator, container.read(displayedDayProvider));
    }
  }

  /// 执行一个要保存的操作；保存失败时提示，返回 false。
  Future<bool> _save(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } on PlannerException catch (e) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(content: Text(saveFailureMessage(e))));
      }
      return false;
    }
  }

  /// 准备连线时的预览，画在卡片上面：连线时是一条虚线，断开时在两张卡片之间
  /// 显示 ✂️。
  List<Widget> _armedPreview(CardArmed armed, Map<String, CardBox> boxes) {
    final (from, to) = (boxes[armed.cardId], boxes[armed.targetId]);
    if (from == null || to == null) return const [];
    final curve = linkCurve(from, to);
    if (armed.action == LinkAction.link) {
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
    return [
      Positioned(
        key: BoardCanvas.unlinkPreviewKey,
        left: middle.x - _Scissors.size / 2,
        top: middle.y - _Scissors.size / 2,
        width: _Scissors.size,
        height: _Scissors.size,
        child: const IgnorePointer(child: _Scissors()),
      ),
    ];
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    _bounceAnimation.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.board.cards;
    final selection = ref.watch(boardSelectionProvider);
    ref.listen(boardSelectionProvider, (_, next) {
      if (next is! Editing) _takeKeyboardFocus();
    });
    final shown = _shownCards();
    // 正在拖动、刚松手还在保存、或者正在弹回的卡片显示在临时位置，画在所有
    // 卡片上面。
    final boxes = _cardBoxes();
    final cardsById = {for (final c in shown) c.id: c};
    final ordered = [for (final id in boxes.keys) cardsById[id]!];
    final armed = switch (_drag.state) {
      final CardArmed armed => armed,
      _ => null,
    };
    final curves = linkCurves(widget.board.links, boxes);
    final selectedLink = switch (selection) {
      LinkSelected(:final linkId) when curves.containsKey(linkId) => linkId,
      _ => null,
    };
    final records = widget.board.carryOverRecords;
    // 内容区要盖住所有卡片和历史记录，不然盖不住的部分点不到。
    final width = [
      ...cards.map((c) => c.x + c.width),
      ...records.map((r) => r.x + r.width),
    ].fold(0.0, math.max);
    final height = [
      ...cards.map((c) => c.y + c.height),
      ...records.map((r) => r.y + r.height),
    ].fold(0.0, math.max);
    final canvas = Listener(
      key: _viewportKey,
      onPointerSignal: _onPointerSignal,
      onPointerDown: _onCanvasPointerDown,
      // 卡片和编辑框在里层，点在它们上面时由它们处理，不算点空白处。
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _save(_selection.tapBlank),
        // 过去的日期上也要接住双击：第一下点在连线或卡片上时要认出来。
        onDoubleTapDown: (details) =>
            _doubleTapPosition = details.localPosition,
        onDoubleTap: _onDoubleTapBlank,
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
                // 连线画在所有卡片下面。
                Positioned.fill(
                  child: IgnorePointer(
                    child: LinkLayer(
                      links: widget.board.links,
                      boxes: boxes,
                      selectedLinkId: selectedLink,
                    ),
                  ),
                ),
                // 连线的点击范围：只有连线附近能点，其余地方点下去落到空白处。
                // 在卡片下面，卡片盖住连线时点的是卡片。
                Positioned.fill(
                  child: GestureDetector(
                    onTapUp: (details) => _onTapLink(details.localPosition),
                    // 双击连线和单击一样。连线自己接住双击，外面的画布才不会
                    // 当成双击空白处新建卡片。
                    onDoubleTapDown: (details) =>
                        _linkDoubleTapPosition = details.localPosition,
                    onDoubleTap: () {
                      if (_linkDoubleTapPosition case final position?) {
                        _onTapLink(position);
                      }
                    },
                    // 右键和卡片一样不区分平台；手机上没有右键。
                    onSecondaryTapUp: (details) => _openLinkMenu(
                      details.localPosition,
                      details.globalPosition,
                    ),
                    child: Listener(
                      onPointerDown: (event) =>
                          _downOn = _DownOnLink(event.localPosition),
                      child: CustomPaint(
                        painter: _LinkHitArea(
                          (position) => _linkAt(position) != null,
                        ),
                      ),
                    ),
                  ),
                ),
                // 历史记录画在连线上面、卡片下面：点击时卡片优先，其次是
                // 历史记录，再其次才是连线。
                for (final record in records)
                  Positioned(
                    left: record.x,
                    top: record.y,
                    width: record.width,
                    height: record.height,
                    child: CarryOverRecordView(
                      key: BoardCanvas.carryOverRecordKey(record.id),
                      record: record,
                      onTap: () => _openCarryOverRecord(record),
                      onPointerDown: () => _downOn = _DownOnRecord(record),
                    ),
                  ),
                for (final card in ordered)
                  _CardView(
                    key: ValueKey(card.id),
                    card: card,
                    armedTarget: card.id == armed?.targetId,
                    completing: _leaving.containsKey(card.id),
                    onCompleted: () => _onLeft(card.id),
                    selected:
                        selection is CardSelected &&
                        selection.cardId == card.id,
                    editing:
                        selection is EditingCard && selection.cardId == card.id
                        ? selection
                        : null,
                    box: boxes[card.id]!,
                    onTap: () => _save(() => _selection.tapCard(card)),
                    onDoubleTap: () => _finishCard(card, _Finish.complete),
                    onPointerDown: () => _downOn = _DownOnCard(card.id),
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
                      child: Listener(
                        onPointerDown: (_) => _downOn = const _DownOnDraft(),
                        child: _CardFrame(
                          colorArgb: TaskCard.defaultColorArgb,
                          builder: (textColor) =>
                              _CardEditor(editing: draft, textColor: textColor),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final page = Scaffold(
      appBar: widget.appBar,
      body: Stack(
        children: [
          Positioned.fill(child: canvas),
          if (selectedLink != null)
            _linkScissors(selectedLink, curves[selectedLink]!),
          if (_drag.state case final CardDragging dragging)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DropZoneBar(
                locator: _dropZones,
                active: switch (dragging) {
                  CardOverZone(:final zone) => zone,
                  _ => null,
                },
              ),
            ),
        ],
      ),
      // 拖动时投放区占着底部，「＋」先藏起来。
      floatingActionButton: widget.canCreateCards && _drag.dragged == null
          ? FloatingActionButton(
              tooltip: '新建卡片',
              onPressed: _onAddCard,
              child: const Icon(Icons.add),
            )
          : null,
    );
    // 快捷键放在焦点外面：焦点在画布或编辑框上时都能收到。
    return CallbackShortcuts(
      bindings: _shortcuts(selection),
      child: Focus(focusNode: _keyboardFocus, child: page),
    );
  }
}

/// 连线的点击范围：什么也不画，只在 [hits] 成立的位置接住点击。
class _LinkHitArea extends CustomPainter {
  _LinkHitArea(this.hits);

  /// 画布上的这个位置算不算点中了连线。
  final bool Function(Offset position) hits;

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool hitTest(Offset position) => hits(position);

  @override
  bool shouldRepaint(_LinkHitArea oldDelegate) => false;
}

/// 圆形的 ✂️ 图标：断开连线。
class _Scissors extends StatelessWidget {
  const _Scissors();

  /// 直径（逻辑像素）。
  static const size = 32.0;

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: PlannerTheme.accent,
        shape: BoxShape.circle,
        boxShadow: PlannerTheme.cardShadow,
      ),
      child: Icon(Icons.content_cut, size: 18, color: Colors.white),
    ),
  );
}

/// 按下时落在了什么上，见 [_BoardCanvasState._downOn]。
sealed class _DownTarget {
  const _DownTarget();
}

/// 按在连线上（不算盖在连线上的卡片），[position] 是画布坐标。
final class _DownOnLink extends _DownTarget {
  const _DownOnLink(this.position);

  final Offset position;
}

/// 按在卡片上。
final class _DownOnCard extends _DownTarget {
  const _DownOnCard(this.cardId);

  final String cardId;
}

/// 按在还没保存的新卡片上。
final class _DownOnDraft extends _DownTarget {
  const _DownOnDraft();
}

/// 按在历史记录上。
final class _DownOnRecord extends _DownTarget {
  const _DownOnRecord(this.record);

  final CarryOverRecord record;
}

/// 让卡片退场的操作：完成，或移到回收站。
enum _Finish { complete, delete }

/// 卡片菜单里的操作。
enum _CardMenuAction { recolor, edit, delete }

/// 连线菜单里的操作。
enum _LinkMenuAction { remove }

class _CardView extends StatefulWidget {
  const _CardView({
    super.key,
    required this.card,
    required this.armedTarget,
    required this.completing,
    required this.onCompleted,
    required this.selected,
    required this.editing,
    required this.box,
    required this.onTap,
    required this.onDoubleTap,
    required this.onPointerDown,
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

  /// 正在完成：打勾消失，不再响应操作。播完时调 [onCompleted]。
  final bool completing;
  final VoidCallback onCompleted;

  final bool selected;

  /// 正在编辑这张卡片时不为 null，卡片上显示编辑框。
  final EditingCard? editing;

  /// 卡片现在在画布上占的矩形，包括拖动、调整大小时的临时位置和大小。
  final CardBox box;

  final VoidCallback onTap;

  /// 双击卡片：完成它。正在编辑的卡片不响应。
  final VoidCallback onDoubleTap;

  /// 指针按在卡片上（包括正在编辑的卡片和手柄）。
  final VoidCallback onPointerDown;

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
    return Positioned(
      key: BoardCanvas.cardKey(widget.card.id),
      left: widget.box.x,
      top: widget.box.y,
      width: widget.box.width,
      height: widget.box.height,
      child: AnimatedScale(
        scale: widget.armedTarget ? 1.05 : 1,
        duration: const Duration(milliseconds: 120),
        child: widget.completing
            ? _CompletingCard(onEnd: widget.onCompleted, child: _card())
            : _card(),
      ),
    );
  }

  /// 卡片本身：手势、底色和内容，选中时右下角有手柄。
  Widget _card() {
    final card = widget.card;
    final editing = widget.editing;
    // 正在编辑的卡片不能拖。
    final onDragPointer = editing == null ? widget.onDragPointer : null;
    // 长按（Windows 上也可以右键）弹出菜单。正在编辑的卡片不弹，
    // 在编辑框里长按、右键是选文字和文字菜单。
    final onMenu = editing == null ? widget.onMenu : null;
    return GestureDetector(
      onTap: widget.onTap,
      // 双击完成。正在编辑的卡片也接住双击（什么都不做），外面的画布才
      // 不会当成双击空白处新建卡片。
      onDoubleTap: editing == null ? widget.onDoubleTap : () {},
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
              onPointerDown: (event) {
                widget.onPointerDown();
                onDragPointer?.call(event);
              },
              onPointerMove: onDragPointer,
              onPointerUp: onDragPointer,
              onPointerCancel: onDragPointer,
              child: _CardFrame(
                colorArgb: card.colorArgb,
                glow: widget.armedTarget,
                builder: (textColor) {
                  final content = switch (editing) {
                    final editing? => _CardEditor(
                      editing: editing,
                      textColor: textColor,
                    ),
                    null => _CardContent(card: card, textColor: textColor),
                  };
                  if (!card.carriedOver) return content;
                  // 「顺延」标记单独占右上角一列，不盖住标题、备注和编辑框；
                  // 编辑时也显示。
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: content),
                      const SizedBox(width: 6),
                      _CarriedOverTag(
                        key: BoardCanvas.carriedOverTagKey(card.id),
                        textColor: textColor,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (widget.selected)
            Positioned(
              right: 0,
              bottom: 0,
              // 拖手柄由手柄自己处理，画布不跟着平移。
              child: Listener(
                onPointerDown: (_) => widget.onPointerDown(),
                child: GestureDetector(
                  key: BoardCanvas.resizeHandleKey(card.id),
                  dragStartBehavior: DragStartBehavior.down,
                  onPanStart: _onResizeStart,
                  onPanUpdate: _onResizeUpdate,
                  onPanEnd: (_) => widget.onResizeEnd(),
                  child: const _ResizeHandle(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 正在完成的卡片：打上 ✓，缩小、淡出，播完时调 [onEnd]。不再响应操作。
class _CompletingCard extends StatelessWidget {
  const _CompletingCard({required this.onEnd, required this.child});

  final VoidCallback onEnd;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: BoardCanvas.completeDuration,
        curve: Curves.easeIn,
        onEnd: onEnd,
        builder: (context, t, child) => Opacity(
          opacity: 1 - t,
          child: Transform.scale(scale: 1 - 0.2 * t, child: child),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: child),
            const Center(
              child: Icon(
                Icons.check_circle,
                key: BoardCanvas.completeCheckKey,
                size: 40,
                color: PlannerTheme.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 一张正在退场的卡片。
class _Leaving {
  _Leaving(this.card, {this.at});

  /// 开始退场时的卡片，数据库里已经没有它、动画还没播完时用它来画。
  final TaskCard card;

  /// 拖进投放区松手的位置，卡片在这里退场；在原处退场时为 null。
  final Offset? at;

  /// 退场动画播完了，不再显示。
  bool gone = false;
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

/// 顺延过的卡片右上角的「顺延」标记。
class _CarriedOverTag extends StatelessWidget {
  const _CarriedOverTag({super.key, required this.textColor});

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final color = textColor.withValues(alpha: 0.6);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          '顺延',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
      ),
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
