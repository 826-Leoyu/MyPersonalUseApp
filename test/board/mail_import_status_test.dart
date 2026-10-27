// 切入点 2：自动导入的界面（M-31、M-32、M-34、M-35）。邮件文件夹是内存里的
// 假文件夹，导入规则本身在 test/mail/mail_folder_test.dart 里用真实目录测。
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_import_status_line.dart';
import 'package:my_personal_use_app/mail/mail_scan_schedule.dart';
import 'package:my_personal_use_app/mail/mail_service.dart';
import 'package:my_personal_use_app/settings/settings_page.dart';

import '../mail/mail_fixtures.dart';
import 'board_harness.dart';

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 在 Windows 上跑的测试，宽屏，"新邮件事项"栏在画布右边。平台和窗口
  /// 大小要在测试结束前改回来，否则测试框架报错。
  void windowsTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    try {
      await body(tester);
    } finally {
      tester.view.reset();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  const folder = r'C:\Users\her\OneDrive\DailyNote';

  const informational = AnalysisResult(
    category: MailCategory.informational,
    reason: '只是通知',
    items: [],
  );

  Map<String, Object?> mail(String key, {DateTime? at}) => fakeMessage(
    internetMessageId: '<$key@example.com>',
    id: 'AAMk-$key',
    subject: 'Mail $key',
    receivedDateTime: (at ?? DateTime.utc(2026, 10, 19, 14, 30))
        .toIso8601String(),
  );

  /// 在邮件文件夹里放一个导出文件，修改时间是现在。
  void drop(String name, Object? content, {String into = folder}) =>
      harness.folders.write(
        into,
        name,
        content is List<int> ? content : encode(content),
        harness.now,
      );

  /// 时间往前走 [duration]：假时钟和定时器一起走。
  Future<void> elapse(WidgetTester tester, Duration duration) async {
    harness.now = harness.now.add(duration);
    await tester.pump(duration);
    await harness.settle(tester);
  }

  Finder headline(String text) => find.descendant(
    of: find.byKey(MailImportStatusLine.headlineKey),
    matching: find.text(text),
  );

  windowsTest('没选择文件夹时状态行显示"开始设置"，点它打开设置页', (tester) async {
    await harness.launch(tester);

    expect(headline('开始设置'), findsOneWidget);
    await tester.tap(headline('开始设置'));
    await harness.settle(tester);

    expect(find.byType(SettingsPage), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('App 关着时同步过来的文件，启动时马上导入；状态行显示上次导入（M-34）', (tester) async {
    drop('mail-1.json', fakeEnvelope([mail('a'), mail('b')]));
    await harness.seedMailFolder(tester, folder, scans: 1);
    harness.now = DateTime(2026, 10, 21, 7, 12);

    await harness.launch(tester);

    expect(headline('✅ 上次导入：今天 07:12 · 新邮件 2 封'), findsOneWidget);
    expect(find.text('这里只能说明电脑上收到了文件，不代表云端流程现在还在正常运行。'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('运行期间每 5 分钟扫描；新文件先显示正在同步，稍后自动导入（M-32）', (tester) async {
    harness.folders.folders[folder] = {};
    await harness.seedMailFolder(tester, folder);
    await harness.launch(tester);
    drop('mail-1.json', fakeEnvelope([mail('a')]));

    await elapse(tester, const Duration(minutes: 4));
    expect(headline('⏳ 有文件正在同步，稍后自动导入'), findsNothing);

    await elapse(tester, const Duration(minutes: 1));
    expect(headline('⏳ 有文件正在同步，稍后自动导入'), findsOneWidget);

    await elapse(tester, MailScanSchedule.recheckAfter);
    expect(headline('✅ 上次导入：今天 09:05 · 新邮件 1 封'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('点 [立即导入] 马上扫描', (tester) async {
    harness.folders.folders[folder] = {};
    await harness.seedMailFolder(tester, folder);
    await harness.launch(tester);
    drop('mail-1.json', fakeEnvelope([mail('a')]));

    await tester.tap(find.byKey(MailImportStatusLine.importNowKey));
    await harness.settle(tester);
    expect(headline('⏳ 有文件正在同步，稍后自动导入'), findsOneWidget);

    await elapse(tester, MailScanSchedule.recheckAfter);
    expect(headline('✅ 上次导入：今天 09:00 · 新邮件 1 封'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('找不到文件夹时显示 [重新选择]，选了新的文件夹以后恢复', (tester) async {
    await harness.seedMailFolder(tester, r'C:\gone');
    await harness.launch(tester);
    expect(headline('❌ 找不到邮件文件夹'), findsOneWidget);

    harness.folders.folders[folder] = {};
    harness.pickedMailFolder = folder;
    await tester.tap(find.byKey(MailImportStatusLine.chooseAgainKey));
    await harness.settle(tester);

    expect(headline('❌ 找不到邮件文件夹'), findsNothing);
    expect(find.byKey(MailImportStatusLine.chooseAgainKey), findsNothing);
    await harness.dispose(tester);
  });

  windowsTest('同时有几个问题时显示最靠前的一个，点开看到全部（M-35、M-36）', (tester) async {
    /// 满的导出文件：从 [from] 起每分钟一封。
    Map<String, Object?> full(String prefix, DateTime from) => fakeEnvelope([
      for (var i = MailService.exportBatchSize - 1; i >= 0; i--)
        mail('$prefix$i', at: from.add(Duration(minutes: i))),
    ]);
    drop('mail-1.json', full('a', DateTime.utc(2026, 10, 17)));
    drop('mail-2.json', full('b', DateTime.utc(2026, 10, 18)));
    drop('mail-3.json', utf8.encode('not json'));
    await harness.seedMailFolder(tester, folder, scans: 2);
    harness.now = harness.now.add(const Duration(days: 3));

    await harness.launch(tester);

    expect(headline('⚠ 文件 mail-3.json 格式不对（已跳过）'), findsOneWidget);
    expect(find.text('⚠ 已 3 天没有新导出文件，请检查 Power Automate 流程'), findsNothing);

    await tester.tap(find.byKey(MailImportStatusLine.headlineKey));
    await harness.settle(tester);

    expect(find.text('⚠ 已 3 天没有新导出文件，请检查 Power Automate 流程'), findsOneWidget);
    expect(find.text('⚠ 可能漏掉了一些邮件，请让设置者手动补读'), findsOneWidget);
    expect(find.text('上次导入：Oct 20 09:01 · 新邮件 400 封'), findsOneWidget);
    await harness.dispose(tester);
  });

  group('分析的提示（M-20、M-22）', () {
    windowsTest('额度用完时提示稍后自动重试，30 分钟后自动重试', (tester) async {
      harness.analyzer.fails('Mail a', AnalysisFailureType.quotaExhausted);
      drop('mail-1.json', fakeEnvelope([mail('a')]));
      await harness.seedMailFolder(tester, folder, scans: 2);
      await harness.launch(tester);
      expect(headline('⏳ Claude 额度已用完，稍后自动重试'), findsOneWidget);

      harness.analyzer.returns('Mail a', informational);
      await elapse(tester, const Duration(minutes: 29));
      expect(headline('⏳ Claude 额度已用完，稍后自动重试'), findsOneWidget);

      await elapse(tester, const Duration(minutes: 1));
      expect(headline('✅ 上次导入：今天 09:01 · 新邮件 1 封'), findsOneWidget);
      await harness.dispose(tester);
    });

    windowsTest('输出格式不对 3 次后提示分析失败，点 [重试] 再分析', (tester) async {
      harness.analyzer.fails('Mail a', AnalysisFailureType.invalidOutput);
      drop('mail-1.json', fakeEnvelope([mail('a')]));
      await harness.seedMailFolder(tester, folder, scans: 2);
      await harness.launch(tester);
      await elapse(tester, MailScanSchedule.retryInterval);
      expect(headline('⚠ 1 封邮件分析失败'), findsOneWidget);

      harness.analyzer.returns('Mail a', informational);
      await tester.tap(find.byKey(MailImportStatusLine.retryAnalysisKey));
      await harness.settle(tester);

      expect(harness.analyzer.requests, hasLength(4));
      expect(find.byKey(MailImportStatusLine.retryAnalysisKey), findsNothing);
      await harness.dispose(tester);
    });

    windowsTest('今天自动分析到上限时暂停，点 [继续分析] 接着分析', (tester) async {
      final limit = MailService.dailyAutoAnalysisLimit;
      drop(
        'mail-1.json',
        fakeEnvelope([
          for (var i = 0; i <= limit; i++)
            mail('m$i', at: DateTime.utc(2026, 10, 19, 12, 0, i)),
        ]),
      );
      await harness.seedMailFolder(tester, folder, scans: 2);
      await harness.launch(tester);
      expect(headline('⏸ 今天的新邮件较多，已暂停自动分析'), findsOneWidget);

      await tester.tap(find.byKey(MailImportStatusLine.resumeAnalysisKey));
      await harness.settle(tester);

      expect(harness.analyzer.requests, hasLength(limit + 1));
      expect(headline('⏸ 今天的新邮件较多，已暂停自动分析'), findsNothing);
      await harness.dispose(tester);
    });

    for (final (type, text) in [
      (AnalysisFailureType.notInstalled, '⚠ 没有找到 Claude Code，请先安装'),
      (AnalysisFailureType.notLoggedIn, '⚠ Claude 未登录，请打开 Claude Code 登录'),
    ]) {
      windowsTest('${type.name}：不自动重试，提示她处理，处理好以后点 [重试]', (tester) async {
        harness.analyzer.fails('Mail a', type);
        drop('mail-1.json', fakeEnvelope([mail('a')]));
        await harness.seedMailFolder(tester, folder, scans: 2);
        await harness.launch(tester);
        await elapse(tester, MailScanSchedule.retryInterval);
        expect(headline(text), findsOneWidget);
        expect(harness.analyzer.requests, hasLength(1));

        harness.analyzer.returns('Mail a', informational);
        await tester.tap(find.byKey(MailImportStatusLine.retryAnalysisKey));
        await harness.settle(tester);

        expect(headline(text), findsNothing);
        await harness.dispose(tester);
      });
    }
  });

  group('设置页（M-31）', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byTooltip('设置'));
      await harness.settle(tester);
    }

    windowsTest('选择邮件文件夹，马上显示找到几个文件和最新一个的时间，并开始导入', (tester) async {
      await harness.launch(tester);
      await openSettings(tester);
      expect(find.text('未选择'), findsOneWidget);
      harness.folders
        ..write(folder, 'mail-1.json', [], DateTime(2026, 10, 19, 16))
        ..write(
          folder,
          'mail-2.json',
          encode(fakeEnvelope([mail('a')])),
          DateTime(2026, 10, 20, 7, 1),
        )
        ..write(folder, 'notes.txt', [], DateTime(2026, 10, 20, 8));
      harness.pickedMailFolder = folder;

      await tester.tap(find.byKey(SettingsPage.mailFolderTileKey));
      await harness.settle(tester);

      expect(find.text(folder), findsOneWidget);
      expect(find.text('找到 2 个导出文件，最新一个是 Oct 20 07:01'), findsOneWidget);
      await tester.pageBack();
      await harness.settle(tester);
      expect(headline('⏳ 有文件正在同步，稍后自动导入'), findsOneWidget);
      await harness.dispose(tester);
    });

    windowsTest('打不开的文件夹不保存，原来的文件夹不变；取消选择时什么都不变', (tester) async {
      harness.folders.folders[folder] = {};
      await harness.seedMailFolder(tester, folder);
      await harness.launch(tester);
      await openSettings(tester);

      harness.pickedMailFolder = r'C:\nope';
      await tester.tap(find.byKey(SettingsPage.mailFolderTileKey));
      await harness.settle(tester);
      expect(find.text('这个文件夹打不开，请换一个'), findsOneWidget);
      expect(find.text(folder), findsOneWidget);

      harness.pickedMailFolder = null;
      await tester.tap(find.byKey(SettingsPage.mailFolderTileKey));
      await harness.settle(tester);
      expect(find.text(folder), findsOneWidget);
      await harness.dispose(tester);
    });
  });
}
