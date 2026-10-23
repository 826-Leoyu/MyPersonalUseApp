import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../formatting/date_format.dart';
import '../planner/planner_exceptions.dart';
import 'board_canvas.dart';
import 'board_selection.dart';
import 'completed_page.dart';
import 'date_bar.dart';
import 'storage_error_page.dart';
import 'trash_page.dart';

/// 画布页面：存储打开后显示顶部标题、日期栏和当前显示那一天的画布。存储打不开、或者读不出
/// 画布内容时显示错误页，不显示空画布。
class BoardPage extends ConsumerStatefulWidget {
  const BoardPage({super.key});

  /// 标题栏上打开「已完成」列表的按钮的 key。
  static const completedButtonKey = ValueKey('completed-button');

  /// 标题栏上打开回收站的按钮的 key。
  static const trashButtonKey = ValueKey('trash-button');

  @override
  ConsumerState<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends ConsumerState<BoardPage> {
  /// 画布的平移和缩放。换一天时画布重建，平移和缩放保持不变。
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayProvider);
    final day = ref.watch(displayedDayProvider);
    // 画布内容依赖打开好的 service，所以打不开时这里也是错误状态。
    final board = ref.watch(dayBoardProvider(day));
    if (board case AsyncError(:final error)) {
      return StorageErrorPage(
        error: error,
        // 重新打开存储；画布内容随之重新读取。
        onRetry: () => ref.invalidate(plannerServiceProvider),
      );
    }
    final appBar = AppBar(
      title: Text(
        day == today ? '${formatFullDate(day)} · 今天' : formatFullDate(day),
      ),
      actions: [
        TextButton.icon(
          key: BoardPage.completedButtonKey,
          onPressed: () => _leaveBoardTo(
            (navigator) =>
                CompletedPage.open(navigator, ref.read(displayedDayProvider)),
          ),
          icon: const Icon(Icons.check_circle_outline),
          // 数量还没读到时只显示文字。
          label: Text(switch (board.value?.completedCount) {
            final count? => '已完成 $count',
            null => '已完成',
          }),
        ),
        IconButton(
          key: BoardPage.trashButtonKey,
          tooltip: '回收站',
          onPressed: () => _leaveBoardTo(TrashPage.open),
          icon: const Icon(Icons.delete_outline),
        ),
        // 一直显示，位置不跳；已经在今天时点不了。
        TextButton(
          onPressed: day == today
              ? null
              : () => switchDay(context, ref, (s) => s.showDay(today)),
          child: const Text('今天'),
        ),
      ],
      bottom: const DateBar(),
    );
    return switch (board) {
      // 画布自己带着页面的 Scaffold，见 [BoardCanvas]。
      AsyncData(:final value) => BoardCanvas(
        // 换一天就换一个画布：拖动、动画这些临时状态不带到另一天。
        key: ValueKey(day),
        appBar: appBar,
        board: value,
        // 过去的日期不能新建卡片。
        canCreateCards: day >= today,
        transform: _transform,
      ),
      _ => Scaffold(appBar: appBar),
    };
  }

  /// 从画布打开别的页面（已完成列表、回收站）：先保存正在编辑的内容，保存
  /// 失败时提示，不打开。
  Future<void> _leaveBoardTo(
    Future<void> Function(NavigatorState navigator) open,
  ) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref.read(boardSelectionProvider.notifier).leaveBoard();
    } on PlannerException catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(saveFailureMessage(e))));
      return;
    }
    await open(navigator);
  }
}
