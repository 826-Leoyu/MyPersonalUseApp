import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/board_layout.dart';
import 'package:my_personal_use_app/board/board_page.dart';
import 'package:my_personal_use_app/board/board_selection.dart';
import 'package:my_personal_use_app/board/date_drawer.dart';
import 'package:my_personal_use_app/board/date_list.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

/// 自适应布局下各平台的输入方式：Windows 的键盘焦点和滚轮，Android 的返回键
/// （#66）。
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

  /// 在 Windows 上跑的测试。平台要在测试结束前改回来，否则测试框架报错。
  void windowsTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  Finder drawer() => find.byType(DateDrawer);

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  /// 在今天的画布上准备一张卡片。
  Future<TaskCard> seedCard(WidgetTester tester) => harness.seed(
    tester,
    (service) => service.createCard(harness.today, title: '买牛奶', x: 40, y: 60),
  );

  /// 单击卡片，等过了双击判定时间，单击才生效。
  Future<void> tapCard(WidgetTester tester, TaskCard card) async {
    await tester.tap(cardFinder(card));
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);
  }

  Finder rowOf(DayKey day) => find.byKey(DateList.dayKey(day));

  /// 画布正在显示哪一天。
  DayKey displayedDay(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(BoardCanvas)))
          .read(displayedDayProvider);

  /// 画布现在的选中状态。
  BoardSelection selection(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(BoardCanvas)))
          .read(boardSelectionProvider);

  Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await harness.settle(tester);
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await harness.settle(tester);
  }

  Future<void> pressWithCtrl(
    WidgetTester tester,
    LogicalKeyboardKey key,
  ) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await harness.settle(tester);
  }

  group('宽屏侧栏里点了某一天以后，快捷键照常能用', () {
    windowsTest('点另一天再按 ← 和 T', (tester) async {
      useWindowWidth(tester, 1000);
      await harness.launch(tester);
      final tomorrow = harness.today.addDays(1);

      await tapAndSettle(tester, rowOf(tomorrow));
      expect(displayedDay(tester), tomorrow);
      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(displayedDay(tester), harness.today.addDays(2));
      await press(tester, LogicalKeyboardKey.keyT);

      expect(displayedDay(tester), harness.today);
      await harness.dispose(tester);
    });

    windowsTest('点正在显示的那一天再按 ←', (tester) async {
      useWindowWidth(tester, 1000);
      await harness.launch(tester);

      await tapAndSettle(tester, rowOf(harness.today));
      await press(tester, LogicalKeyboardKey.arrowLeft);

      expect(displayedDay(tester), harness.today.addDays(-1));
      await harness.dispose(tester);
    });

    windowsTest('点「下一周」再按 Ctrl+N 新建卡片', (tester) async {
      useWindowWidth(tester, 1000);
      await harness.launch(tester);

      await tapAndSettle(tester, find.byTooltip('下一周'));
      await pressWithCtrl(tester, LogicalKeyboardKey.keyN);

      expect(selection(tester), isA<EditingNewCard>());
      await harness.dispose(tester);
    });
  });

  group('窄屏的日期抽屉', () {
    windowsTest('抽屉开着时按 Esc 关上抽屉，选中的卡片还选着', (tester) async {
      useWindowWidth(tester, 600);
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);
      await tapAndSettle(tester, find.byKey(BoardPage.dateDrawerButtonKey));
      expect(drawer(), findsOneWidget);

      await press(tester, LogicalKeyboardKey.escape);

      expect(drawer(), findsNothing);
      expect(selection(tester), isA<CardSelected>());
      await harness.dispose(tester);
    });

    windowsTest('抽屉关上以后再按 Esc 取消选中', (tester) async {
      useWindowWidth(tester, 600);
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);
      await tapAndSettle(tester, find.byKey(BoardPage.dateDrawerButtonKey));
      await press(tester, LogicalKeyboardKey.escape);

      await press(tester, LogicalKeyboardKey.escape);

      expect(selection(tester), isA<NothingSelected>());
      await harness.dispose(tester);
    });
  });

  group('宽屏侧栏跟着快捷键换的日期', () {
    /// [day] 那一行在侧栏里高亮着，并且没被列表的边缘裁掉，点得到。
    void expectHighlightedAndVisible(WidgetTester tester, DayKey day) {
      expect(rowOf(day).hitTestable(), findsOneWidget);
      expect(tester.widget<Semantics>(rowOf(day)).properties.selected, isTrue);
    }

    windowsTest('从很远的一天按 T 回到今天：侧栏滚到今天', (tester) async {
      useWindowWidth(tester, 1000);
      harness.displayedDay = DayKey(2026, 12, 9);
      await harness.launch(tester);

      await press(tester, LogicalKeyboardKey.keyT);

      expectHighlightedAndVisible(tester, harness.today);
      await harness.dispose(tester);
    });

    windowsTest('连按 → 翻过几周：侧栏跟着滚，选中的那一天一直看得到', (tester) async {
      useWindowWidth(tester, 1000);
      await harness.launch(tester);

      for (var i = 1; i <= 16; i++) {
        await press(tester, LogicalKeyboardKey.arrowRight);
        expectHighlightedAndVisible(tester, harness.today.addDays(i));
      }
      await harness.dispose(tester);
    });

    windowsTest('连按 ← 翻到更早的周：侧栏往上滚', (tester) async {
      useWindowWidth(tester, 1000);
      await harness.launch(tester);

      for (var i = 1; i <= 16; i++) {
        await press(tester, LogicalKeyboardKey.arrowLeft);
        expectHighlightedAndVisible(tester, harness.today.addDays(-i));
      }
      await harness.dispose(tester);
    });
  });

  group('返回键', () {
    testWidgets('宽屏下按返回键不折叠侧栏', (tester) async {
      useWindowWidth(tester, 1000);
      await harness.launch(tester);

      await tester.binding.handlePopRoute();
      await harness.settle(tester);

      expect(find.byType(DateSidebar), findsOneWidget);
      await harness.dispose(tester);
    });
  });

  group('侧栏里的滚轮', () {
    /// 在侧栏中间滚一下鼠标滚轮；[ctrl] 为 true 时按住 Ctrl。
    Future<void> scrollSidebar(
      WidgetTester tester, {
      required double dy,
      bool ctrl = false,
    }) async {
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      if (ctrl) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendEventToBinding(
        mouse.hover(tester.getCenter(find.byType(DateSidebar))),
      );
      await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
      if (ctrl) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await harness.settle(tester);
    }

    windowsTest('滚轮只滚动日期列表，不缩放、不平移画布', (tester) async {
      useWindowWidth(tester, 1000);
      final card = await seedCard(tester);
      await harness.launch(tester);
      final cardBefore = tester.getRect(cardFinder(card));
      final rowBefore = tester.getRect(rowOf(harness.today));

      await scrollSidebar(tester, dy: 100);

      expect(tester.getRect(rowOf(harness.today)).top, rowBefore.top - 100);
      expect(tester.getRect(cardFinder(card)), cardBefore);
      await harness.dispose(tester);
    });

    windowsTest('按住 Ctrl 滚轮也不缩放画布', (tester) async {
      useWindowWidth(tester, 1000);
      final card = await seedCard(tester);
      await harness.launch(tester);
      final cardBefore = tester.getRect(cardFinder(card));

      await scrollSidebar(tester, dy: -100, ctrl: true);
      await scrollSidebar(tester, dy: 100, ctrl: true);

      expect(tester.getRect(cardFinder(card)), cardBefore);
      await harness.dispose(tester);
    });
  });
}
