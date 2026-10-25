import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/board_page.dart';
import 'package:my_personal_use_app/board/board_layout.dart';
import 'package:my_personal_use_app/board/date_drawer.dart';
import 'package:my_personal_use_app/board/date_list.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

/// 一套界面按可用宽度自适应：宽度 < 840 是窄屏，日期在左侧的抽屉里；≥ 840
/// 是宽屏，日期侧栏常驻在画布左边，可以折叠（AC-46～AC-50）。
///
/// 假时钟的今天是 2026-10-20（周二），所在的一周是 Oct 19 – Oct 25。
void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 把窗口设成 [width] × 700 逻辑像素。
  void useWindowWidth(WidgetTester tester, double width) {
    tester.view
      ..physicalSize = Size(width, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Finder drawer() => find.byType(DateDrawer);

  Finder sidebar() => find.byType(DateSidebar);

  Finder rowOf(DayKey day) => find.byKey(DateList.dayKey(day));

  /// 标题栏上显示的日期。
  Finder titleOf(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  Future<TaskCard> seedCard(
    WidgetTester tester, {
    DayKey? day,
    double x = 40,
    double y = 60,
  }) async {
    final card = await harness.seed(
      tester,
      (service) => service.createCard(harness.today, title: '买牛奶', x: x, y: y),
    );
    if (day != null) await harness.moveCardToDay(tester, card.id, day);
    return card;
  }

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await harness.settle(tester);
  }

  /// App 运行中把窗口宽度改成 [width]。
  Future<void> resizeTo(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 700);
    await harness.settle(tester);
  }

  Future<void> toggleSidebar(WidgetTester tester) =>
      tapAndSettle(tester, find.byKey(BoardPage.sidebarButtonKey));

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

  /// 标题是 [title] 的编辑框有没有输入焦点。
  bool titleHasFocus(WidgetTester tester, String title) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.widgetWithText(TextField, title),
          matching: find.byType(EditableText),
        ),
      )
      .focusNode
      .hasFocus;

  group('宽屏（AC-46）', () {
    testWidgets('宽度 840 时侧栏常驻在左边，列出今天所在的一周，没有抽屉', (tester) async {
      useWindowWidth(tester, 840);
      await harness.launch(tester);

      expect(sidebar(), findsOneWidget);
      expect(drawer(), findsNothing);
      expect(rowOf(harness.today), findsOneWidget);
      expect(tester.getRect(sidebar()).left, 0);
      await harness.dispose(tester);
    });

    testWidgets('从左边缘往右滑不会拉出抽屉', (tester) async {
      useWindowWidth(tester, 1000);
      await harness.launch(tester);

      await tester.dragFrom(const Offset(5, 400), const Offset(300, 0));
      await harness.settle(tester);

      expect(drawer(), findsNothing);
      await harness.dispose(tester);
    });
  });

  group('窄屏（AC-46）', () {
    testWidgets('宽度 839 时没有侧栏，从左边缘往右滑拉出抽屉', (tester) async {
      useWindowWidth(tester, 839);
      await harness.launch(tester);

      expect(sidebar(), findsNothing);
      expect(find.byKey(BoardPage.sidebarButtonKey), findsNothing);
      await tester.dragFrom(const Offset(5, 400), const Offset(300, 0));
      await harness.settle(tester);

      expect(drawer(), findsOneWidget);
      await harness.dispose(tester);
    });
  });

  group('在侧栏里选日期（AC-47）', () {
    testWidgets('点某一天：侧栏还在，标题和画布换成那一天', (tester) async {
      useWindowWidth(tester, 1000);
      final tomorrow = harness.today.addDays(1);
      final card = await seedCard(tester, day: tomorrow);
      await harness.launch(tester);

      await tapAndSettle(tester, rowOf(tomorrow));

      expect(titleOf('Wed, Oct 21, 2026'), findsOneWidget);
      expect(cardFinder(card), findsOneWidget);
      expect(sidebar(), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('翻到下一周再点「今天」，回到今天', (tester) async {
      useWindowWidth(tester, 1000);
      await harness.launch(tester);
      await tapAndSettle(tester, find.byTooltip('下一周'));
      await tapAndSettle(tester, rowOf(DayKey(2026, 10, 27)));
      expect(titleOf('Tue, Oct 27, 2026'), findsOneWidget);

      await tapAndSettle(tester, find.byKey(DateList.todayButtonKey));

      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('点正在显示的那一天不切换，选中的卡片还选着', (tester) async {
      useWindowWidth(tester, 1000);
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      await tapAndSettle(tester, rowOf(harness.today));

      expect(find.byKey(BoardCanvas.resizeHandleKey(card.id)), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('侧栏里显示未完成数', (tester) async {
      useWindowWidth(tester, 1000);
      await seedCard(tester);
      await harness.launch(tester);

      final count = find.descendant(
        of: rowOf(harness.today),
        matching: find.byKey(DateList.countKey),
      );
      expect(tester.widget<Text>(count).data, '1');
      await harness.dispose(tester);
    });
  });

  group('折叠和展开侧栏（AC-47、AC-50）', () {
    testWidgets('点页头左边的按钮折叠侧栏，画布占满宽度；再点展开', (tester) async {
      useWindowWidth(tester, 1000);
      await harness.launch(tester);

      await toggleSidebar(tester);
      expect(sidebar(), findsNothing);
      expect(drawer(), findsNothing);
      expect(tester.getRect(find.byType(BoardCanvas)).width, 1000);

      await toggleSidebar(tester);
      expect(sidebar(), findsOneWidget);
      await harness.dispose(tester);
    });

    testWidgets('折叠、展开前后，卡片在屏幕上的位置不变', (tester) async {
      useWindowWidth(tester, 1000);
      final card = await seedCard(tester, x: 40, y: 60);
      await harness.launch(tester);
      final before = tester.getRect(cardFinder(card));

      await toggleSidebar(tester);
      expect(tester.getRect(cardFinder(card)), before);

      await toggleSidebar(tester);
      expect(tester.getRect(cardFinder(card)), before);
      await harness.dispose(tester);
    });

    testWidgets('在别的日期折叠侧栏，再切回来：卡片在屏幕上的位置还是不变', (tester) async {
      useWindowWidth(tester, 1000);
      final card = await seedCard(tester, x: 40, y: 60);
      await harness.launch(tester);
      final before = tester.getRect(cardFinder(card));
      await harness.showDay(tester, harness.today.addDays(1));
      await harness.settle(tester);

      await toggleSidebar(tester);
      await harness.showDay(tester, harness.today);
      await harness.settle(tester);

      expect(tester.getRect(cardFinder(card)), before);
      await harness.dispose(tester);
    });

    testWidgets('「＋」在画布可视区域（不含侧栏）的中间新建', (tester) async {
      useWindowWidth(tester, 1000);
      await harness.launch(tester);

      await tapAndSettle(tester, find.byTooltip('新建卡片'));
      await tester.enterText(find.byType(TextField).first, '新任务');
      await tester.runAsync(() => harness.selection(tester).stopEditing());
      await harness.settle(tester);

      // 画布可视区域是 x 304–1000、页头以下的 644 高，中间是 (348, 322)。
      final created = (await harness.readBoard(tester, harness.today)).cards;
      expect(created.single.x, 348 - TaskCard.defaultWidth / 2);
      expect(created.single.y, 322 - TaskCard.defaultHeight / 2);
      await harness.dispose(tester);
    });
  });

  group('宽屏下跳到卡片', () {
    testWidgets('点历史记录跳过去：卡片被侧栏挡住的部分不算看得见，平移到画布可视区域里', (tester) async {
      useWindowWidth(tester, 1000);
      final yesterday = harness.today;
      final card = await seedCard(tester, x: 300, y: 200);
      harness.now = harness.now.add(const Duration(days: 1));
      await harness.seed(tester, (service) => service.runDailyMaintenance());
      final record = (await harness.readBoard(
        tester,
        yesterday,
      )).carryOverRecords.single;
      // 放在 x 600–780：整个窗口有 1000 宽，但画布只有 696 宽，看不全。
      await harness.seed(
        tester,
        (service) => service.moveCard(card.id, x: 600, y: 60),
      );
      harness.displayedDay = yesterday;
      await harness.launch(tester);

      await tester.tap(find.byKey(BoardCanvas.carryOverRecordKey(record.id)));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      final view = tester.getRect(find.byType(InteractiveViewer));
      expect(view.left, dateSidebarWidth);
      final shown = tester.getRect(cardFinder(card));
      expect(view.intersect(shown), shown);
      await harness.dispose(tester);
    });
  });

  group('跨过断点（AC-48、AC-49）', () {
    testWidgets('拖着卡片时跨过断点：拖动接着进行，松手后卡片停在手指下面并保存', (tester) async {
      useWindowWidth(tester, 1000);
      final card = await seedCard(tester, x: 40, y: 60);
      await harness.launch(tester);
      var pointer = tester.getCenter(cardFinder(card));
      final gesture = await tester.startGesture(pointer);
      for (final step in const [Offset(kPanSlop + 4, 0), Offset(30, 0)]) {
        await gesture.moveBy(step);
        pointer += step;
      }
      await tester.pump();

      await resizeTo(tester, 600);
      await gesture.moveBy(const Offset(30, 20));
      pointer += const Offset(30, 20);
      await tester.pump();
      expect(tester.getRect(cardFinder(card)).contains(pointer), isTrue);
      await gesture.up();
      await harness.settle(tester);

      expect(tester.getRect(cardFinder(card)).contains(pointer), isTrue);
      final saved = (await harness.readBoard(tester, harness.today)).cards;
      expect(saved.single.y, 80);
      await harness.dispose(tester);
    });

    testWidgets('编辑中来回跨过断点，编辑框的内容和焦点都还在', (tester) async {
      useWindowWidth(tester, 1000);
      final card = await seedCard(tester);
      await harness.launch(tester);
      await editTitle(tester, card, '买牛奶和面包');
      expect(titleHasFocus(tester, '买牛奶和面包'), isTrue);

      await resizeTo(tester, 600);
      expect(sidebar(), findsNothing);
      expect(find.widgetWithText(TextField, '买牛奶和面包'), findsOneWidget);
      expect(titleHasFocus(tester, '买牛奶和面包'), isTrue);

      await resizeTo(tester, 1000);
      expect(sidebar(), findsOneWidget);
      expect(find.widgetWithText(TextField, '买牛奶和面包'), findsOneWidget);
      expect(titleHasFocus(tester, '买牛奶和面包'), isTrue);
      await harness.dispose(tester);
    });

    testWidgets('抽屉开着时变宽：抽屉关上、侧栏展开；再变窄时抽屉关着', (tester) async {
      useWindowWidth(tester, 1000);
      await harness.launch(tester);
      await toggleSidebar(tester);
      await resizeTo(tester, 600);
      await tapAndSettle(tester, find.byKey(BoardPage.dateDrawerButtonKey));
      expect(drawer(), findsOneWidget);

      await resizeTo(tester, 1000);
      expect(drawer(), findsNothing);
      expect(sidebar(), findsOneWidget);

      await resizeTo(tester, 600);
      expect(drawer(), findsNothing);
      expect(sidebar(), findsNothing);
      await harness.dispose(tester);
    });

    testWidgets('改变窗口大小、跨过断点、折叠侧栏都不改卡片的坐标和大小', (tester) async {
      useWindowWidth(tester, 1000);
      final card = await seedCard(tester, x: 40, y: 60);
      await harness.launch(tester);

      await resizeTo(tester, 1200);
      await toggleSidebar(tester);
      await resizeTo(tester, 500);
      await resizeTo(tester, 900);
      await toggleSidebar(tester);

      final saved = (await harness.readBoard(tester, harness.today)).cards;
      expect(saved.single.id, card.id);
      expect((saved.single.x, saved.single.y), (card.x, card.y));
      expect(
        (saved.single.width, saved.single.height),
        (card.width, card.height),
      );
      expect(saved.single.updatedAt, card.updatedAt);
      await harness.dispose(tester);
    });
  });
}
