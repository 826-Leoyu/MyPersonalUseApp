/// Spec 的「拖动交互状态机」：判断按在卡片上的指针是拖动还是长按，
/// 拖动时算出卡片在画布上的临时位置。所有坐标都是画布坐标。
///
/// 现在只有 `idle` 和 `dragging`，外加按下后还没判定的阶段；碰撞连线的
/// `hovering`、`armed` 由 #18 加。
library;

import 'dart:math' as math;
import 'dart:ui';

/// 拖动状态。
sealed class CardDragState {
  const CardDragState();
}

/// 没有按在卡片上。
final class CardDragIdle extends CardDragState {
  const CardDragIdle();
}

/// 按在卡片上，还没判定是拖动还是长按。
final class CardPressed extends CardDragState {
  const CardPressed({
    required this.cardId,
    required this.origin,
    required this.pointer,
    required this.at,
    required this.slop,
  });

  final String cardId;

  /// 卡片左上角原来的位置。
  final Offset origin;

  /// 按下的位置和时间。
  final Offset pointer;
  final Duration at;

  /// 移动超过这个距离才算拖动。
  final double slop;
}

/// 正在拖动卡片。
final class CardDragging extends CardDragState {
  const CardDragging({
    required this.cardId,
    required this.position,
    required this.grab,
  });

  final String cardId;

  /// 卡片左上角现在的位置，只在内存里，松手时才保存。
  final Offset position;

  /// 卡片左上角相对指针的位置，拖动中保持不变。
  final Offset grab;
}

/// 按住卡片 [CardDragMachine.longPressTimeout] 没有移动：是长按，不是拖动。
/// 长按的菜单由 #16 接上，现在什么也不做。
final class CardLongPressed extends CardDragState {
  const CardLongPressed(this.cardId);

  final String cardId;
}

/// 驱动拖动状态：输入指针的位置和时间，输出 [state]。
class CardDragMachine {
  /// 按住这么久没有移动就是长按（spec：500ms）。
  static const longPressTimeout = Duration(milliseconds: 500);

  CardDragState _state = const CardDragIdle();

  CardDragState get state => _state;

  /// 指针在 [pointer] 按下，按在左上角位于 [origin] 的卡片上。
  void down(
    String cardId, {
    required Offset origin,
    required Offset pointer,
    required Duration at,
    required double slop,
  }) {
    _state = CardPressed(
      cardId: cardId,
      origin: origin,
      pointer: pointer,
      at: at,
      slop: slop,
    );
  }

  /// 指针移动到 [pointer]。
  void move(Offset pointer, {required Duration at}) {
    switch (_state) {
      case final CardPressed pressed:
        if (at - pressed.at >= longPressTimeout) {
          _state = CardLongPressed(pressed.cardId);
          return;
        }
        if ((pointer - pressed.pointer).distance <= pressed.slop) return;
        _state = _dragTo(
          pressed.cardId,
          pointer,
          pressed.origin - pressed.pointer,
        );
      case final CardDragging dragging:
        _state = _dragTo(dragging.cardId, pointer, dragging.grab);
      case CardDragIdle() || CardLongPressed():
        return;
    }
  }

  /// 指针抬起。拖动过时返回卡片要移到的位置；不是拖动时返回 null。
  ({String cardId, Offset position})? up() {
    final state = _state;
    _state = const CardDragIdle();
    return switch (state) {
      CardDragging(:final cardId, :final position) => (
        cardId: cardId,
        position: position,
      ),
      _ => null,
    };
  }

  /// 手势被别的操作抢走（比如捏合缩放画布）：放弃拖动，卡片回到原处。
  void cancel() => _state = const CardDragIdle();

  /// 卡片跟着指针走，但不会放到画布左上角以外。
  CardDragging _dragTo(String cardId, Offset pointer, Offset grab) {
    final position = pointer + grab;
    return CardDragging(
      cardId: cardId,
      position: Offset(math.max(0, position.dx), math.max(0, position.dy)),
      grab: grab,
    );
  }
}
