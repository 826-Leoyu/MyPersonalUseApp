/// Spec 的「拖动交互状态机」：判断按在卡片上的指针有没有开始拖动，
/// 拖动时算出卡片在画布上的临时位置。所有坐标都是画布坐标。
///
/// 现在只有 `idle` 和 `dragging`，外加按下后还没移动够的阶段；碰撞连线的
/// `hovering`、`armed` 由 #18 加。长按由卡片上的 Flutter 长按手势判定，
/// 它胜出时拖动被取消（[CardDragMachine.cancel]），不经过这里。
library;

import 'dart:math' as math;
import 'dart:ui';

/// 一张正在拖动、或者拖完要保存的卡片，和它左上角的位置。
typedef CardDrop = ({String cardId, Offset position});

/// 拖动状态。
sealed class CardDragState {
  const CardDragState();
}

/// 没有按在卡片上。
final class CardDragIdle extends CardDragState {
  const CardDragIdle();
}

/// 按在卡片上，还没移动到判定距离。
final class CardPressed extends CardDragState {
  const CardPressed({
    required this.cardId,
    required this.origin,
    required this.pointer,
    required this.slop,
  });

  final String cardId;

  /// 卡片左上角原来的位置。
  final Offset origin;

  /// 按下的位置。
  final Offset pointer;

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

/// 驱动拖动状态：输入指针的位置和时间，输出 [state]。
class CardDragMachine {
  CardDragState _state = const CardDragIdle();

  CardDragState get state => _state;

  /// 正在拖动的卡片和它现在的位置；没有在拖动时为 null。
  CardDrop? get dragged => switch (_state) {
    CardDragging(:final cardId, :final position) => (
      cardId: cardId,
      position: position,
    ),
    _ => null,
  };

  /// 指针在 [pointer] 按下，按在左上角位于 [origin] 的卡片上。
  void down(
    String cardId, {
    required Offset origin,
    required Offset pointer,
    required double slop,
  }) {
    _state = CardPressed(
      cardId: cardId,
      origin: origin,
      pointer: pointer,
      slop: slop,
    );
  }

  /// 指针移动到 [pointer]。
  void move(Offset pointer) {
    switch (_state) {
      case final CardPressed pressed:
        if ((pointer - pressed.pointer).distance <= pressed.slop) return;
        _state = _dragTo(
          pressed.cardId,
          pointer,
          pressed.origin - pressed.pointer,
        );
      case final CardDragging dragging:
        _state = _dragTo(dragging.cardId, pointer, dragging.grab);
      case CardDragIdle():
        return;
    }
  }

  /// 指针抬起。拖动过时返回卡片要移到的位置；没有拖动时返回 null。
  CardDrop? up() {
    final drop = dragged;
    _state = const CardDragIdle();
    return drop;
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
