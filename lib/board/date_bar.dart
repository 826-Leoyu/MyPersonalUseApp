import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/planner_theme.dart';
import '../app/providers.dart';
import '../formatting/date_format.dart';
import '../planner/day_key.dart';
import '../planner/planner_exceptions.dart';
import 'board_selection.dart';

/// 通过统一的入口切换日期（[switching] 调用 [BoardSelectionController] 的
/// 切换方法），先保存正在编辑的内容。保存失败时提示，停在原来的日期。日期栏
/// 的 ◀ / ▶、格子和「今天」按钮都用它。
Future<void> switchDay(
  BuildContext context,
  WidgetRef ref,
  Future<void> Function(BoardSelectionController selection) switching,
) async {
  // 切换成功以后画布连同日期栏都会换掉，提示用切换前拿到的 messenger。
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await switching(ref.read(boardSelectionProvider.notifier));
  } on PlannerException catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(saveFailureMessage(e))));
  }
}

/// 标题栏下面的日期栏：显示的那一天所在的一周（周一到周日），两边是前一天、
/// 后一天按钮。向左滑切到后一天，向右滑切到前一天，点格子切到那一天。
///
/// 它放在每一天自己的画布里，换一天就重建，所以总是显示那一天所在的一周。
class DateBar extends ConsumerStatefulWidget implements PreferredSizeWidget {
  const DateBar({super.key});

  /// 某一天的格子，测试用。
  static ValueKey<String> cellKey(DayKey day) => ValueKey('date-bar-cell-$day');

  /// 格子里的未完成数，测试用。
  static const countKey = ValueKey('date-bar-count');

  static const _height = 56.0;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  ConsumerState<DateBar> createState() => _DateBarState();
}

/// 记着这一次滑动横向走了多远。
class _DateBarState extends ConsumerState<DateBar> {
  double _dragDistance = 0;

  void _endDrag() {
    final distance = _dragDistance;
    _dragDistance = 0;
    if (distance == 0) return;
    switchDay(context, ref, (s) => s.showDayOffset(distance < 0 ? 1 : -1));
  }

  @override
  Widget build(BuildContext context) {
    final day = ref.watch(displayedDayProvider);
    return SizedBox(
      height: DateBar._height,
      child: Row(
        children: [
          IconButton(
            tooltip: '前一天',
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                switchDay(context, ref, (s) => s.showDayOffset(-1)),
          ),
          Expanded(
            child: GestureDetector(
              onHorizontalDragStart: (_) => _dragDistance = 0,
              onHorizontalDragUpdate: (details) =>
                  _dragDistance += details.primaryDelta ?? 0,
              onHorizontalDragEnd: (_) => _endDrag(),
              onHorizontalDragCancel: () => _dragDistance = 0,
              child: _Week(start: _weekStart(day), selected: day),
            ),
          ),
          IconButton(
            tooltip: '后一天',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => switchDay(context, ref, (s) => s.showDayOffset(1)),
          ),
        ],
      ),
    );
  }
}

/// 日期栏里的一周，从 [start]（周一）起七格。
class _Week extends ConsumerWidget {
  const _Week({required this.start, required this.selected});

  final DayKey start;

  /// 画布正在显示的那一天，它的格子高亮。
  final DayKey selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 数量还没读到或读不出来时不显示，格子照常能点。
    final counts = ref.watch(weekCountsProvider(start)).value;
    return Row(
      children: [
        for (final day in List.generate(7, start.addDays))
          Expanded(
            child: _DayCell(
              day: day,
              selected: day == selected,
              activeCount: counts?[day]?.activeCount,
            ),
          ),
      ],
    );
  }
}

/// 日期栏的一格：两行 `Oct 20` / `Tue`，右上角是未完成数（为 0 时颜色淡一些）。
class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.activeCount,
  });

  final DayKey day;
  final bool selected;

  /// 未完成数；为 null 时还没读到，不显示。
  final int? activeCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = formatDateBarLabel(day);
    final isToday = day == ref.watch(todayProvider);
    final textTheme = Theme.of(context).textTheme;
    final color = selected ? Colors.white : null;
    final count = activeCount;
    const radius = BorderRadius.all(Radius.circular(8));
    return Semantics(
      key: DateBar.cellKey(day),
      container: true,
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Material(
          color: selected ? PlannerTheme.accent : Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: () => switchDay(context, ref, (s) => s.showDay(day)),
            child: Stack(
              children: [
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label.date,
                          style: textTheme.labelMedium?.copyWith(
                            color: color,
                            fontWeight: isToday ? FontWeight.bold : null,
                          ),
                        ),
                        Text(
                          label.weekday,
                          style: textTheme.labelSmall?.copyWith(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
                if (count != null)
                  Positioned(
                    top: 2,
                    right: 4,
                    child: Text(
                      '$count',
                      key: DateBar.countKey,
                      style: textTheme.labelSmall?.copyWith(
                        color: count == 0
                            ? (color ?? Theme.of(context).hintColor).withValues(
                                alpha: 0.6,
                              )
                            : (color ?? PlannerTheme.accent),
                        fontWeight: count == 0 ? null : FontWeight.bold,
                      ),
                    ),
                  ),
              ],
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
