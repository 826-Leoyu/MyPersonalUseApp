import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/board_page.dart';
import 'package:my_personal_use_app/board/completed_page.dart';
import 'package:my_personal_use_app/board/link_layer.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 在 [day]（默认今天）准备一张未完成的卡片。
  Future<TaskCard> seedCard(
    WidgetTester tester, {
    String title = '买牛奶',
    DayKey? day,
    double x = 40,
    double y = 60,
  }) => harness.seed(
    tester,
    (service) =>
        service.createCard(day ?? harness.today, title: title, x: x, y: y),
  );

  /// 在 [at]（默认现在）这个时间把卡片完成。
  Future<void> complete(
    WidgetTester tester,
    TaskCard card, {
    DateTime? at,
  }) async {
    final now = harness.now;
    harness.now = at ?? now;
    await harness.seed(tester, (service) => service.completeCard(card.id));
    harness.now = now;
  }

  /// 在 [day]（默认今天）准备一张卡片，在 [at] 这个时间把它完成。
  Future<TaskCard> seedCompleted(
    WidgetTester tester, {
    required String title,
    required DateTime at,
    DayKey? day,
  }) async {
    final card = await seedCard(tester, title: title, day: day);
    await complete(tester, card, at: at);
    return card;
  }

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  /// 在画布上双击卡片完成它，等动画和保存都结束。
  Future<void> doubleTapCard(WidgetTester tester, TaskCard card) async {
    await tester.tap(cardFinder(card));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(cardFinder(card));
    await harness.settle(tester);
  }

  /// 单击两次卡片进入编辑。
  Future<void> startEditing(WidgetTester tester, TaskCard card) async {
    for (var i = 0; i < 2; i++) {
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
    }
  }

  /// 点画布标题栏上的「已完成」，打开显示的那一天的已完成列表。
  Future<void> openCompletedList(WidgetTester tester) async {
    await tester.tap(find.byKey(BoardPage.completedButtonKey));
    await harness.settle(tester);
  }

  Finder itemFinder(TaskCard card) =>
      find.byKey(CompletedPage.itemKey(card.id));

  /// 列表里这一项上的按钮。
  Finder itemButton(TaskCard card, String tooltip) =>
      find.descendant(of: itemFinder(card), matching: find.byTooltip(tooltip));

  /// 点列表里这一项的「取消完成」。
  Future<void> uncomplete(WidgetTester tester, TaskCard card) async {
    await tester.tap(itemButton(card, '取消完成'));
    await harness.settle(tester);
  }

  /// 从已完成列表回到画布。
  Future<void> backToBoard(WidgetTester tester) async {
    await tester.pageBack();
    await harness.settle(tester);
  }

  /// 连线层现在画着的连线 ID。
  List<String> shownLinkIds(WidgetTester tester) {
    final layer = tester.widget<CustomPaint>(find.byKey(LinkLayer.paintKey));
    return [for (final link in (layer.painter! as LinkPainter).links) link.id];
  }

  Finder titleOf(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  group('已完成列表', () {
    testWidgets('标题用完整格式和完成数量；每项带 HH:mm 完成时间，按完成时间倒序（AC-20）', (tester) async {
      final earlier = await seedCompleted(
        tester,
        title: '买牛奶',
        at: DateTime(2026, 10, 20, 9, 5),
      );
      final later = await seedCompleted(
        tester,
        title: '写周报',
        at: DateTime(2026, 10, 20, 14, 30),
      );
      await harness.launch(tester);

      await openCompletedList(tester);

      expect(titleOf('Tue, Oct 20, 2026 · 已完成 2 项'), findsOneWidget);
      expect(
        find.descendant(of: itemFinder(earlier), matching: find.text('09:05')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: itemFinder(later), matching: find.text('14:30')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(itemFinder(later)).dy,
        lessThan(tester.getTopLeft(itemFinder(earlier)).dy),
      );

      await harness.dispose(tester);
    });

    testWidgets('取消完成今天的卡片：从列表消失，回到画布原来的位置，连线重新显示（AC-21）', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      final linkId = await harness.seed(
        tester,
        (service) async => (await service.toggleLink(a.id, b.id)).linkId,
      );
      await harness.launch(tester);
      final before = tester.getRect(cardFinder(a));
      await doubleTapCard(tester, a);
      expect(shownLinkIds(tester), isEmpty);
      await openCompletedList(tester);

      await uncomplete(tester, a);

      expect(itemFinder(a), findsNothing);
      expect(titleOf('Tue, Oct 20, 2026 · 已完成 0 项'), findsOneWidget);
      await backToBoard(tester);
      expect(tester.getRect(cardFinder(a)), before);
      expect(shownLinkIds(tester), [linkId]);

      await harness.dispose(tester);
    });

    testWidgets('取消完成过去日期的卡片：顺延到今天，原日期留下历史记录（AC-21）', (tester) async {
      final yesterday = harness.today;
      final card = await seedCompleted(
        tester,
        title: '写周报',
        at: DateTime(2026, 10, 20, 15),
      );
      harness.now = DateTime(2026, 10, 21, 9);
      await harness.seed(tester, (service) => service.runDailyMaintenance());
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      await openCompletedList(tester);

      await uncomplete(tester, card);

      expect(itemFinder(card), findsNothing);
      expect(find.text('已顺延至 Oct 21'), findsOneWidget);
      expect(
        (await harness.readBoard(tester, harness.today)).cards.map((c) => c.id),
        [card.id],
      );
      final record = (await harness.readBoard(
        tester,
        yesterday,
      )).carryOverRecords.single;
      await backToBoard(tester);
      expect(
        find.byKey(BoardCanvas.carryOverRecordKey(record.id)),
        findsOneWidget,
      );

      await harness.dispose(tester);
    });

    testWidgets('带「顺延」标记的卡片：列表里不显示标记，取消完成后回到画布仍带标记（AC-47）', (tester) async {
      final card = await seedCard(tester, title: '写周报');
      harness.now = DateTime(2026, 10, 21, 9);
      await harness.seed(tester, (service) => service.runDailyMaintenance());
      await harness.launch(tester);
      final tag = find.byKey(BoardCanvas.carriedOverTagKey(card.id));
      expect(tag, findsOneWidget);
      await doubleTapCard(tester, card);
      await openCompletedList(tester);

      expect(itemFinder(card), findsOneWidget);
      expect(
        find.descendant(of: itemFinder(card), matching: find.text('顺延')),
        findsNothing,
      );

      await uncomplete(tester, card);
      await backToBoard(tester);
      expect(tag, findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('取消完成保存失败：仍在列表里，提示「保存失败，请重试」', (tester) async {
      final card = await seedCompleted(
        tester,
        title: '写周报',
        at: DateTime(2026, 10, 20, 8),
      );
      await harness.launch(tester);
      await openCompletedList(tester);
      harness.failWrites = true;

      await uncomplete(tester, card);

      expect(itemFinder(card), findsOneWidget);
      expect(find.text('保存失败，请重试'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('删除：从列表消失，卡片进入回收站；点「撤销」回到列表', (tester) async {
      final card = await seedCompleted(
        tester,
        title: '写周报',
        at: DateTime(2026, 10, 20, 8),
      );
      await harness.launch(tester);
      await openCompletedList(tester);

      await tester.tap(itemButton(card, '删除'));
      await harness.settle(tester);

      expect(itemFinder(card), findsNothing);
      expect(titleOf('Tue, Oct 20, 2026 · 已完成 0 项'), findsOneWidget);
      expect(
        (await harness.seed(tester, (s) => s.findCard(card.id))).inTrash,
        isTrue,
      );

      await tester.tap(find.text('撤销'));
      await harness.settle(tester);

      expect(itemFinder(card), findsOneWidget);
      expect(
        (await harness.seed(tester, (s) => s.findCard(card.id))).inTrash,
        isFalse,
      );

      await harness.dispose(tester);
    });

    testWidgets('正在编辑卡片时打开列表：先保存输入的内容', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await startEditing(tester, card);
      await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买牛奶和面包');

      await openCompletedList(tester);

      expect(find.byType(CompletedPage), findsOneWidget);
      final saved = (await harness.readBoard(tester, harness.today)).cards;
      expect(saved.single.title, '买牛奶和面包');

      await harness.dispose(tester);
    });

    testWidgets('正在编辑卡片时打开列表而保存失败：提示，不打开，输入的内容还在', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await startEditing(tester, card);
      await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买牛奶和面包');
      harness.failWrites = true;

      await openCompletedList(tester);

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(find.byType(CompletedPage), findsNothing);
      expect(find.widgetWithText(TextField, '买牛奶和面包'), findsOneWidget);

      harness.failWrites = false;
      await harness.dispose(tester);
    });

    testWidgets('读不出已完成列表：提示「读取失败，请重试」，点「重试」重新读取', (tester) async {
      final card = await seedCompleted(
        tester,
        title: '写周报',
        at: DateTime(2026, 10, 20, 8),
      );
      await harness.launch(tester);
      harness.failReads = true;

      await openCompletedList(tester);

      expect(find.text('读取失败，请重试'), findsOneWidget);
      expect(itemFinder(card), findsNothing);

      harness.failReads = false;
      await tester.tap(find.text('重试'));
      await harness.settle(tester);

      expect(itemFinder(card), findsOneWidget);

      await harness.dispose(tester);
    });
  });
}
