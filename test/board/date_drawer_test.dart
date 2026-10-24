import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/board_page.dart';
import 'package:my_personal_use_app/board/date_drawer.dart';
import 'package:my_personal_use_app/board/date_list.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

/// 左侧的日期抽屉：默认关着，点左上角按钮或从左边缘往右滑打开，往左滑、点
/// 外面、按返回键关上。选一天或点「今天」时抽屉关上，再通过统一的入口切换
/// 日期（AC-2）。每一行显示日期、星期和未完成数（AC-3、AC-4）。
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

  Finder drawer() => find.byType(DateDrawer);

  Finder rowOf(DayKey day) => find.byKey(DateList.dayKey(day));

  /// [day] 那一行里的未完成数。
  Finder countIn(DayKey day) =>
      find.descendant(of: rowOf(day), matching: find.byKey(DateList.countKey));

  String? countTextIn(WidgetTester tester, DayKey day) =>
      tester.widget<Text>(countIn(day)).data;

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  /// 在 [day] 那天准备一张卡片。过去的日期不能新建，先建在今天再挪过去。
  Future<TaskCard> seedCard(
    WidgetTester tester,
    DayKey day, {
    String title = '买牛奶',
    double x = 40,
    double y = 60,
  }) async {
    final card = await harness.seed(
      tester,
      (service) => service.createCard(harness.today, title: title, x: x, y: y),
    );
    if (day != harness.today) await harness.moveCardToDay(tester, card.id, day);
    return card;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await harness.settle(tester);
  }

  Future<void> openDrawer(WidgetTester tester) =>
      tapAndSettle(tester, find.byKey(BoardPage.dateDrawerButtonKey));

  /// 单击卡片两次进入编辑，把标题改成 [text]。
  Future<void> editTitle(
    WidgetTester tester,
    TaskCard card,
    String text,
  ) async {
    for (var i = 0; i < 2; i++) {
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
    }
    await tester.enterText(find.widgetWithText(TextField, card.title), text);
  }

  group('打开和关上', () {
    testWidgets('启动时抽屉关着，画布上方没有日期栏', (tester) async {
      await harness.launch(tester);

      expect(drawer(), findsNothing);
      expect(find.byKey(BoardPage.dateDrawerButtonKey), findsOneWidget);
      expect(rowOf(harness.today), findsNothing);
      await harness.dispose(tester);
    });

    testWidgets('点左上角的按钮打开抽屉，显示今天所在的一周', (tester) async {
      await harness.launch(tester);

      await openDrawer(tester);

      expect(drawer(), findsOneWidget);
      for (var i = 0; i < 7; i++) {
        expect(rowOf(DayKey(2026, 10, 19 + i)), findsOneWidget);
      }
      expect(find.text('Oct 19 – Oct 25'), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('从左边缘往右滑打开抽屉', (tester) async {
      await harness.launch(tester);

      await tester.dragFrom(const Offset(5, 300), const Offset(300, 0));
      await harness.settle(tester);

      expect(drawer(), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('往左滑关上抽屉', (tester) async {
      await harness.launch(tester);
      await openDrawer(tester);

      await tester.dragFrom(const Offset(250, 300), const Offset(-300, 0));
      await harness.settle(tester);

      expect(drawer(), findsNothing);
      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('点抽屉外面关上抽屉，不在画布上新建卡片', (tester) async {
      await harness.launch(tester);
      await openDrawer(tester);

      await tester.tapAt(const Offset(700, 300));
      await harness.settle(tester);

      expect(drawer(), findsNothing);
      expect(find.byType(TextField), findsNothing);
      await harness.dispose(tester);
    });

    testWidgets('按返回键关上抽屉，停在画布上', (tester) async {
      await harness.launch(tester);
      await openDrawer(tester);

      await tester.binding.handlePopRoute();
      await harness.settle(tester);

      expect(drawer(), findsNothing);
      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('在画布空白处横向拖动只平移画布，不打开抽屉、不切换日期', (tester) async {
      final card = await seedCard(tester, harness.today);
      await harness.launch(tester);
      const blankSpot = Offset(600, 400);
      expect(tester.getRect(cardFinder(card)).contains(blankSpot), isFalse);
      final before = tester.getTopLeft(cardFinder(card));

      await tester.dragFrom(blankSpot, const Offset(300, 0));
      await harness.settle(tester);

      expect(tester.getTopLeft(cardFinder(card)).dx, greaterThan(before.dx));
      expect(drawer(), findsNothing);
      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('离左边 24 的地方往右滑也能打开抽屉', (tester) async {
      await harness.launch(tester);

      await tester.dragFrom(const Offset(24, 300), const Offset(300, 0));
      await harness.settle(tester);

      expect(drawer(), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('有系统手势区时，从手势区内侧再往里 24 的地方往右滑也能打开抽屉', (tester) async {
      tester.view.systemGestureInsets = FakeViewPadding(
        left: 30 * tester.view.devicePixelRatio,
      );
      addTearDown(tester.view.resetSystemGestureInsets);
      await harness.launch(tester);

      await tester.dragFrom(const Offset(54, 300), const Offset(300, 0));
      await harness.settle(tester);

      expect(drawer(), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('按住边缘范围里的卡片往右拖：卡片跟着走，不打开抽屉', (tester) async {
      final card = await seedCard(tester, harness.today, x: 4);
      await harness.launch(tester);
      final before = tester.getRect(cardFinder(card));
      final edge = drawerEdgeDragWidth(
        tester.element(find.byType(BoardCanvas)),
      );
      // 按下的位置在卡片上，也在边缘拉出抽屉的范围里。
      final start = Offset(before.left + 6, before.center.dy);
      expect(start.dx, lessThan(edge));

      final gesture = await tester.startGesture(start);
      await tester.pump();
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(const Offset(20, 0));
        await tester.pump();
      }
      await gesture.up();
      await harness.settle(tester);

      expect(
        tester.getRect(cardFinder(card)),
        before.shift(const Offset(200, 0)),
      );
      expect(drawer(), findsNothing);
      await harness.dispose(tester);
    });

    testWidgets('拖完边缘范围里的卡片，再从边缘往右滑照常打开抽屉', (tester) async {
      final card = await seedCard(tester, harness.today, x: 4, y: 60);
      await harness.launch(tester);
      final rect = tester.getRect(cardFinder(card));
      await tester.dragFrom(
        Offset(rect.left + 6, rect.center.dy),
        const Offset(0, 100),
      );
      await harness.settle(tester);

      await tester.dragFrom(const Offset(5, 500), const Offset(300, 0));
      await harness.settle(tester);

      expect(drawer(), findsOneWidget);
      await harness.dispose(tester);
    });
  });

  group('选择日期（AC-2）', () {
    testWidgets('点某一天：抽屉关上，标题和画布换成那一天', (tester) async {
      final tomorrow = harness.today.addDays(1);
      final card = await seedCard(tester, tomorrow);
      await harness.launch(tester);
      expect(cardFinder(card), findsNothing);
      await openDrawer(tester);

      await tapAndSettle(tester, rowOf(tomorrow));

      expect(drawer(), findsNothing);
      expect(titleOf('Wed, Oct 21, 2026'), findsOneWidget);
      expect(cardFinder(card), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('点过去的一天，画布显示那一天的卡片', (tester) async {
      final yesterday = harness.today.addDays(-1);
      // 今天已经维护过：之后才放到过去日期的卡片，启动时不会被顺延走。
      await harness.seed(tester, (service) => service.runDailyMaintenance());
      final card = await seedCard(tester, yesterday);
      await harness.launch(tester);
      await openDrawer(tester);

      await tapAndSettle(tester, rowOf(yesterday));

      expect(titleOf('Mon, Oct 19, 2026'), findsOneWidget);
      expect(cardFinder(card), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('点「今天」：抽屉关上，回到今天', (tester) async {
      harness.displayedDay = DayKey(2026, 12, 1);
      await harness.launch(tester);
      await openDrawer(tester);
      expect(rowOf(DayKey(2026, 12, 1)), findsOneWidget);

      await tapAndSettle(tester, find.byKey(DateList.todayButtonKey));

      expect(drawer(), findsNothing);
      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('点正在显示的那一天只关上抽屉，选中的卡片还选着', (tester) async {
      final card = await seedCard(tester, harness.today);
      await harness.launch(tester);
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      expect(find.byKey(BoardCanvas.resizeHandleKey(card.id)), findsOneWidget);
      await openDrawer(tester);

      await tapAndSettle(tester, rowOf(harness.today));

      expect(drawer(), findsNothing);
      expect(find.byKey(BoardCanvas.resizeHandleKey(card.id)), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('点「下一周」翻到下一周，再点那一周的某一天切过去', (tester) async {
      await harness.launch(tester);
      await openDrawer(tester);

      await tapAndSettle(tester, find.byTooltip('下一周'));
      final next = DayKey(2026, 10, 28);
      expect(rowOf(next).hitTestable(), findsOneWidget);
      await tapAndSettle(tester, rowOf(next));

      expect(titleOf('Wed, Oct 28, 2026'), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('点「上一周」翻到上一周', (tester) async {
      await harness.launch(tester);
      await openDrawer(tester);
      expect(rowOf(DayKey(2026, 10, 14)).hitTestable(), findsNothing);

      await tapAndSettle(tester, find.byTooltip('上一周'));

      expect(find.text('Oct 12 – Oct 18'), findsOneWidget);
      expect(rowOf(DayKey(2026, 10, 14)).hitTestable(), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('往下拉能一直滚到更早的周', (tester) async {
      await harness.launch(tester);
      await openDrawer(tester);

      // 一次次往下拉，直到能点到那一行。
      await tester.dragUntilVisible(
        rowOf(DayKey(2026, 9, 1)).hitTestable(),
        find.descendant(of: drawer(), matching: find.byType(Scrollable)),
        const Offset(0, 300),
      );
      await harness.settle(tester);
      await tapAndSettle(tester, rowOf(DayKey(2026, 9, 1)));

      expect(titleOf('Tue, Sep 1, 2026'), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('换了一天再打开抽屉，从那一天所在的一周开始', (tester) async {
      harness.displayedDay = DayKey(2026, 11, 11);
      await harness.launch(tester);

      await openDrawer(tester);

      expect(find.text('Nov 9 – Nov 15'), findsOneWidget);
      expect(rowOf(DayKey(2026, 11, 11)).hitTestable(), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('正在编辑时选另一天：先保存编辑的内容再切换', (tester) async {
      final card = await seedCard(tester, harness.today);
      await harness.launch(tester);
      await editTitle(tester, card, '买牛奶和面包');
      await openDrawer(tester);

      await tapAndSettle(tester, rowOf(harness.today.addDays(1)));

      expect(titleOf('Wed, Oct 21, 2026'), findsOneWidget);
      final saved = (await harness.readBoard(tester, harness.today)).cards;
      expect(saved.single.title, '买牛奶和面包');
      await harness.dispose(tester);
    });

    testWidgets('正在编辑时选另一天而保存失败：提示，不切换，输入的内容还在', (tester) async {
      final card = await seedCard(tester, harness.today);
      await harness.launch(tester);
      await editTitle(tester, card, '买牛奶和面包');
      await openDrawer(tester);
      harness.failWrites = true;

      await tapAndSettle(tester, rowOf(harness.today.addDays(1)));

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
      expect(find.widgetWithText(TextField, '买牛奶和面包'), findsOneWidget);

      harness.failWrites = false;
      await harness.dispose(tester);
    });
  });

  group('抽屉里的每一行（AC-3、AC-4）', () {
    testWidgets('每行显示星期和不带年份的日期，其他年份的周在范围里带年份', (tester) async {
      harness.displayedDay = DayKey(2027, 1, 3);
      await harness.launch(tester);
      await openDrawer(tester);

      final row = rowOf(DayKey(2027, 1, 3));
      expect(
        find.descendant(of: row, matching: find.text('Jan 3')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Sun')),
        findsOneWidget,
      );
      expect(find.text('Dec 28 – Jan 3, 2027'), findsOneWidget);
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
      await openDrawer(tester);

      expect(countTextIn(tester, yesterday), '1');
      // 今天：「未完成」和顺延过来的「顺延的」，不算「已完成」。
      expect(countTextIn(tester, harness.today), '2');
      expect(countTextIn(tester, tomorrow), '3');
      expect(countTextIn(tester, DayKey(2026, 10, 25)), '0');
      await harness.dispose(tester);
    });

    testWidgets('完成卡片后未完成数更新', (tester) async {
      final card = await seedCard(tester, harness.today);
      await harness.launch(tester);
      await openDrawer(tester);
      expect(countTextIn(tester, harness.today), '1');
      await tester.tapAt(const Offset(700, 300));
      await harness.settle(tester);

      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(cardFinder(card));
      await harness.settle(tester);
      await openDrawer(tester);

      expect(countTextIn(tester, harness.today), '0');
      await harness.dispose(tester);
    });

    testWidgets('显示的那一天高亮，今天另有标记', (tester) async {
      harness.displayedDay = DayKey(2026, 10, 23);
      await harness.launch(tester);
      await openDrawer(tester);

      expect(
        tester.getSemantics(rowOf(DayKey(2026, 10, 23))),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(rowOf(harness.today)),
        isSemantics(isSelected: false),
      );
      expect(
        find.descendant(of: rowOf(harness.today), matching: find.text('今天')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: rowOf(DayKey(2026, 10, 23)),
          matching: find.text('今天'),
        ),
        findsNothing,
      );
      await harness.dispose(tester);
    });
  });

  group('标题', () {
    /// 常见手机的宽度（逻辑像素）。
    Future<void> usePhoneSize(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(360, 780)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('窄屏上标题完整显示，不和左右的按钮重叠', (tester) async {
      await usePhoneSize(tester);
      harness.displayedDay = DayKey(2026, 10, 24);
      harness.now = DateTime(2026, 10, 24, 9);
      await harness.launch(tester);

      final title = titleOf('Sat, Oct 24, 2026 · 今天');
      expect(title, findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: title, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      final titleRect = tester.getRect(title);
      expect(
        titleRect.left,
        greaterThanOrEqualTo(
          tester.getRect(find.byKey(BoardPage.dateDrawerButtonKey)).right,
        ),
      );
      expect(
        titleRect.right,
        lessThanOrEqualTo(
          tester.getRect(find.byKey(BoardPage.completedButtonKey)).left,
        ),
      );
      await harness.dispose(tester);
    });
  });
}
