import 'package:flutter/material.dart';

import '../app/planner_theme.dart';
import '../planner/day_key.dart';
import 'date_drawer.dart';
import 'date_list.dart';

/// 可用宽度不小于它（逻辑像素）就是宽屏：日期侧栏常驻在画布左边；小于它是
/// 窄屏：日期在左侧的抽屉里。只看宽度，不看平台。
const wideLayoutMinWidth = 840.0;

/// 宽屏时展开的日期侧栏的宽度。
const dateSidebarWidth = 304.0;

/// 宽屏左侧常驻的日期侧栏，里面是 [DateList]。点某一天直接交给 [onSelect]，
/// 不用等关上的动画。
class DateSidebar extends StatelessWidget {
  const DateSidebar({super.key, required this.onSelect});

  /// 点了某一天（包括点「今天」）。
  final ValueChanged<DayKey> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: dateSidebarWidth,
    child: Material(
      color: PlannerTheme.paper,
      child: SafeArea(right: false, child: DateList(onSelect: onSelect)),
    ),
  );
}

/// 画布页面的外框：页头、左侧的日期抽屉或日期侧栏、[body]（画布）和悬浮
/// 按钮。画布和加载中的页面共用它，两种模式下的结构一样，[body] 在树里的
/// 位置不变：跨过断点、折叠侧栏时画布不重建，编辑的内容和焦点都还在。
///
/// 窄屏时抽屉开着、变成宽屏后，先关上抽屉（不然 Scaffold 记着抽屉开着，再变
/// 窄时抽屉自己又出来），再调用 [onWidenedWithDrawerOpen]。
class BoardShell extends StatefulWidget {
  const BoardShell({
    super.key,
    required this.wide,
    required this.appBar,
    required this.drawer,
    required this.sidebar,
    required this.body,
    this.floatingActionButton,
    this.drawerEnableOpenDragGesture = true,
    this.onWidenedWithDrawerOpen,
  });

  /// 是不是宽屏，见 [wideLayoutMinWidth]。
  final bool wide;

  final PreferredSizeWidget appBar;

  /// 窄屏时的日期抽屉，盖在画布上面，不挤动卡片。宽屏时不用。
  final Widget drawer;

  /// 宽屏时画布左边的日期侧栏，挤着画布；为 null 时侧栏折叠起来（或者是
  /// 窄屏），画布占满宽度。
  final Widget? sidebar;

  final Widget body;

  final Widget? floatingActionButton;

  /// 窄屏时能不能从左边缘拉出抽屉。宽屏时一律不能。
  final bool drawerEnableOpenDragGesture;

  /// 抽屉开着时变成宽屏，抽屉已经关上。
  final VoidCallback? onWidenedWithDrawerOpen;

  @override
  State<BoardShell> createState() => _BoardShellState();
}

class _BoardShellState extends State<BoardShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// 抽屉开着没有。变成宽屏时抽屉还开着，就先留着它，等关上再拿掉。
  bool _drawerOpen = false;

  @override
  void didUpdateWidget(BoardShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wide && !oldWidget.wide && _drawerOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scaffoldKey.currentState?.closeDrawer();
        widget.onWidenedWithDrawerOpen?.call();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sidebar = widget.wide ? widget.sidebar : null;
    return Scaffold(
      key: _scaffoldKey,
      appBar: widget.appBar,
      drawer: !widget.wide || _drawerOpen ? widget.drawer : null,
      onDrawerChanged: (open) => setState(() => _drawerOpen = open),
      drawerEdgeDragWidth: drawerEdgeDragWidth(context),
      drawerEnableOpenDragGesture:
          !widget.wide && widget.drawerEnableOpenDragGesture,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?sidebar,
          // 有没有侧栏，画布都是最后一个，不会因为多了侧栏而重建。
          Expanded(child: widget.body),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }
}
