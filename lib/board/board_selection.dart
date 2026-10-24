/// 「选择与撤销控制器」：画布上同一时间最多选中一个对象，点击规则见 spec 的
/// 「点击和选中规则」；撤销栈见 spec 的「撤销栈」。
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../planner/day_key.dart';
import '../planner/link.dart';
import '../planner/planner_exceptions.dart';
import '../planner/planner_service.dart';
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

/// 按一次 Ctrl+Z 的结果。
sealed class UndoResult {
  const UndoResult();
}

/// 撤销栈是空的，什么都没做。
final class NothingToUndo extends UndoResult {
  const NothingToUndo();
}

/// 撤销了一条操作，[cardId] 是它动到的卡片（移回原处、取消完成、从回收站
/// 拿回来的那张）；撤销连线和断开时为 null。
final class Undone extends UndoResult {
  const Undone(this.cardId);

  final String? cardId;
}

/// 撤销失败（比如那张卡片已经不在原来的状态了），这一条已经丢掉。
final class CannotUndo extends UndoResult {
  const CannotUndo();
}

/// 撤销栈里的一条操作：[cardId] 见 [Undone]，[undo] 把它撤销掉。
final class _UndoEntry {
  const _UndoEntry(this.undo, {this.cardId});

  final String? cardId;
  final Future<void> Function(PlannerService service) undo;
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
  Future<String?>? _saving;

  /// 最后一次排上队的切换日期。切换日期按先后顺序一个一个完成，后来的
  /// 不会被先来的、还没查完的覆盖掉。
  Future<void> _switchingDay = Future.value();

  /// 撤销栈最多记这么多条，再多就丢掉最早的。
  static const undoLimit = 50;

  /// 撤销栈，最后一条是最近的操作。只存在内存里，切换日期和顺延时清空。
  final _undoStack = <_UndoEntry>[];

  /// 最后一次排上队的撤销。连按 Ctrl+Z 时一条一条按顺序撤销。
  Future<void> _undoing = Future.value();

  /// 还在保存、成功后要记进撤销栈的操作（失败也算完成）。
  final _recording = <Future<void>>{};

  /// 撤销栈每清空一次加一；保存期间变了的操作不记进撤销栈。
  var _undoGeneration = 0;

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

  /// 切换到前后 [days] 天（Windows 的 ← / → 快捷键），规则同 [showDay]。从
  /// 排到它时显示的那一天算起：前一次还没切完时再按，也是接着往前走，不会
  /// 两次切到同一天。
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

  /// 拖动卡片后松手：把卡片从 [from] 移到 [to]，记进撤销栈。碰撞后弹回原位
  /// 不算移动，不走这里。
  ///
  /// 保存失败时抛出 PlannerException，不记进撤销栈。
  Future<void> moveCard(
    String cardId, {
    required Offset from,
    required Offset to,
  }) => _record((service) async {
    await service.moveCard(cardId, x: to.dx, y: to.dy);
    return _UndoEntry(
      (service) => service.moveCard(cardId, x: from.dx, y: from.dy),
      cardId: cardId,
    );
  });

  /// 删除卡片（菜单、Delete 键，或拖进 🗑️ 区）：把卡片移到回收站，记进
  /// 撤销栈；它是选中的就取消选中。
  ///
  /// 删除失败时抛出 PlannerException，选中状态不变。
  Future<void> deleteCard(String cardId) async {
    await _record((service) async {
      await service.deleteCard(cardId);
      return _UndoEntry(
        (service) => service.restoreCard(cardId),
        cardId: cardId,
      );
    });
    if (state case CardSelected(cardId: final selected)
        when selected == cardId) {
      state = const NothingSelected();
    }
  }

  /// 完成卡片（双击、Ctrl+Enter，或拖进 ✅ 区），记进撤销栈；它是选中的
  /// 就取消选中。
  ///
  /// 完成失败时抛出 PlannerException，选中状态不变。
  Future<void> completeCard(String cardId) async {
    await _record((service) async {
      await service.completeCard(cardId);
      return _UndoEntry(
        (service) => service.uncompleteCard(cardId),
        cardId: cardId,
      );
    });
    if (state case CardSelected(cardId: final selected)
        when selected == cardId) {
      state = const NothingSelected();
    }
  }

  /// 拖着 [draggedId] 碰到 [targetId] 后松手：两者之间有连线就断开，没有就
  /// 新建一条，记进撤销栈。卡片弹回原位不算移动。
  ///
  /// 保存失败时抛出 PlannerException，不记进撤销栈。
  Future<void> toggleLink(String draggedId, String targetId) =>
      _record((service) async {
        return switch (await service.toggleLink(draggedId, targetId)) {
          LinkCreated(:final linkId) => _UndoEntry(
            (service) => service.removeLink(linkId),
          ),
          LinkRemoved(:final linkId) => _UndoEntry(
            (service) => service.restoreLink(linkId),
          ),
        };
      });

  /// 断开连线（✂️ 或右键菜单），记进撤销栈；它是选中的就取消选中。
  ///
  /// 断开失败时抛出 PlannerException，选中状态不变。
  Future<void> removeLink(String linkId) async {
    await _record((service) async {
      await service.removeLink(linkId);
      return _UndoEntry((service) => service.restoreLink(linkId));
    });
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

  /// 撤销最近的一条操作（Ctrl+Z）。连按时按顺序一条一条撤销。撤销失败时
  /// 丢掉这一条，返回 [CannotUndo]。
  Future<UndoResult> undo() {
    final result = _undoing.then((_) async {
      // 还在保存的操作保存好、记进撤销栈以后再撤销，按相反的顺序撤销。
      await Future.wait(_recording);
      if (_undoStack.isEmpty) return const NothingToUndo();
      final entry = _undoStack.removeLast();
      try {
        await entry.undo(await ref.read(plannerServiceProvider.future));
      } on PlannerException {
        return const CannotUndo();
      }
      return Undone(entry.cardId);
    });
    _undoing = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// 清空撤销栈（切换日期、执行了顺延的每日维护）。正在撤销的那一条照常
  /// 完成；还在保存的操作保存好以后也不再记进来。
  void clearUndo() {
    _undoStack.clear();
    _undoGeneration++;
  }

  /// 执行一次要记进撤销栈的写入 [write]，成功后把它返回的撤销动作记进
  /// 撤销栈，超过 [undoLimit] 时丢掉最早的。保存期间撤销栈被清空过时不记。
  ///
  /// 写入失败时抛出 PlannerException，不记进撤销栈。
  Future<void> _record(
    Future<_UndoEntry> Function(PlannerService service) write,
  ) {
    final generation = _undoGeneration;
    final result = () async {
      final entry = await write(await ref.read(plannerServiceProvider.future));
      if (generation != _undoGeneration) return;
      _undoStack.add(entry);
      if (_undoStack.length > undoLimit) _undoStack.removeAt(0);
    }();
    final settled = result.then((_) {}, onError: (_) {});
    _recording.add(settled);
    settled.whenComplete(() => _recording.remove(settled));
    return result;
  }

  /// 等前面排队的切换日期都完成了再执行 [action]。前面的失败不影响后面的。
  Future<T> _switchDay<T>(Future<T> Function() action) {
    final result = _switchingDay.then((_) => action());
    _switchingDay = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// 换到 [day] 并取消选中、清空撤销栈：选中、编辑和撤销都只属于当时显示的
  /// 那一天。调用前要先保存正在编辑的内容。
  void _show(DayKey day) {
    ref.read(displayedDayProvider.notifier)._set(day);
    state = const NothingSelected();
    clearUndo();
  }

  /// 离开画布去别的页面（例如「已完成」列表）：先保存正在编辑的内容，再
  /// 取消选中。
  ///
  /// 保存失败时抛出 PlannerException，仍然停在编辑状态，内容不丢。
  Future<void> leaveBoard() => stopEditing();

  /// 保存正在编辑的内容并退出编辑，取消选中，返回编辑的那张卡片的 id
  /// （新卡片是刚建好的那张）。标题为空的新卡片丢弃，返回 null；没在编辑时
  /// 也返回 null。
  ///
  /// 保存失败时抛出 PlannerException，仍然停在编辑状态，内容不丢。
  Future<String?> stopEditing() async {
    final cardId = await _finishEditing();
    state = const NothingSelected();
    return cardId;
  }

  /// 单击空白处：和离开画布一样，退出编辑并保存，取消选中。
  ///
  /// 保存失败时抛出 PlannerException，仍然停在编辑状态，内容不丢。
  Future<void> tapBlank() => leaveBoard();

  /// 跨过了午夜、执行每日维护之前：保存正在编辑的内容，取消选中。这样改好
  /// 的内容跟着卡片一起顺延，历史记录也记下改好的标题。和切换日期一样排队，
  /// 不和还没完成的切换日期同时保存。
  ///
  /// 保存失败时抛出 PlannerException，仍然停在编辑状态，内容不丢。
  Future<void> startNewDay() => _switchDay(leaveBoard);

  /// 在画布上以 [center] 为中心新建一张卡片，直接进入标题编辑。
  /// 卡片不会放到画布左上角以外。
  Future<void> newCardAt(Offset center) async {
    await _finishEditing();
    state = EditingNewCard(
      x: math.max(0, center.dx - TaskCard.defaultWidth / 2),
      y: math.max(0, center.dy - TaskCard.defaultHeight / 2),
    );
  }

  /// 正在编辑时保存编辑的内容，返回编辑的那张卡片的 id；没有在编辑时什么
  /// 也不做，返回 null。
  Future<String?> _finishEditing() =>
      _saving ??= _saveEditing().whenComplete(() => _saving = null);

  Future<String?> _saveEditing() async {
    final editing = state;
    if (editing is! Editing) return null;
    final title = editing.title.trim();
    // 标题为空：新卡片丢弃，已有的卡片保留原来的内容。
    if (title.isEmpty) {
      return switch (editing) {
        EditingCard(:final cardId) => cardId,
        EditingNewCard() => null,
      };
    }
    final note = editing.note.trim().isEmpty ? null : editing.note;
    final service = await ref.read(plannerServiceProvider.future);
    switch (editing) {
      case EditingCard(:final cardId):
        await service.updateCardContent(cardId, title: title, note: note);
        return cardId;
      case EditingNewCard(:final x, :final y):
        final card = await service.createCard(
          _dayForNewCard(),
          x: x,
          y: y,
          title: title,
        );
        if (note == null) return card.id;
        // 卡片已经建好，接下来只是补上备注。补备注失败时停在编辑这张卡片的
        // 状态，再次保存只会更新它，不会再新建一张。
        state = EditingCard._(card.id, editing.title, editing.note);
        await service.updateCardContent(card.id, title: title, note: note);
        return card.id;
    }
  }

  /// 新卡片存到哪一天：显示的那一天。草稿开始以后跨过了午夜、那一天已经
  /// 过去时不能再新建，存到今天，草稿的内容不丢。
  DayKey _dayForNewCard() {
    final displayed = ref.read(displayedDayProvider);
    final today = DayKey.fromDateTime(ref.read(clockProvider).now());
    return displayed < today ? today : displayed;
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
