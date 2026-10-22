/// 界面状态层：用 Riverpod 把 [PlannerService] 和它的数据流暴露给界面。
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../planner/day_board.dart';
import '../planner/day_key.dart';
import '../planner/planner_service.dart';
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
