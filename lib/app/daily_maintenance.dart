import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../board/board_selection.dart';
import '../board/date_bar.dart';
import '../planner/day_key.dart';
import '../planner/planner_exceptions.dart';
import 'providers.dart';

/// 每日维护接入 App 生命周期：每次回到前台都执行一次每日维护（同一天不会
/// 再顺延，只清理回收站）；如果已经跨过午夜，先保存正在编辑的内容，维护后
/// 把「今天」换成新的一天，并通过切换日期的统一入口把画布切过去。系统时钟
/// 被调回过去时，「今天」跟着时钟变，画布停在原来的日期。
///
/// 冷启动时的维护在 [plannerServiceProvider] 里，先维护再显示画布。
class DailyMaintenance extends ConsumerStatefulWidget {
  const DailyMaintenance({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<DailyMaintenance> createState() => _DailyMaintenanceState();
}

class _DailyMaintenanceState extends ConsumerState<DailyMaintenance> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _onResume() async {
    // 存储还没打开或打不开：冷启动的维护会在打开时执行。
    final service = ref.read(plannerServiceProvider).value;
    if (service == null) return;
    final today = DayKey.fromDateTime(ref.read(clockProvider).now());
    final previousToday = ref.read(todayProvider);
    // 只有往后跨过午夜才算新的一天；系统时钟被调回过去时不跳回过去。
    final newDay = today > previousToday;
    final selection = ref.read(boardSelectionProvider.notifier);
    final messenger = ScaffoldMessenger.maybeOf(context);
    var saved = true;
    if (newDay) {
      try {
        await selection.startNewDay(today);
      } on PlannerException catch (e) {
        // 保存失败：停在原来的日期，编辑的内容不丢。
        messenger?.showSnackBar(SnackBar(content: Text(saveFailureMessage(e))));
        saved = false;
      }
    }
    try {
      await service.runDailyMaintenance();
    } on StorageFailure {
      // 写不进去时不提示，下次回到前台再维护。
    }
    if (!mounted || today == previousToday) return;
    ref.invalidate(todayProvider);
    if (newDay && saved) {
      await switchDay(context, ref, (s) => s.showDay(today));
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
