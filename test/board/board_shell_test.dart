import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 在今天的画布上准备一张「买牛奶」卡片。
  Future<TaskCard> seedCard(WidgetTester tester) => harness.seed(
    tester,
    (service) => service.createCard(harness.today, title: '买牛奶', x: 40, y: 60),
  );

  testWidgets('冷启动显示今天的画布和标题', (tester) async {
    await seedCard(tester);

    await harness.launch(tester);

    expect(find.text('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
    expect(find.text('买牛奶'), findsOneWidget);

    await harness.dispose(tester);
  });

  testWidgets('数据库打不开时显示错误页和重试按钮，不显示空画布', (tester) async {
    harness.failingOpens = 1;

    await harness.launch(tester);

    expect(find.text('数据库打不开'), findsOneWidget);
    expect(find.textContaining('模拟的数据库打不开'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.byType(BoardCanvas), findsNothing);

    await harness.dispose(tester);
  });

  testWidgets('点重试后存储能打开时进入今天的画布', (tester) async {
    await seedCard(tester);
    harness.failingOpens = 1;
    await harness.launch(tester);

    await tester.tap(find.text('重试'));
    await harness.settle(tester);

    expect(find.text('数据库打不开'), findsNothing);
    expect(find.text('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
    expect(find.text('买牛奶'), findsOneWidget);

    await harness.dispose(tester);
  });

  group('平移和缩放', () {
    late TaskCard card;

    /// 画布上一块没有卡片的空白处。
    const blankSpot = Offset(500, 400);

    Future<void> launchWithCard(WidgetTester tester) async {
      card = await seedCard(tester);
      await harness.launch(tester);
    }

    /// 卡片在屏幕上的位置和大小（经过画布的平移和缩放）。
    Rect cardRect(WidgetTester tester) =>
        tester.getRect(find.byKey(BoardCanvas.cardKey(card.id)));

    /// 在空白处滚一下鼠标滚轮；[dy] 为负是向上滚。
    Future<void> scrollWheel(WidgetTester tester, {required double dy}) async {
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(blankSpot));
      await tester.sendEventToBinding(mouse.scroll(Offset(0, dy)));
      await tester.pump();
    }

    Future<void> ctrlScrollWheel(
      WidgetTester tester, {
      required double dy,
    }) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await scrollWheel(tester, dy: dy);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    }

    /// 两根手指以空白处为中心，水平间距从 2×[from] 变到 2×[to]。
    Future<void> pinch(
      WidgetTester tester, {
      required double from,
      required double to,
    }) async {
      final first = await tester.startGesture(blankSpot - Offset(from, 0));
      final second = await tester.startGesture(blankSpot + Offset(from, 0));
      for (var step = 1; step <= 5; step++) {
        final distance = from + (to - from) * step / 5;
        await first.moveTo(blankSpot - Offset(distance, 0));
        await second.moveTo(blankSpot + Offset(distance, 0));
        await tester.pump();
      }
      await first.up();
      await second.up();
      await harness.settle(tester);
    }

    testWidgets('在空白处拖动鼠标平移画布，卡片在画布上的位置不变', (tester) async {
      await launchWithCard(tester);
      final gesture = await tester.startGesture(
        blankSpot,
        kind: PointerDeviceKind.mouse,
      );
      // 先越过拖动判定的距离，之后的移动才全部用来平移。
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump();
      final before = cardRect(tester);

      await gesture.moveBy(const Offset(100, 50));
      await tester.pump();
      final after = cardRect(tester);
      await gesture.up();
      await harness.settle(tester);

      expect(after.topLeft - before.topLeft, const Offset(100, 50));
      expect(after.size, before.size);
      final saved = (await harness.readBoard(
        tester,
        harness.today,
      )).cards.single;
      expect((saved.x, saved.y), (40, 60));

      await harness.dispose(tester);
    });

    testWidgets('按住 Ctrl 向上滚动鼠标滚轮放大画布', (tester) async {
      await launchWithCard(tester);
      final original = cardRect(tester).size;

      await ctrlScrollWheel(tester, dy: -100);

      expect(cardRect(tester).width, greaterThan(original.width));

      await harness.dispose(tester);
    });

    testWidgets('按住 Ctrl 向下滚动鼠标滚轮缩小画布', (tester) async {
      await launchWithCard(tester);
      final original = cardRect(tester).size;

      await ctrlScrollWheel(tester, dy: 100);

      expect(cardRect(tester).width, lessThan(original.width));

      await harness.dispose(tester);
    });

    testWidgets('不按 Ctrl 滚动鼠标滚轮不缩放画布', (tester) async {
      await launchWithCard(tester);
      final original = cardRect(tester).size;

      await scrollWheel(tester, dy: -100);

      expect(cardRect(tester).size, original);

      await harness.dispose(tester);
    });

    testWidgets('Ctrl+滚轮最多放大到 3 倍', (tester) async {
      await launchWithCard(tester);

      for (var i = 0; i < 20; i++) {
        await ctrlScrollWheel(tester, dy: -100);
      }

      expect(
        cardRect(tester).width,
        moreOrLessEquals(TaskCard.defaultWidth * 3),
      );

      await harness.dispose(tester);
    });

    testWidgets('Ctrl+滚轮最多缩小到 0.5 倍', (tester) async {
      await launchWithCard(tester);

      for (var i = 0; i < 20; i++) {
        await ctrlScrollWheel(tester, dy: 100);
      }

      expect(
        cardRect(tester).width,
        moreOrLessEquals(TaskCard.defaultWidth * 0.5),
      );

      await harness.dispose(tester);
    });

    testWidgets('双指在空白处张开放大画布', (tester) async {
      await launchWithCard(tester);
      final original = cardRect(tester).size;

      await pinch(tester, from: 50, to: 150);

      expect(cardRect(tester).width, greaterThan(original.width));

      await harness.dispose(tester);
    });

    testWidgets('双指在空白处捏合缩小画布', (tester) async {
      await launchWithCard(tester);
      final original = cardRect(tester).size;

      await pinch(tester, from: 150, to: 50);

      expect(cardRect(tester).width, lessThan(original.width));

      await harness.dispose(tester);
    });
  });
}
