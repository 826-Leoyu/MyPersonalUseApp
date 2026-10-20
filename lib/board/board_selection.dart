/// 「选择与撤销控制器」里的选中和编辑部分：画布上同一时间最多选中一个
/// 对象，点击规则见 spec 的「点击和选中规则」。撤销栈在 #27 加。
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../planner/task_card.dart';

/// 画布上选中或正在编辑的对象。
sealed class BoardSelection {
  const BoardSelection();
}

/// 什么都没有选中。
final class NothingSelected extends BoardSelection {
  const NothingSelected();
}

/// 选中了一张卡片：显示调整大小的手柄。
final class CardSelected extends BoardSelection {
  const CardSelected(this.cardId);

  final String cardId;
}

/// 正在编辑卡片的标题和备注。退出编辑时保存。
///
/// [title] 和 [note] 是编辑框里的当前内容，由编辑框随输入更新，
/// 不通知界面刷新。
sealed class Editing extends BoardSelection {
  Editing({required this.title, required this.note});

  String title;
  String note;
}

/// 正在编辑一张已有的卡片。退出编辑时标题为空就不保存，保留原来的内容。
final class EditingCard extends Editing {
  EditingCard(TaskCard card) : this._(card.id, card.title, card.note ?? '');

  EditingCard._(this.cardId, String title, String note)
    : super(title: title, note: note);

  final String cardId;
}

/// 正在编辑一张还没保存的新卡片。退出编辑时标题不为空才新建，否则丢弃。
final class EditingNewCard extends Editing {
  EditingNewCard({required this.x, required this.y})
    : super(title: '', note: '');

  /// 新卡片左上角在画布上的位置。
  final double x;
  final double y;
}

/// 管理画布上的选中和编辑状态，把点击翻译成对 PlannerService 的调用。
class BoardSelectionController extends Notifier<BoardSelection> {
  /// 正在进行的保存；保存完成前再次退出编辑时等它，不重复保存。
  Future<void>? _saving;

  @override
  BoardSelection build() => const NothingSelected();

  /// 单击卡片：没选中就选中它；已经选中就进入编辑；正在编辑它时不变。
  Future<void> tapCard(TaskCard card) async {
    switch (state) {
      case CardSelected(:final cardId) when cardId == card.id:
        state = EditingCard(card);
      case EditingCard(:final cardId) when cardId == card.id:
        return;
      default:
        await _finishEditing();
        state = CardSelected(card.id);
    }
  }

  /// 单击空白处：退出编辑并保存，取消选中。
  ///
  /// 保存失败时抛出 PlannerException，仍然停在编辑状态，内容不丢。
  Future<void> tapBlank() async {
    await _finishEditing();
    state = const NothingSelected();
  }

  /// 在画布上以 [center] 为中心新建一张卡片，直接进入标题编辑。
  /// 卡片不会放到画布左上角以外。
  Future<void> newCardAt(Offset center) async {
    await _finishEditing();
    state = EditingNewCard(
      x: math.max(0, center.dx - TaskCard.defaultWidth / 2),
      y: math.max(0, center.dy - TaskCard.defaultHeight / 2),
    );
  }

  /// 正在编辑时保存编辑的内容；没有在编辑时什么也不做。
  Future<void> _finishEditing() =>
      _saving ??= _saveEditing().whenComplete(() => _saving = null);

  Future<void> _saveEditing() async {
    final editing = state;
    if (editing is! Editing) return;
    final title = editing.title.trim();
    // 标题为空：新卡片丢弃，已有的卡片保留原来的内容。
    if (title.isEmpty) return;
    final note = editing.note.trim().isEmpty ? null : editing.note;
    final service = await ref.read(plannerServiceProvider.future);
    switch (editing) {
      case EditingCard(:final cardId):
        await service.updateCardContent(cardId, title: title, note: note);
      case EditingNewCard(:final x, :final y):
        final card = await service.createCard(
          ref.read(displayedDayProvider),
          x: x,
          y: y,
          title: title,
        );
        if (note == null) return;
        // 卡片已经建好，接下来只是补上备注。补备注失败时停在编辑这张卡片的
        // 状态，再次保存只会更新它，不会再新建一张。
        state = EditingCard._(card.id, editing.title, editing.note);
        await service.updateCardContent(card.id, title: title, note: note);
    }
  }
}

/// 画布的选中和编辑状态。
final boardSelectionProvider =
    NotifierProvider<BoardSelectionController, BoardSelection>(
      BoardSelectionController.new,
    );
