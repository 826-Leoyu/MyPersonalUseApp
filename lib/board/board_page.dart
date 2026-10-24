import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../formatting/date_format.dart';
import '../planner/day_key.dart';
import '../planner/planner_exceptions.dart';
import 'board_canvas.dart';
import 'board_layout.dart';
import 'board_selection.dart';
import 'completed_page.dart';
import 'date_drawer.dart';
import 'storage_error_page.dart';
import 'trash_page.dart';

/// 画布页面：存储打开后显示顶部标题和当前显示那一天的画布。按可用宽度分两种
/// 布局（见 [wideLayoutMinWidth]）：窄屏时日期收在左侧的抽屉里，宽屏时日期
/// 侧栏常驻在画布左边，可以折叠。两种布局是同一套页面，不按平台区分。
/// 存储打不开、或者读不出画布内容时显示错误页，不显示空画布。
class BoardPage extends ConsumerStatefulWidget {
  const BoardPage({super.key});

  /// 窄屏时标题栏左上角打开日期抽屉的按钮的 key。
  static const dateDrawerButtonKey = ValueKey('date-drawer-button');

  /// 宽屏时标题栏左上角折叠、展开日期侧栏的按钮的 key。
  static const sidebarButtonKey = ValueKey('date-sidebar-button');

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

  /// 宽屏时日期侧栏展开着没有。只在这次运行内记住。
  bool _sidebarOpen = true;

  /// 日期侧栏的 key：换一天时画布整个换掉，侧栏跟着挪到新的画布上，滚到哪里
  /// 还在哪里。
  final _sidebarKey = GlobalKey();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _buildPage(context, wide: constraints.maxWidth >= wideLayoutMinWidth),
  );

  Widget _buildPage(BuildContext context, {required bool wide}) {
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
      // 窄屏时打开日期抽屉，要用画布的 Scaffold 打开，所以放在 Builder 里；
      // 宽屏时折叠、展开日期侧栏。
      leading: wide
          ? IconButton(
              key: BoardPage.sidebarButtonKey,
              tooltip: _sidebarOpen ? '收起日期' : '展开日期',
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: _toggleSidebar,
            )
          : Builder(
              builder: (context) => IconButton(
                key: BoardPage.dateDrawerButtonKey,
                tooltip: '选择日期',
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: Scaffold.of(context).openDrawer,
              ),
            ),
      // 窄屏上放不下时整体缩小，不截断、不和右边的按钮重叠。
      title: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          day == today ? '${formatFullDate(day)} · 今天' : formatFullDate(day),
          maxLines: 1,
        ),
      ),
      actions: [
        Tooltip(
          message: '已完成',
          child: TextButton.icon(
            key: BoardPage.completedButtonKey,
            onPressed: () => _leaveBoardTo(
              (navigator) =>
                  CompletedPage.open(navigator, ref.read(displayedDayProvider)),
            ),
            icon: const Icon(Icons.check_circle_outline),
            // 数量还没读到时只显示图标。
            label: Text('${board.value?.completedCount ?? ''}'),
          ),
        ),
        IconButton(
          key: BoardPage.trashButtonKey,
          tooltip: '回收站',
          onPressed: () => _leaveBoardTo(TrashPage.open),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
    Widget shell({
      required Widget body,
      Widget? floatingActionButton,
      bool dragging = false,
    }) => BoardShell(
      wide: wide,
      appBar: appBar,
      drawer: DateDrawer(onSelect: _selectDay),
      sidebar: _sidebarOpen
          ? DateSidebar(key: _sidebarKey, onSelect: _selectDay)
          : null,
      body: body,
      floatingActionButton: floatingActionButton,
      drawerEnableOpenDragGesture: !dragging,
      // 变宽时抽屉开着，就换成展开的侧栏。
      onWidenedWithDrawerOpen: () => setState(() => _sidebarOpen = true),
    );
    return switch (board) {
      // 画布自己带着页面的 Scaffold，见 [BoardCanvas]。
      AsyncData(:final value) => BoardCanvas(
        // 换一天就换一个画布：拖动、动画这些临时状态不带到另一天。
        key: ValueKey(day),
        shell: shell,
        board: value,
        // 过去的日期不能新建卡片。
        canCreateCards: day >= today,
        transform: _transform,
      ),
      _ => shell(body: const SizedBox.expand()),
    };
  }

  /// 折叠、展开日期侧栏。画布反向平移侧栏让出、占用的宽度，卡片在屏幕上
  /// 的位置不动。
  void _toggleSidebar() {
    final shift = _sidebarOpen ? dateSidebarWidth : -dateSidebarWidth;
    setState(() => _sidebarOpen = !_sidebarOpen);
    _transform.value = Matrix4.translationValues(shift, 0, 0)
      ..multiply(_transform.value);
  }

  /// 在日期抽屉（已经关好）或日期侧栏里选了某一天。选的就是正在显示的那一天时
  /// 不切换：切换会取消选中、清空撤销。
  void _selectDay(DayKey day) {
    if (day == ref.read(displayedDayProvider)) return;
    switchDay(context, ref, (s) => s.showDay(day));
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
