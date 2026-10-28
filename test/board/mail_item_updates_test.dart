// 切入点 2：后续邮件的更新建议在界面上的样子：栏里的"已更新"和相关事项，
// 卡片上的更新提示条和 [采用] / [不用]（M-24、M-25、M-26）。
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/mail/mail_analyzer.dart';
import 'package:my_personal_use_app/mail/mail_items_panel.dart';
import 'package:my_personal_use_app/planner/card_time.dart';
import 'package:my_personal_use_app/planner/day_key.dart';

import '../mail/fake_analyzer.dart';
import '../mail/mail_fixtures.dart';
import 'board_harness.dart';

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 在 Windows 上跑的测试。平台和窗口大小要在测试结束前改回来。
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

  Map<String, Object?> mail(
    String subject, {
    String at = '2026-10-19T14:30:00Z',
  }) => fakeMessage(
    internetMessageId: '<$subject@example.com>',
    id: 'AAMk-$subject',
    conversationId: 'conv-a3',
    subject: subject,
    receivedDateTime: at,
  );

  AnalysisResult actionRequired(List<AnalyzedItem> items) => AnalysisResult(
    category: MailCategory.actionRequired,
    reason: '有截止时间',
    items: items,
  );

  final oct30 = CardTime.date(DayKey(2026, 10, 30));
  final nov2 = CardTime.date(DayKey(2026, 11, 2));

  /// 第一封邮件分析出"交作业 3"（截止 Oct 30），返回事项编号。
  Future<String> seedItem(WidgetTester tester) async {
    harness.analyzer.returns(
      'Assignment 3',
      actionRequired([fakeItem('交作业 3', dueTime: oct30)]),
    );
    await harness.seedMail(tester, [mail('Assignment 3')]);
    return harness.seedWithMail(
      tester,
      (service) async => (await service.watchCandidates().first).single.id,
    );
  }

  /// 后续邮件把事项 [itemId] 的截止时间改到 Nov 2。
  Future<void> seedFollowUp(WidgetTester tester, String itemId) {
    harness.analyzer.returns(
      'RE: Assignment 3',
      actionRequired([fakeItem('交作业 3', updates: itemId, dueTime: nov2)]),
    );
    return harness.seedMail(tester, [
      mail('RE: Assignment 3', at: '2026-10-20T08:00:00Z'),
    ]);
  }

  /// 事项加入今天的画布，再来一封后续邮件，然后启动 App。返回卡片编号。
  Future<String> launchWithUpdatedCard(WidgetTester tester) async {
    final itemId = await seedItem(tester);
    final cardId = await harness.seedWithMail(
      tester,
      (service) async => (await service.acceptItem(
        itemId,
        day: harness.today,
        x: 40,
        y: 40,
      )).id,
    );
    await seedFollowUp(tester, itemId);
    await harness.launch(tester);
    return cardId;
  }

  Finder panelText(String text) => find.descendant(
    of: find.byType(MailItemsPanel),
    matching: find.text(text),
  );

  windowsTest('被后续邮件更新过的候选标"已更新"', (tester) async {
    final itemId = await seedItem(tester);
    await seedFollowUp(tester, itemId);
    await harness.launch(tester);

    expect(panelText('交作业 3'), findsOneWidget);
    expect(panelText('已更新'), findsOneWidget);
    expect(panelText('⏰ 截止 Nov 2'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('卡片上出现"📩 有更新"和 [采用] / [不用]，没点之前卡片不变', (tester) async {
    final cardId = await launchWithUpdatedCard(tester);

    expect(find.text('📩 有更新：截止 Oct 30 → Nov 2'), findsOneWidget);
    expect(find.byKey(BoardCanvas.applyUpdateKey(cardId)), findsOneWidget);
    expect(find.byKey(BoardCanvas.rejectUpdateKey(cardId)), findsOneWidget);
    final card = (await harness.readBoard(tester, harness.today)).cards.single;
    expect(card.dueTime, oct30);
    await harness.dispose(tester);
  });

  windowsTest('点 [采用] 后卡片改成新的截止时间，提示消失', (tester) async {
    final cardId = await launchWithUpdatedCard(tester);

    await tester.tap(find.byKey(BoardCanvas.applyUpdateKey(cardId)));
    await harness.settle(tester);

    final card = (await harness.readBoard(tester, harness.today)).cards.single;
    expect(card.dueTime, nov2);
    expect(find.textContaining('📩 有更新'), findsNothing);
    expect(find.text('⏰ 截止 Nov 2'), findsOneWidget);
    await harness.dispose(tester);
  });

  windowsTest('点 [不用] 后提示消失，卡片不变', (tester) async {
    final cardId = await launchWithUpdatedCard(tester);

    await tester.tap(find.byKey(BoardCanvas.rejectUpdateKey(cardId)));
    await harness.settle(tester);

    final card = (await harness.readBoard(tester, harness.today)).cards.single;
    expect(card.dueTime, oct30);
    expect(find.textContaining('📩 有更新'), findsNothing);
    await harness.dispose(tester);
  });

  windowsTest('[采用] 时存不进去：提示失败，卡片和提示都不变', (tester) async {
    final cardId = await launchWithUpdatedCard(tester);
    harness.failWrites = true;

    await tester.tap(find.byKey(BoardCanvas.applyUpdateKey(cardId)));
    await harness.settle(tester);

    expect(find.text('采用失败，请重试'), findsOneWidget);
    expect(find.text('📩 有更新：截止 Oct 30 → Nov 2'), findsOneWidget);
    harness.failWrites = false;
    final card = (await harness.readBoard(tester, harness.today)).cards.single;
    expect(card.dueTime, oct30);
    await harness.dispose(tester);
  });

  windowsTest('涉及已完成的事项时，新候选注明相关事项', (tester) async {
    final itemId = await seedItem(tester);
    final cardId = await harness.seedWithMail(
      tester,
      (service) async => (await service.acceptItem(
        itemId,
        day: harness.today,
        x: 40,
        y: 40,
      )).id,
    );
    await harness.seed(tester, (planner) => planner.completeCard(cardId));
    await seedFollowUp(tester, itemId);
    await harness.launch(tester);

    expect(panelText('可能和已完成的《交作业 3》有关'), findsOneWidget);
    expect(find.textContaining('📩 有更新'), findsNothing);
    await harness.dispose(tester);
  });
}
