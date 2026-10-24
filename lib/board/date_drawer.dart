import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/planner_theme.dart';
import '../app/providers.dart';
import '../formatting/date_format.dart';
import '../planner/day_key.dart';
import '../planner/planner_exceptions.dart';
import 'board_selection.dart';

/// 通过统一的入口切换日期（[switching] 调用 [BoardSelectionController] 的
/// 切换方法），先保存正在编辑的内容。保存失败时提示，停在原来的日期。日期
/// 抽屉、快捷键和跨午夜的维护都用它。
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

/// 左侧的日期抽屉：按周分组竖着列出日期（周一到周日），可以一直往前后滚，
/// 顶部有上一周、下一周和「今天」。画布正在显示的那一天用强调色填充，今天
/// 用强调色描边并标上「今天」。
///
/// 点某一天时先关上抽屉，等关上的动画播完才调用 [onSelect]，由页面通过统一的
/// 入口切换日期：画布连同抽屉换一天就重建，先切换的话抽屉来不及播关上的动画。
/// 每次打开都从显示的那一天所在的一周开始。
class DateDrawer extends ConsumerStatefulWidget {
  const DateDrawer({super.key, required this.onSelect});

  /// 某一天那一行，测试用。
  static ValueKey<String> dayKey(DayKey day) =>
      ValueKey('date-drawer-day-$day');

  /// 某一周的分组，测试用。[start] 是那一周的周一。
  static ValueKey<String> weekKey(DayKey start) =>
      ValueKey('date-drawer-week-$start');

  /// 一行里的未完成数，测试用。
  static const countKey = ValueKey('date-drawer-count');

  /// 「今天」按钮的 key。
  static const todayButtonKey = ValueKey('date-drawer-today');

  /// 选中某一天（包括点「今天」），抽屉已经关好。
  final ValueChanged<DayKey> onSelect;

  @override
  ConsumerState<DateDrawer> createState() => _DateDrawerState();
}

class _DateDrawerState extends ConsumerState<DateDrawer> {
  /// 每一行的高度，也是点击范围的高度。
  static const _rowHeight = 48.0;

  /// 每一周顶部日期范围的高度。
  static const _headerHeight = 36.0;

  /// 一周占的高度：每一周一样高，翻周时可以直接算出滚到哪里。
  static const _weekExtent = _headerHeight + 7 * _rowHeight + 8;

  /// 滚动位置 0 是打开时显示的那一天所在的一周，往上是更早的周。
  late final DayKey _anchor = _weekStart(ref.read(displayedDayProvider));
  final _centerKey = UniqueKey();
  final _scroll = ScrollController();

  /// 选好、等抽屉关上再交给 [DateDrawer.onSelect] 的那一天。
  DayKey? _selected;

  @override
  void dispose() {
    _scroll.dispose();
    // 抽屉关上的动画播完时，Scaffold 才把抽屉的内容拆掉。
    if (_selected case final day?) widget.onSelect(day);
    super.dispose();
  }

  void _select(DayKey day) {
    _selected = day;
    Scaffold.of(context).closeDrawer();
  }

  /// 往前后翻 [weeks] 周，停在一周的开头。
  void _scrollWeeks(int weeks) {
    final current = (_scroll.offset / _weekExtent).round();
    _scroll.animateTo(
      (current + weeks) * _weekExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _week(DayKey start) => SizedBox(
    height: _weekExtent,
    child: _Week(
      key: DateDrawer.weekKey(start),
      start: start,
      headerHeight: _headerHeight,
      rowHeight: _rowHeight,
      onSelect: _select,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Drawer(
      backgroundColor: PlannerTheme.paper,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
              child: Row(
                children: [
                  Expanded(child: Text('选择日期', style: textTheme.titleMedium)),
                  IconButton(
                    tooltip: '上一周',
                    icon: const Icon(Icons.keyboard_arrow_up),
                    onPressed: () => _scrollWeeks(-1),
                  ),
                  IconButton(
                    tooltip: '下一周',
                    icon: const Icon(Icons.keyboard_arrow_down),
                    onPressed: () => _scrollWeeks(1),
                  ),
                  TextButton(
                    key: DateDrawer.todayButtonKey,
                    onPressed: () => _select(ref.read(todayProvider)),
                    child: const Text('今天'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: CustomScrollView(
                controller: _scroll,
                center: _centerKey,
                slivers: [
                  // 打开时那一周之前的周，从近到远往上排。
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _week(_anchor.addDays(-7 * (i + 1))),
                    ),
                  ),
                  SliverList(
                    key: _centerKey,
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _week(_anchor.addDays(7 * i)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 抽屉里的一周：顶部是日期范围，下面从 [start]（周一）起七行。
class _Week extends ConsumerWidget {
  const _Week({
    super.key,
    required this.start,
    required this.headerHeight,
    required this.rowHeight,
    required this.onSelect,
  });

  final DayKey start;
  final double headerHeight;
  final double rowHeight;
  final ValueChanged<DayKey> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(displayedDayProvider);
    final today = ref.watch(todayProvider);
    // 数量还没读到或读不出来时不显示，照常能点。
    final counts = ref.watch(weekCountsProvider(start)).value;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: headerHeight,
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
                child: Text(
                  '${formatShortDate(start)} – '
                  '${formatShortDate(start.addDays(6))}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ),
            ),
          ),
          for (final day in List.generate(7, start.addDays))
            SizedBox(
              height: rowHeight,
              child: _DayRow(
                day: day,
                selected: day == selected,
                isToday: day == today,
                activeCount: counts?[day]?.activeCount,
                onTap: () => onSelect(day),
              ),
            ),
        ],
      ),
    );
  }
}

/// 抽屉里的一行：星期、`Oct 20`，今天带「今天」标记，右边是未完成数（为 0
/// 时颜色淡一些）。
class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.activeCount,
    required this.onTap,
  });

  final DayKey day;
  final bool selected;
  final bool isToday;

  /// 未完成数；为 null 时还没读到，不显示。
  final int? activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = formatDateDrawerLabel(day);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final color = selected ? Colors.white : null;
    final count = activeCount;
    return Semantics(
      key: DateDrawer.dayKey(day),
      container: true,
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: selected ? PlannerTheme.accent : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(8)),
            // 今天但没选中时描边，和选中的填充区分开。
            side: isToday && !selected
                ? const BorderSide(color: PlannerTheme.accent, width: 1.5)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      label.weekday,
                      style: textTheme.bodyMedium?.copyWith(
                        color: color ?? theme.hintColor,
                      ),
                    ),
                  ),
                  Text(
                    label.date,
                    style: textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: isToday ? FontWeight.bold : null,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Text(
                      '今天',
                      style: textTheme.labelSmall?.copyWith(
                        color: color ?? PlannerTheme.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (count != null)
                    Text(
                      '$count',
                      key: DateDrawer.countKey,
                      style: textTheme.labelLarge?.copyWith(
                        color: count == 0
                            ? (color ?? theme.hintColor).withValues(alpha: 0.6)
                            : (color ?? PlannerTheme.accent),
                        fontWeight: count == 0 ? null : FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [day] 所在那一周的周一。
DayKey _weekStart(DayKey day) =>
    day.addDays(1 - DateTime.utc(day.year, day.month, day.day).weekday);
