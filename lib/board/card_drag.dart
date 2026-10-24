/// Spec 的「拖动交互状态机」：判断按在卡片上的指针有没有开始拖动，
/// 拖动时算出卡片在画布上的临时位置，指针在另一张卡片上停够时间就准备连线
/// 或断开。所有坐标都是画布坐标。
///
/// 长按由卡片上的 Flutter 长按手势判定，它胜出时拖动被取消
/// （[CardDragMachine.cancel]），不经过这里。
///
/// 碰撞只看画布上的卡片，底部投放区优先于卡片碰撞。投放区是屏幕上固定的
/// 位置，由界面按屏幕坐标判断后传进来。画布上的历史记录（#21）不参与碰撞，
/// 由那个任务接上。
library;

import 'dart:ui';

import '../planner/link_geometry.dart';

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

/// 正在拖动卡片，指针不在别的卡片上。[CardHovering]、[CardArmed] 也是在拖动，
/// 只是指针停在了另一张卡片上。
final class CardDragging extends CardDragState {
  const CardDragging({
    required this.cardId,
    required this.origin,
    required this.position,
    required this.grab,
  });

  final String cardId;

  /// 卡片左上角拖动前的位置，连线或断开后弹回这里。
  final Offset origin;

  /// 卡片左上角现在的位置，只在内存里，松手时才保存。
  final Offset position;

  /// 卡片左上角相对指针的位置，拖动中保持不变。
  final Offset grab;
}

/// 底部投放区：✅ 完成、🗑️ 回收站。
enum DropZone { complete, trash }

/// 拖动中指针在底部投放区里。
final class CardOverZone extends CardDragging {
  CardOverZone(CardDragging dragging, {required this.zone})
    : super(
        cardId: dragging.cardId,
        origin: dragging.origin,
        position: dragging.position,
        grab: dragging.grab,
      );

  final DropZone zone;
}

/// 拖动中指针停在另一张卡片上，开始计时。
final class CardHovering extends CardDragging {
  CardHovering(
    CardDragging dragging, {
    required this.targetId,
    required this.since,
  }) : super(
         cardId: dragging.cardId,
         origin: dragging.origin,
         position: dragging.position,
         grab: dragging.grab,
       );

  /// 指针所在的那张卡片。
  final String targetId;

  /// 指针进入这张卡片的时间。
  final Duration since;
}

/// 松手时对两张卡片做什么：没连上就连线，已经连上（任一方向）就断开。
enum LinkAction { link, unlink }

/// 指针在另一张卡片上停满了 [CardDragMachine.armDelay]：松手就连线或断开。
final class CardArmed extends CardDragging {
  CardArmed(
    CardDragging dragging, {
    required this.targetId,
    required this.action,
  }) : super(
         cardId: dragging.cardId,
         origin: dragging.origin,
         position: dragging.position,
         grab: dragging.grab,
       );

  /// 要连上或断开的那张卡片。
  final String targetId;

  final LinkAction action;
}

/// 拖动后松手的结果。
sealed class CardRelease {
  const CardRelease();
}

/// 卡片移到 [drop] 的位置。
final class CardMoved extends CardRelease {
  const CardMoved(this.drop);

  final CardDrop drop;
}

/// 在 [targetId] 上松手：切换 [cardId] → [targetId] 的连线，卡片从松手的位置
/// [releasedAt] 弹回起点 [origin]，不算移动。
final class CardLinkToggled extends CardRelease {
  const CardLinkToggled({
    required this.cardId,
    required this.targetId,
    required this.releasedAt,
    required this.origin,
  });

  final String cardId;
  final String targetId;
  final Offset releasedAt;
  final Offset origin;
}

/// 在投放区 [zone] 里松手：完成或删除 [cardId]。[releasedAt] 是卡片松手时的
/// 位置，[origin] 是拖动前的位置，保存失败时卡片回到那里。
final class CardDropped extends CardRelease {
  const CardDropped({
    required this.cardId,
    required this.zone,
    required this.releasedAt,
    required this.origin,
  });

  final String cardId;
  final DropZone zone;
  final Offset releasedAt;
  final Offset origin;
}

/// 驱动拖动状态：输入指针的位置和时间，输出 [state]。
class CardDragMachine {
  /// [isLinked] 判断两张卡片之间现在有没有连线（任一方向）。
  CardDragMachine({required this.isLinked});

  final bool Function(String cardId, String otherId) isLinked;

  /// 指针在另一张卡片上停这么久进入 [CardArmed]。
  static const armDelay = Duration(milliseconds: 400);

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

  /// 指针在 [now] 时移动到 [pointer]。[cards] 是画布上的卡片（卡片 ID → 现在
  /// 占的矩形），按从下到上的顺序，用来判断指针停在哪张卡片上。[zone] 是
  /// 指针所在的投放区，不在投放区里时为 null。
  void move(
    Offset pointer, {
    required Map<String, CardBox> cards,
    required Duration now,
    DropZone? zone,
  }) {
    final dragging = switch (_state) {
      final CardPressed pressed
          when (pointer - pressed.pointer).distance > pressed.slop =>
        _dragTo(
          pressed.cardId,
          pressed.origin,
          pointer,
          pressed.origin - pressed.pointer,
        ),
      final CardDragging dragging => _dragTo(
        dragging.cardId,
        dragging.origin,
        pointer,
        dragging.grab,
      ),
      _ => null,
    };
    if (dragging == null) return;
    if (zone != null) {
      _state = CardOverZone(dragging, zone: zone);
      return;
    }
    final targetId = _cardAt(pointer, cards, except: dragging.cardId);
    // 还在同一张卡片上：接着计时，或者保持 armed；换了卡片重新计时。
    _state = switch (_state) {
      _ when targetId == null => dragging,
      CardArmed(targetId: final armed, :final action) when armed == targetId =>
        CardArmed(dragging, targetId: targetId, action: action),
      CardHovering(targetId: final hovered, :final since)
          when hovered == targetId =>
        CardHovering(dragging, targetId: targetId, since: since),
      _ => CardHovering(dragging, targetId: targetId, since: now),
    };
    tick(now);
  }

  /// 时间到了 [now]：在一张卡片上停满 [armDelay] 就进入 [CardArmed]。
  void tick(Duration now) {
    if (_state case final CardHovering hovering
        when now - hovering.since >= armDelay) {
      _state = CardArmed(
        hovering,
        targetId: hovering.targetId,
        action: isLinked(hovering.cardId, hovering.targetId)
            ? LinkAction.unlink
            : LinkAction.link,
      );
    }
  }

  /// 指针抬起，回到 idle。返回松手的结果；没有拖动时返回 null。
  CardRelease? up() {
    final state = _state;
    _state = const CardDragIdle();
    return switch (state) {
      CardOverZone() => CardDropped(
        cardId: state.cardId,
        zone: state.zone,
        releasedAt: state.position,
        origin: state.origin,
      ),
      CardArmed() => CardLinkToggled(
        cardId: state.cardId,
        targetId: state.targetId,
        releasedAt: state.position,
        origin: state.origin,
      ),
      CardDragging(:final cardId, :final position) => CardMoved((
        cardId: cardId,
        position: position,
      )),
      _ => null,
    };
  }

  /// 手势被别的操作抢走（比如捏合缩放画布）：放弃拖动，卡片回到原处。
  void cancel() => _state = const CardDragIdle();

  /// 卡片跟着指针走。画布没有边界，坐标可以是负数。
  CardDragging _dragTo(
    String cardId,
    Offset origin,
    Offset pointer,
    Offset grab,
  ) => CardDragging(
    cardId: cardId,
    origin: origin,
    position: pointer + grab,
    grab: grab,
  );

  /// 指针所在的最上面一张卡片，不算 [except]；不在任何卡片上时为 null。
  static String? _cardAt(
    Offset pointer,
    Map<String, CardBox> cards, {
    required String except,
  }) {
    for (final MapEntry(key: id, value: box)
        in cards.entries.toList().reversed) {
      if (id == except) continue;
      if (Rect.fromLTWH(
        box.x,
        box.y,
        box.width,
        box.height,
      ).contains(pointer)) {
        return id;
      }
    }
    return null;
  }
}
