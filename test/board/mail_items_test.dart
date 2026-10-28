// 切入点 2："新邮件事项"栏、加入和忽略、卡片上的信封图标和来源邮件
// （M-14、M-16、M-17）。分析器是按脚本返回结果的假分析器。
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/board_page.dart';
import 'package:my_personal_use_app/board/dot_grid.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_detail_page.dart';
import 'package:my_personal_use_app/mail/mail_items_panel.dart';
import 'package:my_personal_use_app/planner/card_time.dart';

import '../mail/fake_analyzer.dart';
import '../mail/mail_fixtures.dart';
import 'board_harness.dart';

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 在 Windows 上跑的测试，窗口宽 [width]。平台和窗口大小要在测试结束前
  /// 改回来，否则测试框架报错。
  void windowsTest(
    String description,
    Future<void> Function(WidgetTester tester) body, {
    double width = 1280,
  }) => testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view
      ..physicalSize = Size(width, 800)
      ..devicePixelRatio = 1;
    try {
      await body(tester);
    } finally {
      tester.view.reset();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  Map<String, Object?> mail(
    String subject, {
    String sender = '李明',
    String at = '2026-10-19T14:30:00Z',
  }) => fakeMessage(
    internetMessageId: '<$subject@example.com>',
    id: 'AAMk-$subject',
    conversationId: 'conv-$subject',
    subject: subject,
    from: {
      'emailAddress': {'name': sender, 'address': 'li@example.com'},
    },
    receivedDateTime: at,
  );

  AnalysisResult actionRequired(List<AnalyzedItem> items) => AnalysisResult(
    category: MailCategory.actionRequired,
    reason: '有截止时间',
    items: items,
  );

  windowsTest('候选事项在画布右边的栏里：需要行动在前，可选活动带"可选"标签', (tester) async {
    harness.analyzer
      ..returns(
        'Career fair',
        AnalysisResult(
          category: MailCategory.optionalEvent,
          reason: '可以去',
          items: [
            fakeItem(
              '参加秋季招聘会',
              optional: true,
              eventTime: CardTime.dateTime(DateTime(2026, 10, 22, 10)),
            ),
          ],
        ),
      )
      ..returns(
        'Report due',
        actionRequired([
          fakeItem(
            '交周报',
            dueTime: CardTime.dateTime(DateTime(2026, 10, 30, 23, 59)),
          ),
        ]),
      );
    await harness.seedMail(tester, [
      mail('Career fair', sender: '就业中心'),
      mail('Report due'),
    ]);
    await harness.launch(tester);

    expect(find.text('新邮件事项'), findsOneWidget);
    final report = tester.getTopLeft(find.text('交周报'));
    final fair = tester.getTopLeft(find.text('参加秋季招聘会'));
    expect(report.dy, lessThan(fair.dy));
    // 栏在画布右边。
    expect(report.dx, greaterThan(1280 - 400));
    expect(find.text('⏰ 截止 Oct 30 23:59'), findsOneWidget);
    expect(find.text('来自 就业中心《Career fair》'), findsOneWidget);
    expect(find.text('可选'), findsOneWidget);
    await harness.dispose(tester);
  });

  /// 导入一封"需要行动"的邮件，分析出一个事项 [title]，然后启动 App。
  Future<void> launchWithItem(
    WidgetTester tester,
    String title, {
    String? summary,
    CardTime? dueTime,
  }) async {
    harness.analyzer.returns(
      'Report due',
      actionRequired([fakeItem(title, summary: summary, dueTime: dueTime)]),
    );
    await harness.seedMail(tester, [mail('Report due')]);
    await harness.launch(tester);
  }

  /// "新邮件事项"栏里的文字 [text]。
  Finder inPanel(String text) => find.descendant(
    of: find.byType(MailItemsPanel),
    matching: find.text(text),
  );

  /// 点 [finder]，等数据库写完、界面刷新。
  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await harness.settle(tester);
  }

  windowsTest('[加入] 后今天的画布中间出现一张卡片，带信封图标，事项离开栏', (tester) async {
    await launchWithItem(
      tester,
      '交周报',
      summary: '每周五交',
      dueTime: CardTime.dateTime(DateTime(2026, 10, 30, 23, 59)),
    );

    await tapAndSettle(tester, find.text('加入'));

    final card = (await harness.readBoard(tester, harness.today)).cards.single;
    expect(card.title, '交周报');
    expect(card.note, '每周五交');
    expect(card.dueTime, CardTime.dateTime(DateTime(2026, 10, 30, 23, 59)));
    expect(find.text('没有新的邮件事项'), findsOneWidget);
    expect(find.byKey(BoardCanvas.mailIconKey(card.id)), findsOneWidget);
    // 放在画布可见区域的中间，和「＋」新建的卡片一样。
    final shown = tester.getCenter(find.byKey(BoardCanvas.cardKey(card.id)));
    final canvas = tester.getRect(find.byType(DotGrid));
    expect(shown.dx, moreOrLessEquals(canvas.center.dx, epsilon: 1));
    expect(shown.dy, moreOrLessEquals(canvas.center.dy, epsilon: 1));
    await harness.dispose(tester);
  });

  windowsTest('改日期以后 [加入]，卡片放到那一天，今天的画布上没有', (tester) async {
    await launchWithItem(tester, '交周报');

    await tapAndSettle(tester, inPanel('今天'));
    await tester.tap(find.text('22'));
    await tapAndSettle(tester, find.text('OK'));
    expect(inPanel('Oct 22'), findsOneWidget);
    await tapAndSettle(tester, find.text('加入'));

    final later = await harness.readBoard(tester, harness.today.addDays(2));
    expect(later.cards.map((c) => c.title), ['交周报']);
    expect((await harness.readBoard(tester, harness.today)).cards, isEmpty);
    await harness.dispose(tester);
  });

  windowsTest('改日期不能选过去的日子', (tester) async {
    await launchWithItem(tester, '交周报');

    await tapAndSettle(tester, inPanel('今天'));
    // 昨天在日期选择器里不能点。
    await tester.tap(find.text('19'));
    await tapAndSettle(tester, find.text('OK'));

    expect(inPanel('今天'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('[忽略] 后事项从栏里消失，画布上没有新卡片', (tester) async {
    await launchWithItem(tester, '交周报');

    await tapAndSettle(tester, find.text('忽略'));

    expect(find.text('交周报'), findsNothing);
    expect(find.text('没有新的邮件事项'), findsOneWidget);
    expect((await harness.readBoard(tester, harness.today)).cards, isEmpty);
    await harness.dispose(tester);
  });

  windowsTest('[加入] 时存不进去：提示失败，事项还在栏里，画布上没有新卡片', (tester) async {
    await launchWithItem(tester, '交周报');
    harness.failWrites = true;

    await tapAndSettle(tester, find.text('加入'));

    expect(find.text('加入失败，请重试'), findsOneWidget);
    expect(find.text('交周报'), findsOneWidget);
    harness.failWrites = false;
    expect((await harness.readBoard(tester, harness.today)).cards, isEmpty);
    await harness.dispose(tester);
  });

  windowsTest('栏收起后页头有带数字的"邮件事项"按钮，点它重新展开', (tester) async {
    await launchWithItem(tester, '交周报');
    expect(find.byKey(BoardPage.mailItemsButtonKey), findsNothing);

    await tapAndSettle(tester, find.byKey(MailItemsPanel.collapseButtonKey));

    expect(find.text('交周报'), findsNothing);
    final button = find.byKey(BoardPage.mailItemsButtonKey);
    expect(
      find.descendant(of: button, matching: find.text('1')),
      findsOneWidget,
    );

    await tapAndSettle(tester, button);

    expect(find.text('交周报'), findsOneWidget);
    expect(find.byKey(BoardPage.mailItemsButtonKey), findsNothing);
    await harness.dispose(tester);
  });

  windowsTest('窗口窄时没有右边的栏，页头按钮打开底部面板，在里面 [加入]', (tester) async {
    await launchWithItem(tester, '交周报');
    expect(find.text('交周报'), findsNothing);

    await tapAndSettle(tester, find.byKey(BoardPage.mailItemsButtonKey));
    expect(find.text('交周报'), findsOneWidget);
    await tapAndSettle(tester, find.text('加入'));

    expect(find.text('没有新的邮件事项'), findsOneWidget);
    final card = (await harness.readBoard(tester, harness.today)).cards.single;
    expect(card.title, '交周报');
    await harness.dispose(tester);
  }, width: 600);

  testWidgets('Android 上没有"新邮件事项"栏和按钮', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view
      ..physicalSize = const Size(1280, 800)
      ..devicePixelRatio = 1;
    try {
      await harness.launch(tester);

      expect(find.byType(MailItemsPanel), findsNothing);
      expect(find.byKey(BoardPage.mailItemsButtonKey), findsNothing);
      await harness.dispose(tester);
    } finally {
      tester.view.reset();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  /// 单击卡片两次进入编辑，每次等过了双击判定时间。
  Future<void> editCard(WidgetTester tester, String cardId) async {
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byKey(BoardCanvas.cardKey(cardId)));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
    }
  }

  windowsTest('编辑来自邮件的卡片时点"查看来源邮件"，打开那封邮件', (tester) async {
    await launchWithItem(tester, '交周报');
    await tapAndSettle(tester, find.text('加入'));
    final card = (await harness.readBoard(tester, harness.today)).cards.single;

    await editCard(tester, card.id);
    final button = find.text('查看来源邮件');
    await tester.ensureVisible(button);
    await tapAndSettle(tester, button);

    expect(find.byType(MailDetailPage), findsOneWidget);
    expect(find.text('Report due'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('编辑不是来自邮件的卡片时没有"查看来源邮件"', (tester) async {
    final card = await harness.seed(
      tester,
      (service) =>
          service.createCard(harness.today, title: '买牛奶', x: 40, y: 60),
    );
    await harness.launch(tester);

    await editCard(tester, card.id);

    expect(find.widgetWithText(TextField, '标题'), findsOneWidget);
    expect(find.text('查看来源邮件'), findsNothing);
    await harness.dispose(tester);
  });

  windowsTest('点开事项看到摘要、要做的事、地点和链接，可以打开原邮件', (tester) async {
    harness.analyzer.returns(
      'Report due',
      actionRequired([
        fakeItem(
          '交周报',
          summary: '每周五交',
          actions: ['写周报'],
          location: 'Room 101',
        ),
      ]),
    );
    await harness.seedMail(tester, [mail('Report due')]);
    await harness.launch(tester);
    expect(find.text('每周五交'), findsNothing);

    await tapAndSettle(tester, find.text('交周报'));

    expect(find.text('每周五交'), findsOneWidget);
    expect(find.text('- 写周报'), findsOneWidget);
    expect(find.text('地点：Room 101'), findsOneWidget);
    await tapAndSettle(tester, find.text('查看原邮件'));
    expect(find.byType(MailDetailPage), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('正文已清除时，打开原邮件显示"原文已清理，请在 Outlook 中查看"', (tester) async {
    harness.analyzer.returns('Report due', actionRequired([fakeItem('交周报')]));
    await harness.seedMail(tester, [mail('Report due')]);
    await harness.clearMailBodies(tester);
    await harness.launch(tester);

    await tapAndSettle(tester, find.text('交周报'));
    await tapAndSettle(tester, find.text('查看原邮件'));

    expect(find.byType(MailDetailPage), findsOneWidget);
    expect(find.text('原文已清理，请在 Outlook 中查看'), findsOneWidget);
    expect(find.text('（没有正文）'), findsNothing);
    await harness.dispose(tester);
  });

  windowsTest('邮件有附件时，事项上提示"附件或图片未分析"', (tester) async {
    harness.analyzer.returns('Report due', actionRequired([fakeItem('交周报')]));
    await harness.seedMail(tester, [
      {...mail('Report due'), 'hasAttachments': true},
    ]);
    await harness.launch(tester);

    expect(find.text('附件或图片未分析'), findsOneWidget);
    await harness.dispose(tester);
  });
}
