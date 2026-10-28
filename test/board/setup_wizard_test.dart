// 切入点 2：首次设置向导的步骤（#91）。Claude Code 的检查和分析器都是假的，
// 邮件文件夹在内存里。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/claude_code_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_import_status_line.dart';
import 'package:my_personal_use_app/mail/mail_scan_schedule.dart';
import 'package:my_personal_use_app/mail/mail_setup.dart';
import 'package:my_personal_use_app/mail/setup_wizard_page.dart';
import 'package:my_personal_use_app/settings/settings_page.dart';

import '../mail/fake_analyzer.dart';
import '../mail/mail_fixtures.dart';
import 'board_harness.dart';

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 在 Windows 上跑的测试，宽屏，"新邮件事项"栏在画布右边。
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
  const claudePath = r'C:\Users\her\.local\bin\claude.exe';

  Finder headline(String text) => find.descendant(
    of: find.byKey(MailImportStatusLine.headlineKey),
    matching: find.text(text),
  );

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.tap(find.byKey(key));
    await harness.settle(tester);
  }

  /// 从状态行的"开始设置"打开向导。
  Future<void> openFromStatusLine(WidgetTester tester) async {
    await tester.tap(headline('开始设置'));
    await harness.settle(tester);
  }

  Future<void> openFromSettings(WidgetTester tester) async {
    await tester.tap(find.byTooltip('设置'));
    await harness.settle(tester);
    await tap(tester, SettingsPage.setupWizardTileKey);
  }

  /// 第一步勾选同意，进第二步；第二步选好 [folder]，进第三步。
  Future<void> throughFolder(WidgetTester tester) async {
    await tap(tester, SetupWizardPage.consentKey);
    await tap(tester, SetupWizardPage.nextKey);
    harness.folders.folders[folder] = {};
    harness.pickedMailFolder = folder;
    await tap(tester, SetupWizardPage.chooseFolderKey);
    await tap(tester, SetupWizardPage.nextKey);
  }

  bool enabled(WidgetTester tester, Key key) =>
      tester.widget<ButtonStyleButton>(find.byKey(key)).enabled;

  windowsTest('没设置过时栏里显示"开始设置"，点它打开向导第一步', (tester) async {
    await harness.launch(tester);

    await openFromStatusLine(tester);

    expect(find.byType(SetupWizardPage), findsOneWidget);
    expect(find.text('第 1 步，共 4 步'), findsOneWidget);
    expect(
      find.textContaining('邮件内容会交给你自己账号下的 Claude 分析，不会改动、删除或回复 Outlook 里的邮件'),
      findsOneWidget,
    );
    await harness.dispose(tester);
  });

  windowsTest('勾选同意后才能继续', (tester) async {
    await harness.launch(tester);
    await openFromStatusLine(tester);
    expect(enabled(tester, SetupWizardPage.nextKey), isFalse);

    await tap(tester, SetupWizardPage.consentKey);
    expect(enabled(tester, SetupWizardPage.nextKey), isTrue);
    await tap(tester, SetupWizardPage.nextKey);

    expect(find.text('第 2 步，共 4 步'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('第二步用文件夹选择窗口选择，马上显示检查结果；选好以后才能继续', (tester) async {
    await harness.launch(tester);
    await openFromStatusLine(tester);
    await tap(tester, SetupWizardPage.consentKey);
    await tap(tester, SetupWizardPage.nextKey);
    expect(enabled(tester, SetupWizardPage.nextKey), isFalse);

    harness.pickedMailFolder = r'C:\nope';
    await tap(tester, SetupWizardPage.chooseFolderKey);
    expect(find.text('这个文件夹打不开，请换一个'), findsOneWidget);
    expect(enabled(tester, SetupWizardPage.nextKey), isFalse);

    harness.folders.write(
      folder,
      'mail-1.json',
      encode(fakeEnvelope([fakeMessage()])),
      DateTime(2026, 10, 20, 7, 1),
    );
    harness.pickedMailFolder = folder;
    await tap(tester, SetupWizardPage.chooseFolderKey);

    expect(find.text(folder), findsOneWidget);
    expect(find.text('找到 1 个导出文件，最新一个是 Oct 20 07:01'), findsOneWidget);
    expect(enabled(tester, SetupWizardPage.nextKey), isTrue);
    await harness.dispose(tester);
  });

  windowsTest('第三步找到 Claude Code 并且登录了时显示它的位置', (tester) async {
    harness.claudeStatus = const ClaudeCodeReady(claudePath);
    await harness.launch(tester);
    await openFromStatusLine(tester);
    await throughFolder(tester);

    expect(find.text('第 3 步，共 4 步'), findsOneWidget);
    expect(find.textContaining(claudePath), findsOneWidget);
    expect(find.textContaining('已登录'), findsOneWidget);
    expect(enabled(tester, SetupWizardPage.nextKey), isTrue);
    await harness.dispose(tester);
  });

  windowsTest('找不到 Claude Code 时提示请设置者检查，不给安装步骤，不能继续', (tester) async {
    harness.claudeStatus = const ClaudeCodeMissing();
    await harness.launch(tester);
    await openFromStatusLine(tester);
    await throughFolder(tester);

    expect(find.text('找不到 Claude Code，请让设置者检查'), findsOneWidget);
    expect(find.textContaining('安装'), findsNothing);
    expect(enabled(tester, SetupWizardPage.nextKey), isFalse);
    await harness.dispose(tester);
  });

  windowsTest('没登录时显示登录步骤；她登录以后点 [重新检查] 就能继续', (tester) async {
    harness.claudeStatus = const ClaudeCodeNotLoggedIn(claudePath);
    await harness.launch(tester);
    await openFromStatusLine(tester);
    await throughFolder(tester);

    expect(find.textContaining('还没有登录'), findsOneWidget);
    expect(find.textContaining('官方'), findsWidgets);
    expect(enabled(tester, SetupWizardPage.nextKey), isFalse);

    harness.claudeStatus = const ClaudeCodeReady(claudePath);
    await tap(tester, SetupWizardPage.recheckKey);

    expect(find.textContaining('已登录'), findsOneWidget);
    expect(enabled(tester, SetupWizardPage.nextKey), isTrue);
    await harness.dispose(tester);
  });

  windowsTest('第四步用示例邮件试分析，显示成功；点 [完成] 关闭向导', (tester) async {
    harness.analyzer.returns(
      sampleMailSubject,
      AnalysisResult(
        category: MailCategory.actionRequired,
        reason: '要交实验报告',
        items: [fakeItem('交实验报告 2')],
      ),
    );
    await harness.launch(tester);
    await openFromStatusLine(tester);
    await throughFolder(tester);
    await tap(tester, SetupWizardPage.nextKey);
    expect(find.text('第 4 步，共 4 步'), findsOneWidget);

    await tap(tester, SetupWizardPage.tryKey);

    expect(find.textContaining('试分析成功'), findsOneWidget);
    expect(find.textContaining('交实验报告 2'), findsOneWidget);
    await tap(tester, SetupWizardPage.finishKey);
    expect(find.byType(SetupWizardPage), findsNothing);
    expect(headline('开始设置'), findsNothing);
    await harness.dispose(tester);
  });

  windowsTest('试分析失败时显示具体原因，可以再试一次', (tester) async {
    harness.analyzer.fails(
      sampleMailSubject,
      AnalysisFailureType.quotaExhausted,
    );
    await harness.launch(tester);
    await openFromStatusLine(tester);
    await throughFolder(tester);
    await tap(tester, SetupWizardPage.nextKey);

    await tap(tester, SetupWizardPage.tryKey);
    expect(find.textContaining('额度已用完'), findsOneWidget);
    expect(find.byKey(SetupWizardPage.finishKey), findsNothing);

    harness.analyzer.returns(
      sampleMailSubject,
      const AnalysisResult(
        category: MailCategory.informational,
        reason: '只是通知',
        items: [],
      ),
    );
    await tap(tester, SetupWizardPage.tryKey);
    expect(find.textContaining('试分析成功'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('每一步都可以返回上一步', (tester) async {
    await harness.launch(tester);
    await openFromStatusLine(tester);
    await throughFolder(tester);
    await tap(tester, SetupWizardPage.nextKey);
    expect(find.text('第 4 步，共 4 步'), findsOneWidget);

    for (final step in [3, 2, 1]) {
      await tap(tester, SetupWizardPage.backKey);
      expect(find.text('第 $step 步，共 4 步'), findsOneWidget);
      // 回到第 2 步时，已经选好的文件夹马上再检查一次。
      if (step == 2) expect(find.text('找到 0 个导出文件'), findsOneWidget);
    }
    expect(find.byKey(SetupWizardPage.backKey), findsNothing);
    await harness.dispose(tester);
  });

  windowsTest('中途退出后，下次从没做完的那一步继续', (tester) async {
    await harness.launch(tester);
    await openFromStatusLine(tester);
    await throughFolder(tester);
    await tester.pageBack();
    await harness.settle(tester);

    await openFromSettings(tester);

    expect(find.text('第 3 步，共 4 步'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('做完以后从设置页重新打开向导，从第一步开始，同意已经勾上', (tester) async {
    await harness.seedWithMail(tester, (service) async {
      await service.agreeToMailUse();
      await service.completeClaudeCheck();
    });
    await harness.seedMailFolder(tester, folder);
    await harness.launch(tester);
    await openFromSettings(tester);
    expect(find.text('第 4 步，共 4 步'), findsOneWidget);
    await tap(tester, SetupWizardPage.tryKey);
    await tap(tester, SetupWizardPage.finishKey);

    await tap(tester, SettingsPage.setupWizardTileKey);

    expect(find.text('第 1 步，共 4 步'), findsOneWidget);
    expect(enabled(tester, SetupWizardPage.nextKey), isTrue);
    await harness.dispose(tester);
  });

  for (final (type, text) in [
    (AnalysisFailureType.notInstalled, '⚠ 找不到 Claude Code，请让设置者检查'),
    (AnalysisFailureType.notLoggedIn, '⚠ Claude 未登录，请打开 Claude Code 登录'),
  ]) {
    windowsTest('状态行的"$text"可以打开向导第三步', (tester) async {
      harness.analyzer.fails('Mail a', type);
      harness.folders.write(
        folder,
        'mail-1.json',
        encode(
          fakeEnvelope([
            fakeMessage(
              internetMessageId: '<a@example.com>',
              subject: 'Mail a',
            ),
          ]),
        ),
        harness.now,
      );
      await harness.seedMailFolder(tester, folder, scans: 2);
      await harness.launch(tester);
      harness.now = harness.now.add(MailScanSchedule.retryInterval);
      await tester.pump(MailScanSchedule.retryInterval);
      await harness.settle(tester);
      expect(headline(text), findsOneWidget);

      await tap(tester, MailImportStatusLine.checkClaudeKey);

      expect(find.text('第 3 步，共 4 步'), findsOneWidget);
      await harness.dispose(tester);
    });
  }
}
