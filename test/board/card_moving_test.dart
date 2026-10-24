import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 在今天的画布上准备一张卡片。
  Future<TaskCard> seedCard(
    WidgetTester tester, {
    String title = '买牛奶',
    double x = 40,
    double y = 60,
  }) => harness.seed(
    tester,
    (service) => service.createCard(harness.today, title: title, x: x, y: y),
  );

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  Finder handleFinder(TaskCard card) =>
      find.byKey(BoardCanvas.resizeHandleKey(card.id));

  Finder titleField() => find.widgetWithText(TextField, '标题');

  /// 单击卡片，等过了双击判定时间，单击才生效。
  Future<void> tapCard(WidgetTester tester, TaskCard card) async {
    await tester.tap(cardFinder(card));
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);
  }

  /// 存储里这张卡片现在的样子。
  Future<TaskCard> savedCard(WidgetTester tester, TaskCard card) async =>
      (await harness.readBoard(
        tester,
        harness.today,
      )).cards.singleWhere((c) => c.id == card.id);

  /// [cards] 在画布上从下到上的顺序（标题）；后画的盖在先画的上面。
  List<String> paintOrder(WidgetTester tester, List<TaskCard> cards) {
    final keys = {for (final c in cards) BoardCanvas.cardKey(c.id): c.title};
    return [
      for (final widget in tester.widgetList(
        find.byWidgetPredicate((w) => keys.containsKey(w.key)),
      ))
        keys[widget.key]!,
    ];
  }

  /// 按住卡片拖动 [offset]（屏幕上的距离）再松手。
  Future<void> dragCard(
    WidgetTester tester,
    TaskCard card,
    Offset offset,
  ) async {
    await tester.drag(cardFinder(card), offset);
    await harness.settle(tester);
  }

  /// 在空白处拖动，把画布平移 [offset]。
  Future<void> panCanvas(WidgetTester tester, Offset offset) async {
    await tester.dragFrom(const Offset(600, 450), offset);
    await harness.settle(tester);
  }

  testWidgets('画布没有边界：卡片可以拖到原点左上方，坐标是负数', (tester) async {
    final card = await seedCard(tester);
    await harness.launch(tester);
    await panCanvas(tester, const Offset(300, 200));
    final before = tester.getRect(cardFinder(card));

    await dragCard(tester, card, const Offset(-200, -150));

    expect(
      tester.getRect(cardFinder(card)),
      rectMoreOrLessEquals(before.shift(const Offset(-200, -150))),
    );
    final saved = await savedCard(tester, card);
    expect(saved.x, moreOrLessEquals(-160));
    expect(saved.y, moreOrLessEquals(-90));
    await harness.dispose(tester);
  });

  testWidgets('坐标是负数的卡片照常能选中、能拖动', (tester) async {
    final card = await seedCard(tester, x: -100, y: -50);
    await harness.launch(tester);
    await panCanvas(tester, const Offset(300, 200));

    await tapCard(tester, card);
    expect(handleFinder(card), findsOneWidget);

    final before = tester.getRect(cardFinder(card));
    await dragCard(tester, card, const Offset(-60, -40));

    expect(
      tester.getRect(cardFinder(card)),
      rectMoreOrLessEquals(before.shift(const Offset(-60, -40))),
    );
    final saved = await savedCard(tester, card);
    expect(saved.x, moreOrLessEquals(-160));
    expect(saved.y, moreOrLessEquals(-90));
    await harness.dispose(tester);
  });

  testWidgets('拖动卡片后它停在松手的位置并保存，画布不平移', (tester) async {
    final card = await seedCard(tester);
    final other = await seedCard(tester, title: '回邮件', x: 400);
    await harness.launch(tester);
    final before = tester.getRect(cardFinder(card));
    final otherBefore = tester.getRect(cardFinder(other));

    await dragCard(tester, card, const Offset(100, 150));

    expect(
      tester.getRect(cardFinder(card)),
      before.shift(const Offset(100, 150)),
    );
    expect(tester.getRect(cardFinder(other)), otherBefore);
    final saved = await savedCard(tester, card);
    expect((saved.x, saved.y), (card.x + 100, card.y + 150));

    await harness.dispose(tester);
  });

  /// 以卡片中心为中心，用 Ctrl+滚轮把画布放大，返回放大后的缩放比例。
  Future<double> zoomInOn(WidgetTester tester, TaskCard card) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      mouse.hover(tester.getCenter(cardFinder(card))),
    );
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await harness.settle(tester);
    final scale =
        tester.getRect(cardFinder(card)).width / TaskCard.defaultWidth;
    expect(scale, greaterThan(1));
    return scale;
  }

  testWidgets('画布放大后拖动卡片，移动距离按缩放比例换算', (tester) async {
    final card = await seedCard(tester);
    await harness.launch(tester);
    final scale = await zoomInOn(tester, card);

    await dragCard(tester, card, Offset(80 * scale, 40 * scale));

    final saved = await savedCard(tester, card);
    expect(saved.x, moreOrLessEquals(card.x + 80));
    expect(saved.y, moreOrLessEquals(card.y + 40));

    await harness.dispose(tester);
  });

  testWidgets('画布放大后慢慢拖，在屏幕上移动超过判定距离就开始拖动', (tester) async {
    final card = await seedCard(tester);
    await harness.launch(tester);
    final scale = await zoomInOn(tester, card);
    final start = tester.getCenter(cardFinder(card));

    // 先在屏幕上刚好移动超过判定距离，过一会儿再接着移动。
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(
      const Offset(kPanSlop + 4, 0),
      timeStamp: const Duration(milliseconds: 100),
    );
    await gesture.moveBy(
      const Offset(60, 0),
      timeStamp: const Duration(milliseconds: 700),
    );
    await gesture.up();
    await harness.settle(tester);

    final saved = await savedCard(tester, card);
    expect(saved.x, moreOrLessEquals(card.x + (kPanSlop + 64) / scale));

    await harness.dispose(tester);
  });

  testWidgets('保存失败时卡片回到拖动前的位置，提示「保存失败，请重试」', (tester) async {
    final card = await seedCard(tester);
    await harness.launch(tester);
    final before = tester.getRect(cardFinder(card));
    harness.failWrites = true;

    await dragCard(tester, card, const Offset(100, 150));

    expect(tester.getRect(cardFinder(card)), before);
    expect(find.text('保存失败，请重试'), findsOneWidget);
    final saved = await savedCard(tester, card);
    expect((saved.x, saved.y), (card.x, card.y));

    await harness.dispose(tester);
  });

  testWidgets('正在拖动的卡片画在所有卡片上面，松手后仍在最上面', (tester) async {
    final card = await seedCard(tester);
    final other = await seedCard(tester, title: '回邮件', x: 100, y: 80);
    await harness.launch(tester);
    expect(paintOrder(tester, [card, other]), ['买牛奶', '回邮件']);

    // 按在没被另一张卡片盖住的左上角。
    final gesture = await tester.startGesture(
      tester.getTopLeft(cardFinder(card)) + const Offset(20, 10),
    );
    await gesture.moveBy(const Offset(30, 30));
    await gesture.moveBy(const Offset(10, 10));
    await tester.pump();

    expect(paintOrder(tester, [card, other]), ['回邮件', '买牛奶']);

    await gesture.up();
    await harness.settle(tester);

    expect(paintOrder(tester, [card, other]), ['回邮件', '买牛奶']);
    final saved = await savedCard(tester, card);
    expect(saved.zIndex, greaterThan(other.zIndex));

    await harness.dispose(tester);
  });

  group('拖动和选中、编辑', () {
    testWidgets('拖动已选中的卡片，仍然选中，手柄跟着卡片走', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);
      final handleBefore = tester.getRect(handleFinder(card));

      await dragCard(tester, card, const Offset(100, 150));

      expect(
        tester.getRect(handleFinder(card)),
        handleBefore.shift(const Offset(100, 150)),
      );

      await harness.dispose(tester);
    });

    testWidgets('拖动未选中的卡片不会选中它，也不取消别的卡片的选中', (tester) async {
      final card = await seedCard(tester);
      final selected = await seedCard(tester, title: '回邮件', x: 400);
      await harness.launch(tester);
      await tapCard(tester, selected);

      await dragCard(tester, card, const Offset(0, 200));

      expect(handleFinder(card), findsNothing);
      expect(handleFinder(selected), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('正在编辑的卡片拖不动', (tester) async {
      final card = await seedCard(tester);
      final other = await seedCard(tester, title: '回邮件', x: 400);
      await harness.launch(tester);
      await tapCard(tester, card);
      await tapCard(tester, card);
      expect(titleField(), findsOneWidget);
      Offset gap() =>
          tester.getTopLeft(cardFinder(card)) -
          tester.getTopLeft(cardFinder(other));
      final gapBefore = gap();

      // 按在卡片边上、编辑框以外的地方拖。
      await tester.dragFrom(
        tester.getTopLeft(cardFinder(card)) + const Offset(4, 4),
        const Offset(100, 150),
      );
      await harness.settle(tester);

      expect(gap(), gapBefore);
      final saved = await savedCard(tester, card);
      expect((saved.x, saved.y), (card.x, card.y));

      await harness.dispose(tester);
    });

    testWidgets('编辑一张卡片时拖动另一张，编辑不受影响', (tester) async {
      final editing = await seedCard(tester);
      final card = await seedCard(tester, title: '回邮件', x: 400);
      await harness.launch(tester);
      await tapCard(tester, editing);
      await tapCard(tester, editing);
      await tester.enterText(titleField(), '买豆浆');

      await dragCard(tester, card, const Offset(0, 200));

      expect(find.widgetWithText(TextField, '买豆浆'), findsOneWidget);
      final moved = await savedCard(tester, card);
      expect((moved.x, moved.y), (card.x, card.y + 200));
      final unsaved = await savedCard(tester, editing);
      expect(unsaved.title, '买牛奶');

      await harness.dispose(tester);
    });
  });

  testWidgets('按住卡片 500ms 不动是长按：弹出菜单，之后移动不拖卡片、不平移画布，松手也不选中', (tester) async {
    final card = await seedCard(tester);
    await harness.launch(tester);
    final before = tester.getRect(cardFinder(card));

    final gesture = await tester.startGesture(
      tester.getCenter(cardFinder(card)),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(50, 50));
    await gesture.moveBy(const Offset(50, 50));
    await gesture.up();
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);

    expect(find.text('改颜色'), findsOneWidget);
    expect(tester.getRect(cardFinder(card)), before);
    expect(handleFinder(card), findsNothing);
    final saved = await savedCard(tester, card);
    expect((saved.x, saved.y), (card.x, card.y));

    await harness.dispose(tester);
  });
}
