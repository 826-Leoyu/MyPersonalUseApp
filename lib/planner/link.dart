import 'link_kind.dart';

/// 两张卡片之间的一条连线，方向是 [fromCardId] → [toCardId]；时间都是 UTC。
class Link {
  const Link({
    required this.id,
    required this.fromCardId,
    required this.toCardId,
    required this.kind,
    required this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;

  /// 被拖的卡片。
  final String fromCardId;

  /// 被碰的卡片。
  final String toCardId;
  final LinkKind kind;

  /// 有值就表示连线已断开（软删除）。
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

/// `toggleLink` 的结果：新建了连线，或者断开了已有的连线。
sealed class ToggleLinkResult {
  const ToggleLinkResult(this.linkId);

  /// 新建或断开的那条连线，撤销时用。
  final String linkId;
}

class LinkCreated extends ToggleLinkResult {
  const LinkCreated(super.linkId);
}

class LinkRemoved extends ToggleLinkResult {
  const LinkRemoved(super.linkId);
}
