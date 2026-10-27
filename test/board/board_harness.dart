import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/app/planner_app.dart';
import 'package:my_personal_use_app/app/providers.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/board_selection.dart';
import 'package:my_personal_use_app/mail/mail_service.dart';
import 'package:my_personal_use_app/planner/day_board.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/planner_service.dart';
import 'package:my_personal_use_app/storage/planner_database.dart';
import 'package:sqlite3/sqlite3.dart';

import '../mail/fake_analyzer.dart';
import '../mail/mail_fixtures.dart';
import '../support/failing_storage.dart';

/// 切入点 2 的测试环境：真实的 [PlannerApp] + 真实的 [PlannerService] +
/// 内存 SQLite + 假时钟。
///
/// App 自己通过注入的数据库工厂打开存储；[seed] 在启动 App 之前用另一个
/// 连接准备数据，两者共用同一个内存数据库。
class BoardHarness {
  BoardHarness() : _sqlite = sqlite3.openInMemory() {
    // App 和 seed 各开一个连接，drift 默认会对此发出警告。
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  final Database _sqlite;
  final _failingStorage = FailingStorage();

  /// 假时钟的当前时间（本地时间）。
  DateTime now = DateTime(2026, 10, 20, 9);

  DayKey get today => DayKey.fromDateTime(now);

  /// App 启动时画布显示哪一天；为 null 时显示今天。用它直接从别的日期开始测。
  DayKey? displayedDay;

  /// 接下来这么多次打开存储都会报错，用来模拟数据库打不开。
  int failingOpens = 0;

  /// 邮件预览里点「导入文件」时选中的文件路径；为 null 时相当于取消选择。
  String? pickedMailFile;

  /// App 用的分析器：按脚本返回结果，不调用真的 Claude Code。
  final analyzer = FakeAnalyzer();

  /// 打开后，App 的所有写入都会报错；读取不受影响。
  set failWrites(bool value) =>
      _failingStorage.writesBeforeFailure = value ? 0 : null;

  /// 打开后，App 的所有读取都会报错。只在画布已经显示出来以后打开，
  /// 不然画布本身就读不出来。
  set failReads(bool value) => _failingStorage.failReads = value;

  Clock get _clock => Clock(() => now);

  /// 在共用的内存数据库上新建一个连接。
  QueryExecutor _connect() =>
      NativeDatabase.opened(_sqlite, closeUnderlyingOnClose: false);

  /// 给 seed 和 readBoard 用的连接，写入不会被模拟成失败。
  PlannerDatabase _newConnection() => PlannerDatabase(_connect());

  /// 注入给 App 的数据库工厂。
  PlannerDatabase _openDatabase() {
    if (failingOpens > 0) {
      failingOpens--;
      return PlannerDatabase(LazyDatabase(() => throw Exception('模拟的数据库打不开')));
    }
    return PlannerDatabase(_connect().interceptWith(_failingStorage));
  }

  /// 在启动 App 之前准备数据。
  Future<T> seed<T>(
    WidgetTester tester,
    Future<T> Function(PlannerService service) action,
  ) async {
    final result = await tester.runAsync(() async {
      final database = _newConnection();
      try {
        return await action(PlannerService(database: database, clock: _clock));
      } finally {
        await database.close();
      }
    });
    return result as T;
  }

  /// 在启动 App 之前导入 [messages]（虚构邮件，见 `fakeMessage`），并用
  /// [analyzer] 分析完。
  Future<void> seedMail(
    WidgetTester tester,
    List<Map<String, Object?>> messages,
  ) async {
    await tester.runAsync(() async {
      final directory = Directory.systemTemp.createTempSync('board_mail_');
      final database = _newConnection();
      try {
        final file = File('${directory.path}${Platform.pathSeparator}mail.json')
          ..writeAsBytesSync(encode(fakeEnvelope(messages)));
        final service = MailService(
          planner: PlannerService(database: database, clock: _clock),
          analyzer: analyzer,
          clock: _clock,
        );
        await service.importFile(file.path);
        await service.analyzePending();
      } finally {
        await database.close();
        directory.deleteSync(recursive: true);
      }
    });
  }

  /// 直接改数据库，把卡片挪到 [dayKey] 那一天。正常操作造不出两端不在同一天的
  /// 连线，用它来模拟。
  Future<void> moveCardToDay(
    WidgetTester tester,
    String cardId,
    DayKey dayKey,
  ) async {
    await tester.runAsync(() async {
      final database = _newConnection();
      try {
        await (database.update(database.taskCards)
              ..where((c) => c.id.equals(cardId)))
            .write(TaskCardsCompanion(dayKey: Value(dayKey.toString())));
      } finally {
        await database.close();
      }
    });
  }

  /// 通过 service 读出某一天的画布内容，用来检查结果。
  Future<DayBoard> readBoard(WidgetTester tester, DayKey dayKey) =>
      seed(tester, (service) => service.watchDay(dayKey).first);

  /// 冷启动 App，等它打开存储并显示出来。
  ///
  /// [settleAnimations] 为 false 时，画布一出现就返回，不推进动画的时间。
  Future<void> launch(
    WidgetTester tester, {
    bool settleAnimations = true,
  }) async {
    await tester.pumpWidget(_app());
    if (settleAnimations) return settle(tester);
    await pumpData(
      tester,
      rounds: 10,
      until: () => find.byType(BoardCanvas).evaluate().isNotEmpty,
    );
  }

  /// App 运行中的 provider 容器。
  ProviderContainer _container(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(PlannerApp)));

  /// App 运行中的选中和编辑控制器，用来直接调用它测并发的情况。
  BoardSelectionController selection(WidgetTester tester) =>
      _container(tester).read(boardSelectionProvider.notifier);

  /// App 运行中把假时钟拨到 [time]，让「今天」重新计算（比如过了午夜）。
  Future<void> changeNow(WidgetTester tester, DateTime time) async {
    now = time;
    _container(tester).invalidate(todayProvider);
    await settle(tester);
  }

  /// App 运行中通过统一的入口把画布切到 [day]，等那一天的画布内容显示出来，
  /// 不推进动画的时间。不经过日期抽屉，直接调用入口测切换日期。
  ///
  /// 保存正在编辑的内容失败时抛出 PlannerException，不切换。
  Future<void> showDay(WidgetTester tester, DayKey day) async {
    var done = false;
    Object? error;
    selection(tester)
        .showDay(day)
        .then<void>((_) {}, onError: (Object e) => error = e)
        .whenComplete(() => done = true);
    await pumpData(tester, rounds: 20, until: () => done);
    if (!done) fail('切换到 $day 没有完成');
    if (error case final e?) throw e;
    await pumpData(tester);
  }

  Widget _app() => ProviderScope(
    overrides: [
      clockProvider.overrideWithValue(_clock),
      plannerDatabaseFactoryProvider.overrideWithValue(_openDatabase),
      pickMailExportFileProvider.overrideWithValue(() async => pickedMailFile),
      mailAnalyzerProvider.overrideWithValue(analyzer),
      if (displayedDay case final day?)
        displayedDayProvider.overrideWithBuild((ref, _) => day),
    ],
    child: const PlannerApp(),
  );

  /// 让数据库读写跑完、新的画布内容显示出来，不推进动画的时间。最多推
  /// [rounds] 轮，[until] 成立时提前停下。
  Future<void> pumpData(
    WidgetTester tester, {
    int rounds = 3,
    bool Function()? until,
  }) async {
    for (var i = 0; i < rounds && !(until?.call() ?? false); i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
  }

  /// 等待数据库读写和界面刷新都完成。drift 的查询是真正的异步 IO，
  /// 要在 runAsync 里让它跑完，再推进界面。
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
    }
  }

  /// 拆掉 App（让它关闭数据库连接），再关闭内存数据库。
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
    _sqlite.close();
  }
}
