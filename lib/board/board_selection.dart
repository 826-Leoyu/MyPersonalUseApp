/// 「选择与撤销控制器」里的选中和编辑部分：画布上同一时间最多选中一个
/// 对象，点击规则见 spec 的「点击和选中规则」。撤销栈在 #27 加。
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../planner/day_key.dart';
import '../planner/planner_exceptions.dart';
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

/// 选中了一条连线：高亮，中点显示 ✂️。
final class LinkSelected extends BoardSelection {
  const LinkSelected(this.linkId);

  final String linkId;
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

/// 单击历史记录以后的结果。
enum CarryOverJump {
  /// 卡片还在画布上：跳到它所在的日期并选中了它。
  selected,

  /// 卡片已完成：跳到了它所在的日期，没有选中。
  completed,

  /// 卡片在回收站里：不跳转。
  inTrash,

  /// 卡片已经不存在：不跳转。
  missing,

  /// 读不出卡片现在在哪：不跳转。
  unreadable,
}

/// 画布正在显示哪一天，默认是今天。
///
/// 只能通过 [BoardSelectionController] 切换日期（[BoardSelectionController.showDay]
/// 和点历史记录跳转）：它先保存正在编辑的内容，保存成功才切换，编辑的内容
/// 不会因为换了一天而丢掉。
///
/// 只在启动时取一次今天，之后「今天」变了也不跟着变：不能绕过统一的入口
/// 把用户选的日期和正在编辑的内容丢掉。
class DisplayedDayController extends Notifier<DayKey> {
  @override
  DayKey build() => ref.read(todayProvider);

  void _set(DayKey day) => state = day;
}

/// 画布正在显示哪一天。
final displayedDayProvider = NotifierProvider<DisplayedDayController, DayKey>(
  DisplayedDayController.new,
);

/// 管理画布上的选中和编辑状态，把点击翻译成对 PlannerService 的调用。
class BoardSelectionController extends Notifier<BoardSelection> {
  /// 正在进行的保存；保存完成前再次退出编辑时等它，不重复保存。
  Future<void>? _saving;

  /// 最后一次排上队的切换日期。切换日期按先后顺序一个一个完成，后来的
  /// 不会被先来的、还没查完的覆盖掉。
  Future<void> _switchingDay = Future.value();

  @override
  BoardSelection build() => const NothingSelected();

  /// 切换到 [day]：先保存正在编辑的内容，保存成功才切换，并取消选中。
  /// 标题为空时按退出编辑的规则处理（新卡片丢弃，已有的卡片保留原来的内容）。
  ///
  /// 保存失败时抛出 PlannerException，停在原来的日期和编辑状态，内容不丢。
  Future<void> showDay(DayKey day) => _switchDay(() async {
    await _finishEditing();
    _show(day);
  });

  /// 切换到前后 [days] 天（◀ / ▶），规则同 [showDay]。从排到它时显示的那一天
  /// 算起：前一次还没切完时再点，也是接着往前走，不会两次切到同一天。
  Future<void> showDayOffset(int days) => _switchDay(() async {
    await _finishEditing();
    _show(ref.read(displayedDayProvider).addDays(days));
  });

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

  /// 单击（或双击）连线：先保存正在编辑的卡片，再选中这条连线。
  ///
  /// 保存失败时抛出 PlannerException，仍然停在编辑状态，内容不丢。
  Future<void> tapLink(String linkId) async {
    await _finishEditing();
    state = LinkSelected(linkId);
  }

  /// 卡片菜单里的「编辑」：先保存正在编辑的其他卡片，再编辑这张。
  ///
  /// 保存失败时抛出 PlannerException，仍然停在原来的编辑状态，内容不丢。
  Future<void> editCard(TaskCard card) async {
    await _finishEditing();
    state = EditingCard(card);
  }

  /// 卡片菜单里的「删除」：把卡片移到回收站；它是选中的就取消选中。
  ///
  /// 删除失败时抛出 PlannerException，选中状态不变。
  Future<void> deleteCard(String cardId) async {
    final service = await ref.read(plannerServiceProvider.future);
    await service.deleteCard(cardId);
    if (state case CardSelected(cardId: final selected)
        when selected == cardId) {
      state = const NothingSelected();
    }
  }

  /// 完成卡片（双击，或拖进 ✅ 区）；它是选中的就取消选中。
  ///
  /// 完成失败时抛出 PlannerException，选中状态不变。
  Future<void> completeCard(String cardId) async {
    final service = await ref.read(plannerServiceProvider.future);
    await service.completeCard(cardId);
    if (state case CardSelected(cardId: final selected)
        when selected == cardId) {
      state = const NothingSelected();
    }
  }

  /// 断开连线（✂️ 或右键菜单）；它是选中的就取消选中。
  ///
  /// 断开失败时抛出 PlannerException，选中状态不变。
  Future<void> removeLink(String linkId) async {
    final service = await ref.read(plannerServiceProvider.future);
    await service.removeLink(linkId);
    forgetLink(linkId);
  }

  /// 连线不再显示了（断开、或者一端完成、删除了）：它是选中的就取消选中。
  void forgetLink(String linkId) {
    if (state case LinkSelected(linkId: final selected)
        when selected == linkId) {
      state = const NothingSelected();
    }
  }

  /// 单击历史记录：先查这张卡片现在在哪，再保存正在编辑的卡片（并退出
  /// 编辑），然后按卡片现在的状态跳转，见 [CarryOverJump]。卡片现在在哪由
  /// 存储里的真实状态决定，不看历史记录里的日期。
  ///
  /// 保存失败时抛出 PlannerException，仍然停在编辑状态，不跳转；这时即使
  /// 查卡片也失败了，也按保存失败处理。
  Future<CarryOverJump> openCarryOverRecord(String cardId) =>
      _switchDay(() async {
        // 先查卡片在哪再保存：保存完马上切换，中间不再等，查的时候输入的内容
        // 也一起保存了。
        final service = await ref.read(plannerServiceProvider.future);
        CardLocation? location;
        CarryOverJump? stay;
        try {
          location = await service.findCard(cardId);
          if (location.inTrash) stay = CarryOverJump.inTrash;
        } on NotFound {
          stay = CarryOverJump.missing;
        } on StorageFailure {
          stay = CarryOverJump.unreadable;
        }
        await _finishEditing();
        if (stay != null) {
          state = const NothingSelected();
          return stay;
        }
        _show(location!.dayKey);
        if (location.status == CardStatus.completed) {
          return CarryOverJump.completed;
        }
        state = CardSelected(cardId);
        return CarryOverJump.selected;
      });

  /// 等前面排队的切换日期都完成了再执行 [action]。前面的失败不影响后面的。
  Future<T> _switchDay<T>(Future<T> Function() action) {
    final result = _switchingDay.then((_) => action());
    _switchingDay = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// 换到 [day] 并取消选中：选中和编辑都只属于当时显示的那一天。调用前
  /// 要先保存正在编辑的内容。
  void _show(DayKey day) {
    ref.read(displayedDayProvider.notifier)._set(day);
    state = const NothingSelected();
  }

  /// 离开画布去别的页面（例如「已完成」列表）：先保存正在编辑的内容，再
  /// 取消选中。
  ///
  /// 保存失败时抛出 PlannerException，仍然停在编辑状态，内容不丢。
  Future<void> leaveBoard() async {
    await _finishEditing();
    state = const NothingSelected();
  }

  /// 单击空白处：和离开画布一样，退出编辑并保存，取消选中。
  ///
  /// 保存失败时抛出 PlannerException，仍然停在编辑状态，内容不丢。
  Future<void> tapBlank() => leaveBoard();

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

/// 保存失败时给用户看的提示：输入不合规时说明原因，其他情况请用户重试。
String saveFailureMessage(PlannerException error) =>
    error is InvalidInput ? error.message : '保存失败，请重试';

/// 画布的选中和编辑状态。
final boardSelectionProvider =
    NotifierProvider<BoardSelectionController, BoardSelection>(
      BoardSelectionController.new,
    );
