/// 界面状态层：用 Riverpod 把 [PlannerService] 和它的数据流暴露给界面。
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../planner/day_board.dart';
import '../planner/day_counts.dart';
import '../planner/day_key.dart';
import '../planner/planner_exceptions.dart';
import '../planner/planner_service.dart';
import '../planner/task_card.dart';
import '../planner/trashed_card.dart';
import '../storage/planner_database.dart';

/// App 使用的时钟；测试里换成假时钟。
final clockProvider = Provider<Clock>((ref) => const Clock());

/// 打开存储的方式：每次调用新建一个数据库连接。在 `main` 里换成真实的
/// 数据库文件，测试里换成内存数据库。
final plannerDatabaseFactoryProvider = Provider<PlannerDatabase Function()>(
  (ref) =>
      throw UnimplementedError('plannerDatabaseFactoryProvider 需要 override'),
);

/// 打开好的 [PlannerService]。打不开时是错误状态，由界面显示错误页；
/// 重试时 invalidate 它。打开成功的 service 在 provider 销毁时关闭。
final plannerServiceProvider = FutureProvider<PlannerService>(
  (ref) async {
    final database = ref.watch(plannerDatabaseFactoryProvider)();
    final service = PlannerService(
      database: database,
      clock: ref.watch(clockProvider),
    );
    try {
      await service.open();
    } on Object {
      // 打开时的错误已经由 provider 报告，关闭时再抛出的同一个错误忽略掉。
      service.close().ignore();
      rethrow;
    }
    ref.onDispose(service.close);
    // 每日维护：冷启动时先维护，再显示画布，画布一出来就是顺延以后的样子。
    // 回到前台时的维护见 [DailyMaintenance]。
    try {
      await service.runDailyMaintenance();
    } on StorageFailure {
      // 写不进去时照常显示画布，下次回到前台再维护。
    }
    return service;
  },
  // 不自动重试：打不开时停在错误页，由用户点「重试」。
  retry: (_, _) => null,
);

/// 今天，由注入的时钟决定。
final todayProvider = Provider<DayKey>(
  (ref) => DayKey.fromDateTime(ref.watch(clockProvider).now()),
);

/// 某一天画布上要显示的内容。存储打不开或读取失败时是错误状态。
final dayBoardProvider = StreamProvider.family<DayBoard, DayKey>(
  (ref, dayKey) async* {
    final service = await ref.watch(plannerServiceProvider.future);
    yield* service.watchDay(dayKey);
  },
  // 不自动重试：出错时停在错误页，由用户点「重试」。
  retry: (_, _) => null,
);

/// 从 [from] 起连续 7 天的任务数量，给日期抽屉用。读取失败时是错误状态。
///
/// 没有日期抽屉在显示这一周时就停止监听：可以一直往前后翻，不能让翻过的每一周
/// 都留着一个查询。
final weekCountsProvider = StreamProvider.autoDispose
    .family<Map<DayKey, DayCounts>, DayKey>(
      (ref, from) async* {
        final service = await ref.watch(plannerServiceProvider.future);
        yield* service.watchDayCounts(from, from.addDays(6));
      },
      // 不自动重试：读不出来时格子里不显示数量。
      retry: (_, _) => null,
    );

/// 某一天的「已完成」列表，按完成时间倒序。读取失败时是错误状态。
final completedCardsProvider = StreamProvider.autoDispose
    .family<List<TaskCard>, DayKey>(
      (ref, dayKey) async* {
        final service = await ref.watch(plannerServiceProvider.future);
        yield* service.watchCompleted(dayKey);
      },
      // 不自动重试：读不出来时停在提示上，由用户点「重试」。
      retry: (_, _) => null,
    );

/// 回收站里的卡片，按删除时间倒序，每张带剩余天数。读取失败时是错误状态。
final trashProvider = StreamProvider.autoDispose<List<TrashedCard>>(
  (ref) async* {
    final service = await ref.watch(plannerServiceProvider.future);
    yield* service.watchTrash();
  },
  // 不自动重试：读不出来时停在提示上，由用户点「重试」。
  retry: (_, _) => null,
);
