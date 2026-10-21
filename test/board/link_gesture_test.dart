import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/card_drag.dart';
import 'package:my_personal_use_app/planner/link.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 在今天的画布上准备一张卡片（默认 180 × 88）。
  Future<TaskCard> seedCard(
    WidgetTester tester, {
    required String title,
    required double x,
    double y = 60,
  }) => harness.seed(
    tester,
    (service) => service.createCard(harness.today, title: title, x: x, y: y),
  );

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  /// 卡片现在显示的放大倍数。
  double cardScale(WidgetTester tester, TaskCard card) => tester
      .widget<AnimatedScale>(
        find.descendant(
          of: cardFinder(card),
          matching: find.byType(AnimatedScale),
        ),
      )
      .scale;

  /// 存储里今天的连线。
  Future<List<Link>> savedLinks(WidgetTester tester) async =>
      (await harness.readBoard(tester, harness.today)).links;

  /// 存储里这张卡片现在的样子。
  Future<TaskCard> savedCard(WidgetTester tester, TaskCard card) async =>
      (await harness.readBoard(
        tester,
        harness.today,
      )).cards.singleWhere((c) => c.id == card.id);

  /// 按住 [dragged] 的中心，拖到 [to]（屏幕坐标），还没松手。
  Future<TestGesture> dragTo(
    WidgetTester tester,
    TaskCard dragged,
    Offset to,
  ) async {
    final from = tester.getCenter(cardFinder(dragged));
    final gesture = await tester.startGesture(from);
    // 先移动一小段开始拖动，再移到目标位置。
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveTo(to);
    await tester.pump();
    return gesture;
  }

  /// 松手，等连线保存好、被拖的卡片弹回去。
  Future<void> release(WidgetTester tester, TestGesture gesture) async {
    await gesture.up();
    await harness.settle(tester);
  }

  testWidgets('在另一张卡片上停满 400ms：目标放大、出现虚线预览；松手新建连线，被拖卡片回到原处（AC-13）', (
    tester,
  ) async {
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    await harness.launch(tester);
    final before = tester.getRect(cardFinder(a));

    final gesture = await dragTo(tester, a, tester.getCenter(cardFinder(b)));
    await tester.pump(CardDragMachine.armDelay);
    await tester.pump(const Duration(milliseconds: 200));

    expect(cardScale(tester, b), 1.05);
    expect(find.byKey(BoardCanvas.linkPreviewKey), findsOneWidget);
    expect(find.byKey(BoardCanvas.unlinkPreviewKey), findsNothing);

    await release(tester, gesture);

    final links = await savedLinks(tester);
    expect(links.map((l) => (l.fromCardId, l.toCardId)), [(a.id, b.id)]);
    expect(tester.getRect(cardFinder(a)), before);
    final saved = await savedCard(tester, a);
    expect((saved.x, saved.y), (a.x, a.y));
    expect(cardScale(tester, b), 1);
    expect(find.byKey(BoardCanvas.linkPreviewKey), findsNothing);

    await harness.dispose(tester);
  });

  testWidgets('在另一张卡片上停不到 400ms 就移开：没有连线，卡片停在松手的位置（AC-12）', (tester) async {
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    await harness.launch(tester);

    final gesture = await dragTo(tester, a, tester.getCenter(cardFinder(b)));
    await tester.pump(const Duration(milliseconds: 300));
    // 移到 B 下面的空白处，再等一会儿，计时不会接着算。
    await gesture.moveTo(
      tester.getBottomLeft(cardFinder(b)) + const Offset(0, 100),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(cardScale(tester, b), 1);
    expect(find.byKey(BoardCanvas.linkPreviewKey), findsNothing);
    final dropped = tester.getRect(cardFinder(a));

    await release(tester, gesture);

    expect(await savedLinks(tester), isEmpty);
    expect(tester.getRect(cardFinder(a)), dropped);
    final saved = await savedCard(tester, a);
    expect((saved.x, saved.y), isNot((a.x, a.y)));

    await harness.dispose(tester);
  });

  testWidgets('停不到 400ms 就在目标卡片上松手，当作普通移动', (tester) async {
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    await harness.launch(tester);

    final gesture = await dragTo(tester, a, tester.getCenter(cardFinder(b)));
    await tester.pump(const Duration(milliseconds: 300));
    final dropped = tester.getRect(cardFinder(a));
    await release(tester, gesture);

    expect(await savedLinks(tester), isEmpty);
    expect(tester.getRect(cardFinder(a)), dropped);

    await harness.dispose(tester);
  });

  testWidgets('出现预览后移开就取消：预览消失，松手是普通移动', (tester) async {
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    await harness.launch(tester);

    final gesture = await dragTo(tester, a, tester.getCenter(cardFinder(b)));
    await tester.pump(CardDragMachine.armDelay);
    expect(find.byKey(BoardCanvas.linkPreviewKey), findsOneWidget);

    await gesture.moveTo(
      tester.getBottomLeft(cardFinder(b)) + const Offset(0, 100),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(BoardCanvas.linkPreviewKey), findsNothing);
    expect(cardScale(tester, b), 1);
    await release(tester, gesture);

    expect(await savedLinks(tester), isEmpty);

    await harness.dispose(tester);
  });

  for (final reversed in [false, true]) {
    final direction = reversed ? 'B → A' : 'A → B';
    testWidgets('已经连着（$direction）：停满 400ms 显示 ✂️，松手断开（AC-14）', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 400);
      await harness.seed(
        tester,
        (service) => reversed
            ? service.toggleLink(b.id, a.id)
            : service.toggleLink(a.id, b.id),
      );
      await harness.launch(tester);
      final before = tester.getRect(cardFinder(a));

      final gesture = await dragTo(tester, a, tester.getCenter(cardFinder(b)));
      await tester.pump(CardDragMachine.armDelay);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(BoardCanvas.unlinkPreviewKey), findsOneWidget);
      expect(find.byKey(BoardCanvas.linkPreviewKey), findsNothing);
      expect(cardScale(tester, b), 1.05);

      await release(tester, gesture);

      expect(await savedLinks(tester), isEmpty);
      expect(tester.getRect(cardFinder(a)), before);
      expect(find.byKey(BoardCanvas.unlinkPreviewKey), findsNothing);

      await harness.dispose(tester);
    });
  }

  /// 以 [card] 中心为中心，用 Ctrl+滚轮把画布放大。
  Future<void> zoomInOn(WidgetTester tester, TaskCard card) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      mouse.hover(tester.getCenter(cardFinder(card))),
    );
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await harness.settle(tester);
    expect(
      tester.getRect(cardFinder(card)).width,
      greaterThan(TaskCard.defaultWidth),
    );
  }

  testWidgets('画布放大后，碰撞按指针在屏幕上看到的卡片范围判断', (tester) async {
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    await harness.launch(tester);
    // 以 A 为中心放大，A 和 B 都还在屏幕里。
    await zoomInOn(tester, a);
    final target = tester.getRect(cardFinder(b));

    // 刚好在 B 外面：不碰撞。
    var gesture = await dragTo(tester, a, target.topLeft - const Offset(4, 4));
    await tester.pump(CardDragMachine.armDelay);
    expect(cardScale(tester, b), 1);
    await gesture.cancel();
    await harness.settle(tester);

    // 刚好在 B 里面：碰撞。
    gesture = await dragTo(tester, a, target.topLeft + const Offset(4, 4));
    await tester.pump(CardDragMachine.armDelay);
    expect(cardScale(tester, b), 1.05);
    await release(tester, gesture);

    final links = await savedLinks(tester);
    expect(links.map((l) => (l.fromCardId, l.toCardId)), [(a.id, b.id)]);

    await harness.dispose(tester);
  });

  testWidgets('连线保存失败时提示「保存失败，请重试」，被拖卡片仍然回到原处', (tester) async {
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    await harness.launch(tester);
    final before = tester.getRect(cardFinder(a));
    harness.failWrites = true;

    final gesture = await dragTo(tester, a, tester.getCenter(cardFinder(b)));
    await tester.pump(CardDragMachine.armDelay);
    await release(tester, gesture);

    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(await savedLinks(tester), isEmpty);
    expect(tester.getRect(cardFinder(a)), before);

    await harness.dispose(tester);
  });
}
