/// 界面状态层：用 Riverpod 把 [PlannerService] 和它的数据流暴露给界面。
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mail/claude_code_analyzer.dart';
import '../mail/export_source.dart';
import '../mail/import_status.dart';
import '../mail/mail_analyzer.dart';
import '../mail/mail_items.dart';
import '../mail/mail_preview.dart';
import '../mail/mail_scan_schedule.dart';
import '../mail/mail_service.dart';
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

/// 邮件功能只在 Windows 上有（spec 0002"平台"）；其他平台看不到任何入口。
bool get mailAvailable => defaultTargetPlatform == TargetPlatform.windows;

/// 分析邮件用的分析器：本机的 Claude Code。测试里换成假的。
final mailAnalyzerProvider = Provider<MailAnalyzer>(
  (ref) => ClaudeCodeAnalyzer(),
);

/// 打开邮件文件夹的方式。测试里换成内存里的假文件夹。
final mailExportSourceProvider = Provider<ExportSource Function(String)>(
  (ref) => DirectoryExportSource.new,
);

/// 打开好的 [MailService]，和 [PlannerService] 共用同一个数据库。打开后
/// 接着分析上次没分析完的邮件（M-13），不等分析结束。
final mailServiceProvider = FutureProvider<MailService>((ref) async {
  final planner = await ref.watch(plannerServiceProvider.future);
  final service = MailService(
    planner: planner,
    analyzer: ref.watch(mailAnalyzerProvider),
    clock: ref.watch(clockProvider),
    openFolder: ref.watch(mailExportSourceProvider),
  );
  unawaited(service.analyzePending());
  return service;
}, retry: (_, _) => null);

/// 自动导入：开始监听时扫描一次邮件文件夹，之后每 5 分钟一次。画布页一直
/// 监听它。
final mailScanScheduleProvider = FutureProvider<MailScanSchedule>((ref) async {
  final schedule = MailScanSchedule(
    await ref.watch(mailServiceProvider.future),
  );
  ref.onDispose(schedule.dispose);
  schedule.start();
  return schedule;
}, retry: (_, _) => null);

/// 状态行要显示的导入情况。读取失败时是错误状态。
final mailImportStatusProvider = StreamProvider<MailImportStatus>((ref) async* {
  final service = await ref.watch(mailServiceProvider.future);
  yield* service.watchImportStatus();
}, retry: (_, _) => null);

/// 设置里的邮件文件夹，没有选择时为 null。修改以后 invalidate 它。
final mailFolderProvider = FutureProvider.autoDispose<String?>((ref) async {
  final service = await ref.watch(mailServiceProvider.future);
  return service.mailFolder();
}, retry: (_, _) => null);

/// 让用户选择邮件文件夹，返回它的路径；取消时为 null。测试里换成直接返回
/// 一个路径。
final pickMailFolderProvider = Provider<Future<String?> Function()>(
  (ref) =>
      () => getDirectoryPath(confirmButtonText: '选择'),
);

/// 让用户选择邮件文件夹并检查。能用时保存并马上扫描；打不开时不保存。
/// 取消时为 null。保存失败时抛出 [StorageFailure]。
Future<FolderCheck?> chooseMailFolder(WidgetRef ref) async {
  final path = await ref.read(pickMailFolderProvider)();
  if (path == null) return null;
  final service = await ref.read(mailServiceProvider.future);
  final check = await service.checkFolder(path);
  if (check is FolderFound) {
    await service.setMailFolder(path);
    ref.invalidate(mailFolderProvider);
    final schedule = await ref.read(mailScanScheduleProvider.future);
    unawaited(schedule.scanNow());
  }
  return check;
}

/// "新邮件事项"栏里的候选事项，排好序。读取失败时是错误状态。
final mailCandidatesProvider = StreamProvider<List<MailItemCandidate>>(
  (ref) async* {
    final service = await ref.watch(mailServiceProvider.future);
    yield* service.watchCandidates();
  },
  // 不自动重试：读不出来时栏里显示提示，由用户点「重试」。
  retry: (_, _) => null,
);

/// "已过滤的邮件"，给栏底部的入口和列表页用。读取失败时是错误状态。
final mailFilteredProvider = StreamProvider<List<FilteredEntry>>(
  (ref) async* {
    final service = await ref.watch(mailServiceProvider.future);
    yield* service.watchFiltered();
  },
  // 不自动重试：读不出来时停在提示上，由用户点「重试」。
  retry: (_, _) => null,
);

/// 由邮件事项加入的卡片的 id，给卡片上的信封图标用。读不出来时不显示图标。
final mailCardIdsProvider = StreamProvider<Set<String>>((ref) async* {
  final service = await ref.watch(mailServiceProvider.future);
  yield* service.watchMailCardIds();
}, retry: (_, _) => null);

/// 已导入的邮件，给邮件预览列表用。读取失败时是错误状态。
final mailPreviewsProvider = StreamProvider.autoDispose<List<MailPreview>>(
  (ref) async* {
    final service = await ref.watch(mailServiceProvider.future);
    yield* service.watchMails();
  },
  // 不自动重试：读不出来时停在提示上，由用户点「重试」。
  retry: (_, _) => null,
);

/// 一封邮件的正文和链接，给点开的邮件用；没有这封邮件时为 null。
final mailDetailProvider = FutureProvider.autoDispose
    .family<MailDetail?, String>((ref, id) async {
      final service = await ref.watch(mailServiceProvider.future);
      return service.mailDetail(id);
    }, retry: (_, _) => null);

/// 设置里的邮箱地址，没有填写时为 null。修改以后 invalidate 它。
final mailboxAddressProvider = FutureProvider.autoDispose<String?>((ref) async {
  final service = await ref.watch(mailServiceProvider.future);
  return service.mailboxAddress();
}, retry: (_, _) => null);

/// 让用户选择一个导出文件，返回它的路径；取消时为 null。测试里换成直接
/// 返回临时目录里的文件。
final pickMailExportFileProvider = Provider<Future<String?> Function()>(
  (ref) => () async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    return file?.path;
  },
);
