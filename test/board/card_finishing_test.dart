import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

  /// 存储里这张卡片现在在哪一天、什么状态、在不在回收站。
  Future<CardLocation> locate(WidgetTester tester, TaskCard card) =>
      harness.seed(tester, (service) => service.findCard(card.id));

  /// 画布上一块没有卡片的空白处（屏幕坐标）。
  const blankSpot = Offset(500, 400);

  Finder titleField() => find.widgetWithText(TextField, '标题');

  /// 单击卡片，等过了双击判定时间，单击才生效。
  Future<void> tapCard(WidgetTester tester, TaskCard card) async {
    await tester.tap(cardFinder(card));
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);
  }

  /// 双击卡片，等动画和保存都结束。
  Future<void> doubleTapCard(WidgetTester tester, TaskCard card) async {
    await tester.tap(cardFinder(card));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(cardFinder(card));
    await harness.settle(tester);
  }

  group('双击完成', () {
    testWidgets('双击卡片：卡片从画布消失，标记为完成', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      await doubleTapCard(tester, card);

      expect(cardFinder(card), findsNothing);
      expect((await locate(tester, card)).status, CardStatus.completed);

      await harness.dispose(tester);
    });

    testWidgets('双击后卡片先打勾，动画结束就从画布消失，不等保存完成', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(cardFinder(card));
      await tester.pump();
      await tester.pump(BoardCanvas.completeDuration ~/ 2);

      expect(
        find.descendant(
          of: cardFinder(card),
          matching: find.byKey(BoardCanvas.completeCheckKey),
        ),
        findsOneWidget,
      );

      // 只推进动画的时间，不让数据库读写跑。
      await tester.pump(BoardCanvas.completeDuration);
      expect(cardFinder(card), findsNothing);

      await harness.settle(tester);
      expect(cardFinder(card), findsNothing);
      expect((await locate(tester, card)).status, CardStatus.completed);

      await harness.dispose(tester);
    });

    testWidgets('完成保存失败：卡片回到画布上原来的位置，提示「保存失败，请重试」', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      final before = tester.getRect(cardFinder(card));
      harness.failWrites = true;

      await doubleTapCard(tester, card);

      expect(tester.getRect(cardFinder(card)), before);
      expect(find.byKey(BoardCanvas.completeCheckKey), findsNothing);
      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect((await locate(tester, card)).status, CardStatus.active);

      await harness.dispose(tester);
    });

    testWidgets('正在编辑的卡片：在编辑框里双击不完成，仍在编辑', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);
      await tapCard(tester, card);
      expect(titleField(), findsOneWidget);

      await tester.tap(titleField());
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(titleField());
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expect(titleField(), findsOneWidget);
      expect(cardFinder(card), findsOneWidget);
      expect((await locate(tester, card)).status, CardStatus.active);

      await harness.dispose(tester);
    });

    testWidgets('新建还没保存的卡片：双击它不完成，也不新建另一张', (tester) async {
      await harness.launch(tester);
      await tester.tapAt(blankSpot);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(blankSpot);
      await harness.settle(tester);
      await tester.enterText(titleField(), '买牛奶');

      await tester.tap(titleField());
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(titleField());
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expect(titleField(), findsOneWidget);
      expect(find.text('买牛奶'), findsOneWidget);
      expect((await harness.readBoard(tester, harness.today)).cards, isEmpty);

      await harness.dispose(tester);
    });

    testWidgets('第一下点卡片、第二下偏出卡片落在旁边的空白处：算双击卡片，完成它，不新建卡片（#50）', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      final rect = tester.getRect(cardFinder(card));

      // 第二下在卡片右边一点的空白处，和第一下离得够近，能凑成双击。
      await tester.tapAt(rect.centerRight - const Offset(20, 0));
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(rect.centerRight + const Offset(20, 0));
      await harness.settle(tester);

      expect(titleField(), findsNothing);
      expect(cardFinder(card), findsNothing);
      expect((await locate(tester, card)).status, CardStatus.completed);
      expect((await harness.readBoard(tester, harness.today)).cards, isEmpty);

      await harness.dispose(tester);
    });
  });
}
