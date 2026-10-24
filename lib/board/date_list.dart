import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/planner_theme.dart';
import '../app/providers.dart';
import '../formatting/date_format.dart';
import '../planner/day_key.dart';
import 'board_selection.dart';

/// 日期列表：按周分组竖着列出日期（周一到周日），可以一直往前后滚，顶部有
/// 上一周、下一周和「今天」。画布正在显示的那一天用米色高亮、文字加粗，今天
/// 用强调色标上「今天」，每一行带未完成数。
///
/// 窄屏的日期抽屉（`DateDrawer`）和宽屏的日期侧栏（`DateSidebar`）都用它。
/// 从建好时显示的那一天所在的一周开始。
class DateList extends ConsumerStatefulWidget {
  const DateList({super.key, required this.onSelect});

  /// 某一天那一行，测试用。
  static ValueKey<String> dayKey(DayKey day) => ValueKey('date-list-day-$day');

  /// 某一周的分组，测试用。[start] 是那一周的周一。
  static ValueKey<String> weekKey(DayKey start) =>
      ValueKey('date-list-week-$start');

  /// 一行里的未完成数，测试用。
  static const countKey = ValueKey('date-list-count');

  /// 「今天」按钮的 key。
  static const todayButtonKey = ValueKey('date-list-today');

  /// 点了某一天（包括点「今天」）。点的是正在显示的那一天时也照样调用，由
  /// 外面决定切不切换。
  final ValueChanged<DayKey> onSelect;

  @override
  ConsumerState<DateList> createState() => _DateListState();
}

class _DateListState extends ConsumerState<DateList> {
  /// 每一行的高度，也是点击范围的高度。
  static const _rowHeight = 48.0;

  /// 每一周顶部日期范围的高度。
  static const _headerHeight = 36.0;

  /// 一周占的高度：每一周一样高，翻周时可以直接算出滚到哪里。
  static const _weekExtent =
      _headerHeight + 7 * _rowHeight + PlannerTheme.space2;

  /// 滚动位置 0 是建好时显示的那一天所在的一周，往上是更早的周。
  late final DayKey _anchor = _weekStart(ref.read(displayedDayProvider));
  final _centerKey = UniqueKey();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
      key: DateList.weekKey(start),
      start: start,
      headerHeight: _headerHeight,
      rowHeight: _rowHeight,
      onSelect: widget.onSelect,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            PlannerTheme.space4,
            PlannerTheme.space2,
            PlannerTheme.space2,
            PlannerTheme.space2,
          ),
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
                key: DateList.todayButtonKey,
                onPressed: () => widget.onSelect(ref.read(todayProvider)),
                child: const Text('今天'),
              ),
            ],
          ),
        ),
        const Divider(
          height: 1,
          indent: PlannerTheme.space4,
          endIndent: PlannerTheme.space4,
        ),
        Expanded(
          child: CustomScrollView(
            controller: _scroll,
            center: _centerKey,
            slivers: [
              // 建好时那一周之前的周，从近到远往上排。
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
    );
  }
}

/// 列表里的一周：顶部是日期范围，下面从 [start]（周一）起七行。
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
      padding: const EdgeInsets.symmetric(horizontal: PlannerTheme.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: headerHeight,
            child: Align(
              alignment: AlignmentDirectional.bottomStart,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: PlannerTheme.space1,
                  bottom: PlannerTheme.space2,
                ),
                child: Text(
                  '${formatShortDate(start)} – '
                  '${formatShortDate(start.addDays(6))}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: PlannerTheme.secondaryText,
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

/// 列表里的一行：星期、`Oct 20`，今天带「今天」标记，右边是未完成数（为 0
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
    final count = activeCount;
    final weight = selected ? FontWeight.bold : null;
    return Semantics(
      key: DateList.dayKey(day),
      container: true,
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: PlannerTheme.space1),
        child: Material(
          color: selected ? PlannerTheme.selectedDay : Colors.transparent,
          borderRadius: PlannerTheme.rowRadius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: PlannerTheme.space3,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      label.weekday,
                      style: textTheme.bodyMedium?.copyWith(
                        color: selected
                            ? PlannerTheme.text
                            : PlannerTheme.secondaryText,
                        fontWeight: weight,
                      ),
                    ),
                  ),
                  Text(
                    label.date,
                    style: textTheme.bodyLarge?.copyWith(
                      color: PlannerTheme.text,
                      fontWeight: weight,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: PlannerTheme.space2),
                    Text(
                      '今天',
                      style: textTheme.labelSmall?.copyWith(
                        color: PlannerTheme.accentText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (count != null)
                    Text(
                      '$count',
                      key: DateList.countKey,
                      style: textTheme.labelLarge?.copyWith(
                        color: count == 0
                            ? PlannerTheme.secondaryText.withValues(alpha: 0.6)
                            : PlannerTheme.text,
                        fontWeight: count == 0 ? null : FontWeight.w600,
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
