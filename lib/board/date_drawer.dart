import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../planner/day_key.dart';
import '../planner/planner_exceptions.dart';
import 'board_selection.dart';
import 'date_list.dart';

/// 通过统一的入口切换日期（[switching] 调用 [BoardSelectionController] 的
/// 切换方法），先保存正在编辑的内容。保存失败时提示，停在原来的日期。日期
/// 抽屉、日期侧栏、快捷键和跨午夜的维护都用它。
Future<void> switchDay(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(BoardSelectionController selection) switching,
) async {
  // 切换成功以后画布会整个换掉，提示用切换前拿到的 messenger。
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await switching(ref.read(boardSelectionProvider.notifier));
  } on PlannerException catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(saveFailureMessage(e))));
  }
}

/// 从左边缘拉出日期抽屉的范围。只认边缘，画布其他地方的横向拖动照常是平移
/// 和拖卡片；按住卡片拖动时不认（见 `BoardCanvas` 的 Scaffold）。Android 手势
/// 导航的返回手势占着最边上的一条，范围从它的内侧再往里算
/// [_edgeDragWidth]，不然在边缘一滑就被系统当成返回。
double drawerEdgeDragWidth(BuildContext context) {
  final padding = MediaQuery.paddingOf(context).left;
  final gestureInset = MediaQuery.systemGestureInsetsOf(context).left;
  return math.max(padding, gestureInset) + _edgeDragWidth;
}

/// 系统手势区内侧能起手拉出抽屉的宽度。
const _edgeDragWidth = 25.0;

/// 窄屏左侧的日期抽屉，里面是 [DateList]。
///
/// 点某一天时先关上抽屉，等关上的动画播完才调用 [onSelect]，由页面通过统一的
/// 入口切换日期：画布连同抽屉换一天就重建，先切换的话抽屉来不及播关上的动画。
/// 每次打开都从显示的那一天所在的一周开始。
class DateDrawer extends StatefulWidget {
  const DateDrawer({super.key, required this.onSelect});

  /// 选中某一天（包括点「今天」），抽屉已经关好。
  final ValueChanged<DayKey> onSelect;

  @override
  State<DateDrawer> createState() => _DateDrawerState();
}

class _DateDrawerState extends State<DateDrawer> {
  /// 选好、等抽屉关上再交给 [DateDrawer.onSelect] 的那一天。
  DayKey? _selected;

  @override
  void dispose() {
    // 抽屉关上的动画播完时，Scaffold 才把抽屉的内容拆掉。
    if (_selected case final day?) widget.onSelect(day);
    super.dispose();
  }

  void _select(DayKey day) {
    _selected = day;
    Scaffold.of(context).closeDrawer();
  }

  @override
  Widget build(BuildContext context) => Drawer(
    child: SafeArea(child: DateList(onSelect: _select)),
  );
}
