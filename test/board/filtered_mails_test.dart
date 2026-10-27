// 切入点 2："已过滤的邮件"、[这封有用] 和 [恢复]（M-15、M-18、M-19、M-21）。
// 分析器是按脚本返回结果的假分析器。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/mail/filtered_mails_page.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_items_panel.dart';

import '../mail/fake_analyzer.dart';
import '../mail/mail_fixtures.dart';
import 'board_harness.dart';

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 在 Windows 上跑的测试。平台和窗口大小要在测试结束前改回来，否则测试
  /// 框架报错。
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

  /// 收件时间：本地时间 Oct 19 10:30。
  final received = DateTime(2026, 10, 19, 10, 30).toUtc().toIso8601String();

  Map<String, Object?> mail(String subject, {String sender = '图书馆'}) =>
      fakeMessage(
        internetMessageId: '<$subject@example.com>',
        id: 'AAMk-$subject',
        conversationId: 'conv-$subject',
        subject: subject,
        from: {
          'emailAddress': {'name': sender, 'address': 'lib@example.com'},
        },
        receivedDateTime: received,
      );

  /// 点 [finder]，等数据库写完、界面刷新。
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await harness.settle(tester);
  }

  /// "新邮件事项"栏里的文字 [text]。
  Finder inPanel(String text) => find.descendant(
    of: find.byType(MailItemsPanel),
    matching: find.text(text),
  );

  /// 导入一封"仅供参考"的邮件 Library hours，启动 App，打开已过滤的邮件。
  Future<void> openWithInformational(WidgetTester tester) async {
    harness.analyzer.returns(
      'Library hours',
      const AnalysisResult(
        category: MailCategory.informational,
        reason: '只是开放时间通知',
        items: [],
      ),
    );
    await harness.seedMail(tester, [mail('Library hours')]);
    await harness.launch(tester);
    await tapAndSettle(tester, find.text('已过滤的邮件 (1)'));
  }

  windowsTest('栏底部的"已过滤的邮件 (N)"打开列表，每条有主题、发件人、日期和理由', (tester) async {
    await openWithInformational(tester);

    expect(find.byType(FilteredMailsPage), findsOneWidget);
    expect(find.text('Library hours'), findsOneWidget);
    expect(find.text('图书馆 · Oct 19 10:30'), findsOneWidget);
    expect(find.text('只是开放时间通知'), findsOneWidget);
    expect(find.text('这封有用'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('点 [这封有用] 后重新分析，事项出现在栏里，邮件离开列表', (tester) async {
    await openWithInformational(tester);
    harness.analyzer.returns(
      'Library hours',
      AnalysisResult(
        category: MailCategory.actionRequired,
        reason: '要续借',
        items: [fakeItem('续借图书')],
      ),
    );

    await tapAndSettle(tester, find.text('这封有用'));

    expect(find.text('Library hours'), findsNothing);
    expect(find.text('没有已过滤的邮件'), findsOneWidget);
    await tester.pageBack();
    await harness.settle(tester);
    expect(inPanel('续借图书'), findsOneWidget);
    expect(inPanel('已过滤的邮件 (0)'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('正文已清除时点 [这封有用]，提示在 Outlook 中查看', (tester) async {
    harness.analyzer.returns(
      'Library hours',
      const AnalysisResult(
        category: MailCategory.informational,
        reason: '只是开放时间通知',
        items: [],
      ),
    );
    await harness.seedMail(tester, [mail('Library hours')]);
    await harness.clearMailBodies(tester);
    await harness.launch(tester);
    await tapAndSettle(tester, find.text('已过滤的邮件 (1)'));

    await tapAndSettle(tester, find.text('这封有用'));

    expect(find.text('原文已清理，请在 Outlook 中查看'), findsOneWidget);
    expect(find.text('Library hours'), findsOneWidget);
    expect(harness.analyzer.requests, hasLength(1));
    await harness.dispose(tester);
  });

  windowsTest('被忽略的事项在列表里，点 [恢复] 回到栏里', (tester) async {
    harness.analyzer.returns(
      'Report due',
      AnalysisResult(
        category: MailCategory.actionRequired,
        reason: '有截止时间',
        items: [fakeItem('交周报')],
      ),
    );
    await harness.seedMail(tester, [mail('Report due', sender: '李明')]);
    await harness.launch(tester);
    await tapAndSettle(tester, find.text('忽略'));
    await tapAndSettle(tester, find.text('已过滤的邮件 (1)'));

    expect(find.text('交周报'), findsOneWidget);
    expect(find.text('你忽略了这个事项'), findsOneWidget);
    await tapAndSettle(tester, find.text('恢复'));

    expect(find.text('没有已过滤的邮件'), findsOneWidget);
    await tester.pageBack();
    await harness.settle(tester);
    expect(inPanel('交周报'), findsOneWidget);
    await harness.dispose(tester);
  });
}
