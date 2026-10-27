import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/planner_theme.dart';
import '../mail/mail_items_panel.dart';
import '../planner/day_key.dart';
import 'date_drawer.dart';
import 'date_list.dart';

/// 可用宽度不小于它（逻辑像素）就是宽屏：日期侧栏常驻在画布左边；小于它是
/// 窄屏：日期在左侧的抽屉里。只看宽度，不看平台。
const wideLayoutMinWidth = 840.0;

/// 宽屏时展开的日期侧栏的宽度。
const dateSidebarWidth = 304.0;

/// 宽屏左侧常驻的日期侧栏：浅灰的圆角面板，里面是 [DateList]。点某一天直接
/// 交给 [onSelect]，不用等关上的动画。宽度连同四周的留白一共是
/// [dateSidebarWidth]。
class DateSidebar extends StatelessWidget {
  const DateSidebar({super.key, required this.onSelect});

  /// 点了某一天（包括点「今天」）。
  final ValueChanged<DayKey> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: dateSidebarWidth,
    child: SafeArea(
      right: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          PlannerTheme.space3,
          PlannerTheme.space3,
          0,
          PlannerTheme.space3,
        ),
        child: Material(
          color: PlannerColors.of(context).panel,
          borderRadius: PlannerTheme.panelRadius,
          clipBehavior: Clip.antiAlias,
          child: DateList(onSelect: onSelect),
        ),
      ),
    ),
  );
}

/// 画布页面的外框：页头、左侧的日期抽屉或日期侧栏、[body]（画布）、宽屏时
/// 右侧的"新邮件事项"栏和悬浮按钮。画布和加载中的页面共用它，两种模式下的
/// 结构一样，[body] 在树里的位置不变：跨过断点、折叠侧栏时画布不重建，编辑
/// 的内容和焦点都还在。
///
/// Windows 上抽屉开着时按 Esc 关上抽屉；关着时 Esc 照常交给画布的快捷键。
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
    this.mailPanel,
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

  /// 宽屏时画布右边的"新邮件事项"栏，挤着画布；为 null 时没有栏（收起来了、
  /// 窄屏或者不是 Windows）。
  final Widget? mailPanel;

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
    final mailPanel = widget.wide ? widget.mailPanel : null;
    // 抽屉开着时焦点在抽屉里，按键从抽屉往上传，先到这里，再到画布的快捷键。
    return CallbackShortcuts(
      bindings: {
        // 和画布的快捷键一样只在 Windows 上启用。
        if (_drawerOpen && defaultTargetPlatform == TargetPlatform.windows)
          const SingleActivator(
            LogicalKeyboardKey.escape,
            includeRepeats: false,
          ): () =>
              _scaffoldKey.currentState?.closeDrawer(),
      },
      child: Scaffold(
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
            // 画布带着 key：变窄时左右两边的栏同时拿掉，画布也不会重建。
            Expanded(key: const ValueKey('board-body'), child: widget.body),
            ?mailPanel,
          ],
        ),
        floatingActionButton: widget.floatingActionButton,
      ),
    );
  }
}

/// 宽屏时画布右边的"新邮件事项"栏：浅灰的圆角面板，和左边的日期侧栏一样。
/// 宽度连同四周的留白一共是 [mailItemsPanelWidth]。
class MailItemsSidePanel extends StatelessWidget {
  const MailItemsSidePanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: mailItemsPanelWidth,
    child: SafeArea(
      left: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          0,
          PlannerTheme.space3,
          PlannerTheme.space3,
          PlannerTheme.space3,
        ),
        child: Material(
          color: PlannerColors.of(context).panel,
          borderRadius: PlannerTheme.panelRadius,
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    ),
  );
}
