import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/date_bar.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

/// 顶部的日期栏：◀ / ▶、滑动、「今天」都通过统一的入口切换日期（AC-2），
/// 每一格显示两行日期和未完成数（AC-3、AC-4）。
///
/// 假时钟的今天是 2026-10-20（周二），所在的一周是 Oct 19 – Oct 25。
void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 标题栏上显示的日期。
  Finder titleOf(String text) => find.descendant(
    of: find.byType(AppBar),
    matching: find.text(text),
    skipOffstage: false,
  );

  Finder cellOf(DayKey day) => find.byKey(DateBar.cellKey(day));

  /// [day] 那一格里的未完成数。
  Finder countIn(DayKey day) =>
      find.descendant(of: cellOf(day), matching: find.byKey(DateBar.countKey));

  String? countTextIn(WidgetTester tester, DayKey day) =>
      tester.widget<Text>(countIn(day)).data;

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  /// 在 [day] 那天准备一张卡片。过去的日期不能新建，先建在今天再挪过去。
  Future<TaskCard> seedCard(
    WidgetTester tester,
    DayKey day, {
    String title = '买牛奶',
  }) async {
    final card = await harness.seed(
      tester,
      (service) =>
          service.createCard(harness.today, title: title, x: 40, y: 60),
    );
    if (day != harness.today) await harness.moveCardToDay(tester, card.id, day);
    return card;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await harness.settle(tester);
  }

  group('切换日期（AC-2）', () {
    testWidgets('点 ▶ 切到后一天，画布显示那一天的卡片', (tester) async {
      final tomorrow = harness.today.addDays(1);
      final card = await seedCard(tester, tomorrow);
      await harness.launch(tester);
      expect(cardFinder(card), findsNothing);

      await tapAndSettle(tester, find.byTooltip('后一天'));

      expect(titleOf('Wed, Oct 21, 2026'), findsOneWidget);
      expect(cardFinder(card), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('点 ◀ 切到前一天，画布显示那一天的卡片', (tester) async {
      final yesterday = harness.today.addDays(-1);
      // 今天已经维护过：之后才放到过去日期的卡片，启动时不会被顺延走。
      await harness.seed(tester, (service) => service.runDailyMaintenance());
      final card = await seedCard(tester, yesterday);
      await harness.launch(tester);

      await tapAndSettle(tester, find.byTooltip('前一天'));

      expect(titleOf('Mon, Oct 19, 2026'), findsOneWidget);
      expect(cardFinder(card), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('跨周点 ▶：日期栏翻到新的一周', (tester) async {
      harness.displayedDay = DayKey(2026, 10, 25);
      await harness.launch(tester);

      await tapAndSettle(tester, find.byTooltip('后一天'));

      expect(titleOf('Mon, Oct 26, 2026'), findsOneWidget);
      expect(cellOf(DayKey(2026, 10, 26)), findsOneWidget);
      expect(cellOf(DayKey(2026, 10, 25)), findsNothing);
      await harness.dispose(tester);
    });

    testWidgets('正在编辑时连点两次 ▶：保存完以后一共走两天', (tester) async {
      final card = await seedCard(tester, harness.today);
      await harness.launch(tester);
      for (var i = 0; i < 2; i++) {
        await tester.tap(cardFinder(card));
        await tester.pump(kDoubleTapTimeout);
        await harness.settle(tester);
      }
      await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买牛奶和面包');

      // 第一次的保存还没完成时就点第二次。
      await tester.tap(find.byTooltip('后一天'));
      await tester.tap(find.byTooltip('后一天'));
      await harness.settle(tester);

      expect(titleOf('Thu, Oct 22, 2026'), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('点「今天」回到今天', (tester) async {
      harness.displayedDay = DayKey(2026, 12, 1);
      await harness.launch(tester);

      await tapAndSettle(tester, find.text('今天'));

      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
      expect(cellOf(harness.today), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('点日期栏的格子切到那一天', (tester) async {
      await harness.launch(tester);

      await tapAndSettle(tester, cellOf(DayKey(2026, 10, 23)));

      expect(titleOf('Fri, Oct 23, 2026'), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('向左滑日期栏切到后一天，画布显示那一天的卡片', (tester) async {
      final tomorrow = harness.today.addDays(1);
      final card = await seedCard(tester, tomorrow);
      await harness.launch(tester);

      await tester.drag(cellOf(DayKey(2026, 10, 22)), const Offset(-200, 0));
      await harness.settle(tester);

      expect(titleOf('Wed, Oct 21, 2026'), findsOneWidget);
      expect(cardFinder(card), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('向右滑日期栏切到前一天', (tester) async {
      await harness.launch(tester);

      await tester.drag(cellOf(DayKey(2026, 10, 22)), const Offset(200, 0));
      await harness.settle(tester);

      expect(titleOf('Mon, Oct 19, 2026'), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('在周日向左滑：切到下周一，日期栏换成新的一周', (tester) async {
      harness.displayedDay = DayKey(2026, 10, 25);
      await harness.launch(tester);

      await tester.drag(cellOf(DayKey(2026, 10, 22)), const Offset(-200, 0));
      await harness.settle(tester);

      expect(titleOf('Mon, Oct 26, 2026'), findsOneWidget);
      expect(cellOf(DayKey(2026, 10, 26)), findsOneWidget);
      expect(cellOf(DayKey(2026, 10, 25)), findsNothing);
      await harness.dispose(tester);
    });

    testWidgets('在画布空白处滑动不切换日期，只平移画布', (tester) async {
      final card = await seedCard(tester, harness.today);
      await harness.launch(tester);
      const blankSpot = Offset(600, 400);
      expect(
        tester.getRect(find.byType(InteractiveViewer)).contains(blankSpot),
        isTrue,
      );
      expect(tester.getRect(find.byType(DateBar)).contains(blankSpot), isFalse);
      expect(tester.getRect(cardFinder(card)).contains(blankSpot), isFalse);
      final before = tester.getTopLeft(cardFinder(card));

      await tester.dragFrom(blankSpot, const Offset(-500, 0));
      await harness.settle(tester);

      expect(tester.getTopLeft(cardFinder(card)).dx, lessThan(before.dx));
      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('正在编辑时点 ▶ 而保存失败：提示，不切换，输入的内容还在', (tester) async {
      final card = await seedCard(tester, harness.today);
      await harness.launch(tester);
      for (var i = 0; i < 2; i++) {
        await tester.tap(cardFinder(card));
        await tester.pump(kDoubleTapTimeout);
        await harness.settle(tester);
      }
      await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买牛奶和面包');
      harness.failWrites = true;

      await tapAndSettle(tester, find.byTooltip('后一天'));

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
      expect(find.widgetWithText(TextField, '买牛奶和面包'), findsOneWidget);

      harness.failWrites = false;
      await harness.dispose(tester);
    });
  });

  group('日期栏的格子（AC-3、AC-4）', () {
    testWidgets('一周七格，每格两行：日期不带年份、星期', (tester) async {
      await harness.launch(tester);

      for (var i = 0; i < 7; i++) {
        expect(cellOf(DayKey(2026, 10, 19 + i)), findsOneWidget);
      }
      final cell = cellOf(DayKey(2026, 10, 20));
      expect(
        find.descendant(of: cell, matching: find.text('Oct 20')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cell, matching: find.text('Tue')),
        findsOneWidget,
      );
      await harness.dispose(tester);
    });

    testWidgets('其他年份的格子也不带年份', (tester) async {
      harness.displayedDay = DayKey(2027, 1, 3);
      await harness.launch(tester);

      final cell = cellOf(DayKey(2027, 1, 3));
      expect(
        find.descendant(of: cell, matching: find.text('Jan 3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: cell, matching: find.text('Sun')),
        findsOneWidget,
      );
      expect(titleOf('Sun, Jan 3, 2027'), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('显示未完成数，不算已完成的卡片和历史记录', (tester) async {
      final yesterday = harness.today.addDays(-1);
      final tomorrow = harness.today.addDays(1);
      // 昨天的卡片顺延到今天，昨天只留下历史记录；之后再往昨天放一张未完成的。
      await seedCard(tester, yesterday, title: '顺延的');
      await harness.seed(tester, (service) => service.runDailyMaintenance());
      await seedCard(tester, yesterday, title: '昨天的');
      await seedCard(tester, harness.today, title: '未完成');
      final done = await seedCard(tester, harness.today, title: '已完成');
      await harness.seed(tester, (service) => service.completeCard(done.id));
      for (final title in ['甲', '乙', '丙']) {
        await seedCard(tester, tomorrow, title: title);
      }
      await harness.launch(tester);

      expect(countTextIn(tester, yesterday), '1');
      // 今天：「未完成」和顺延过来的「顺延的」，不算「已完成」。
      expect(countTextIn(tester, harness.today), '2');
      expect(countTextIn(tester, tomorrow), '3');
      await harness.dispose(tester);
    });

    testWidgets('未完成数随卡片完成而更新', (tester) async {
      final card = await seedCard(tester, harness.today);
      await harness.launch(tester);
      expect(countTextIn(tester, harness.today), '1');

      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(cardFinder(card));
      await harness.settle(tester);

      expect(countTextIn(tester, harness.today), '0');
      await harness.dispose(tester);
    });

    testWidgets('没有未完成的卡片时显示 0', (tester) async {
      await harness.launch(tester);

      for (var i = 0; i < 7; i++) {
        expect(countTextIn(tester, DayKey(2026, 10, 19 + i)), '0');
      }
      await harness.dispose(tester);
    });

    testWidgets('切到过去的日期时，那一格高亮', (tester) async {
      final yesterday = harness.today.addDays(-1);
      await harness.launch(tester);

      await tapAndSettle(tester, find.byTooltip('前一天'));

      expect(
        tester.getSemantics(cellOf(yesterday)),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(cellOf(harness.today)),
        isSemantics(isSelected: false),
      );
      await harness.dispose(tester);
    });

    testWidgets('当前显示的那一格高亮', (tester) async {
      await harness.launch(tester);
      await tapAndSettle(tester, cellOf(DayKey(2026, 10, 23)));

      expect(
        tester.getSemantics(cellOf(DayKey(2026, 10, 23))),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(cellOf(harness.today)),
        isSemantics(isSelected: false),
      );
      await harness.dispose(tester);
    });
  });
}
