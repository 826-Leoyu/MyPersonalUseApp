import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

  testWidgets('在另一张卡片上停满 400ms：目标放大、出现虚线预览（AC-13）', (tester) async {
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    await harness.launch(tester);

    final gesture = await dragTo(tester, a, tester.getCenter(cardFinder(b)));
    await tester.pump(CardDragMachine.armDelay);
    await tester.pump(const Duration(milliseconds: 200));

    expect(cardScale(tester, b), 1.05);
    expect(find.byKey(BoardCanvas.linkPreviewKey), findsOneWidget);
    expect(find.byKey(BoardCanvas.unlinkPreviewKey), findsNothing);

    await release(tester, gesture);
    await harness.dispose(tester);
  });

  testWidgets('出现预览后松手：新建连线，被拖卡片回到原处，预览消失（AC-13）', (tester) async {
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    await harness.launch(tester);
    final before = tester.getRect(cardFinder(a));

    final gesture = await dragTo(tester, a, tester.getCenter(cardFinder(b)));
    await tester.pump(CardDragMachine.armDelay);
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

  testWidgets('断开保存失败时提示「保存失败，请重试」，连线还在，被拖卡片仍然回到原处', (tester) async {
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    await harness.seed(tester, (service) => service.toggleLink(a.id, b.id));
    await harness.launch(tester);
    final before = tester.getRect(cardFinder(a));
    harness.failWrites = true;

    final gesture = await dragTo(tester, a, tester.getCenter(cardFinder(b)));
    await tester.pump(CardDragMachine.armDelay);
    expect(find.byKey(BoardCanvas.unlinkPreviewKey), findsOneWidget);
    await release(tester, gesture);

    expect(find.text('保存失败，请重试'), findsOneWidget);
    final links = await savedLinks(tester);
    expect(links.map((l) => (l.fromCardId, l.toCardId)), [(a.id, b.id)]);
    expect(tester.getRect(cardFinder(a)), before);

    await harness.dispose(tester);
  });

  /// 画布放大或缩小到 [scale] 倍，以屏幕上的 [focal] 为中心。
  Future<void> zoomTo(WidgetTester tester, double scale, Offset focal) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(focal));
    // Ctrl+滚轮每滚动 200 逻辑像素缩放 e 倍，见 BoardCanvas。
    await tester.sendEventToBinding(
      mouse.scroll(Offset(0, -200 * math.log(scale))),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await harness.settle(tester);
  }

  /// 屏幕大一些，画布放大到 3 倍时两张卡片都还在屏幕里。
  void useLargeView(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(2400, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final scale in [0.5, 1.0, 3.0]) {
    testWidgets('画布 $scale 倍：armed 后贴着目标边缘内侧慢慢移动，预览一直在，不闪烁', (tester) async {
      useLargeView(tester);
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 300);
      await harness.launch(tester);
      await zoomTo(tester, scale, tester.getCenter(cardFinder(a)));
      final target = tester.getRect(cardFinder(b));
      expect(target.width, moreOrLessEquals(TaskCard.defaultWidth * scale));

      final gesture = await dragTo(tester, a, target.center);
      await tester.pump(CardDragMachine.armDelay);
      expect(cardScale(tester, b), 1.05);

      // 先移到右边缘内侧 1 像素，再沿着右边缘、下边缘内侧每步 1 像素慢慢走。
      final steps = [
        for (var y = target.center.dy; y < target.bottom - 1; y++)
          Offset(target.right - 1, y),
        for (var x = target.right - 1; x > target.left; x--)
          Offset(x, target.bottom - 1),
      ];
      for (final point in steps) {
        await gesture.moveTo(point);
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          find.byKey(BoardCanvas.linkPreviewKey),
          findsOneWidget,
          reason: '指针在 $point',
        );
      }

      await release(tester, gesture);
      expect(await savedLinks(tester), hasLength(1));

      await harness.dispose(tester);
    });

    testWidgets('画布 $scale 倍：目标放大 1.05 倍多出来的一圈不算碰到目标，预览取消', (tester) async {
      useLargeView(tester);
      final a = await seedCard(tester, title: 'A', x: 40);
      final b = await seedCard(tester, title: 'B', x: 300);
      await harness.launch(tester);
      await zoomTo(tester, scale, tester.getCenter(cardFinder(a)));
      final target = tester.getRect(cardFinder(b));

      final gesture = await dragTo(tester, a, target.center);
      await tester.pump(CardDragMachine.armDelay);
      expect(find.byKey(BoardCanvas.linkPreviewKey), findsOneWidget);

      // 放大后的卡片右边缘在 target.right + 宽度 × 0.025，这里在它里面、
      // 在原来的矩形外面。
      await gesture.moveTo(Offset(target.right + 1, target.center.dy));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byKey(BoardCanvas.linkPreviewKey), findsNothing);

      await release(tester, gesture);
      expect(await savedLinks(tester), isEmpty);

      await harness.dispose(tester);
    });
  }

  testWidgets('Android 上连线保存成功才振动，保存失败不振动', (tester) async {
    final vibrations = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          vibrations.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    final c = await seedCard(tester, title: 'C', x: 40, y: 300);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await harness.launch(tester);

    var gesture = await dragTo(tester, a, tester.getCenter(cardFinder(b)));
    await tester.pump(CardDragMachine.armDelay);
    await release(tester, gesture);
    expect(vibrations, ['HapticFeedbackType.lightImpact']);

    harness.failWrites = true;
    gesture = await dragTo(tester, c, tester.getCenter(cardFinder(b)));
    await tester.pump(CardDragMachine.armDelay);
    await release(tester, gesture);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(vibrations, hasLength(1));

    await harness.dispose(tester);
    debugDefaultTargetPlatformOverride = null;
  });
}
