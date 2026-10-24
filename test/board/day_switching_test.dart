import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/planner_exceptions.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

/// 切换日期的统一入口：先处理正在编辑的内容，保存成功才切换。日期抽屉
/// 和点历史记录跳转都走这个入口。
void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 画布上一块没有卡片的空白处（屏幕坐标）。
  const blankSpot = Offset(500, 400);

  /// 在今天的画布上准备一张卡片。
  Future<TaskCard> seedCard(WidgetTester tester, {String title = '买牛奶'}) =>
      harness.seed(
        tester,
        (service) =>
            service.createCard(harness.today, title: title, x: 40, y: 60),
      );

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  /// 标题栏上显示的日期。
  Finder titleOf(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  /// 单击两次卡片进入编辑。
  Future<void> startEditing(WidgetTester tester, TaskCard card) async {
    for (var i = 0; i < 2; i++) {
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
    }
  }

  testWidgets('正在编辑卡片时切换日期：先保存编辑的内容，再切换', (tester) async {
    final card = await seedCard(tester);
    await harness.launch(tester);
    await startEditing(tester, card);
    await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买牛奶和面包');

    await harness.showDay(tester, harness.today.addDays(-1));
    await harness.settle(tester);

    expect(titleOf('Mon, Oct 19, 2026'), findsOneWidget);
    final saved = (await harness.readBoard(tester, harness.today)).cards;
    expect(saved.single.title, '买牛奶和面包');

    await harness.dispose(tester);
  });

  testWidgets('保存失败：不切换，停在编辑状态，输入的内容还在', (tester) async {
    final card = await seedCard(tester);
    await harness.launch(tester);
    await startEditing(tester, card);
    await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买牛奶和面包');
    harness.failWrites = true;

    await expectLater(
      harness.showDay(tester, harness.today.addDays(-1)),
      throwsA(isA<StorageFailure>()),
    );
    await harness.settle(tester);

    expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
    expect(find.widgetWithText(TextField, '买牛奶和面包'), findsOneWidget);

    harness.failWrites = false;
    await harness.dispose(tester);
  });

  testWidgets('标题为空的新卡片草稿：丢弃，照常切换', (tester) async {
    await harness.launch(tester);
    await tester.tapAt(blankSpot);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(blankSpot);
    await harness.settle(tester);
    expect(find.widgetWithText(TextField, '标题'), findsOneWidget);

    await harness.showDay(tester, harness.today.addDays(-1));
    await harness.settle(tester);

    expect(titleOf('Mon, Oct 19, 2026'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect((await harness.readBoard(tester, harness.today)).cards, isEmpty);

    await harness.dispose(tester);
  });

  testWidgets('已有的卡片标题被清空：保留原来的内容，照常切换', (tester) async {
    final card = await seedCard(tester);
    await harness.launch(tester);
    await startEditing(tester, card);
    await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '  ');

    await harness.showDay(tester, harness.today.addDays(-1));
    await harness.settle(tester);

    expect(titleOf('Mon, Oct 19, 2026'), findsOneWidget);
    final saved = (await harness.readBoard(tester, harness.today)).cards;
    expect(saved.single.title, '买牛奶');

    await harness.dispose(tester);
  });

  testWidgets('点历史记录正在查卡片时又切换到另一天：按先后顺序完成，最后停在后切的那天', (tester) async {
    final card = await seedCard(tester);
    harness.displayedDay = harness.today.addDays(-1);
    await harness.launch(tester);
    final selection = harness.selection(tester);

    final jumping = selection.openCarryOverRecord(card.id);
    await harness.showDay(tester, harness.today.addDays(-2));
    await jumping;
    await harness.settle(tester);

    expect(titleOf('Sun, Oct 18, 2026'), findsOneWidget);

    await harness.dispose(tester);
  });

  testWidgets('正在编辑时连续切换两次日期：内容保存好，最后停在后切的那天', (tester) async {
    final card = await seedCard(tester);
    await harness.launch(tester);
    await startEditing(tester, card);
    await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买牛奶和面包');
    final selection = harness.selection(tester);

    var done = 0;
    for (final offset in [-1, -2]) {
      selection
          .showDay(harness.today.addDays(offset))
          .whenComplete(() => done++);
    }
    await harness.pumpData(tester, rounds: 20, until: () => done == 2);
    await harness.settle(tester);

    expect(done, 2);
    expect(titleOf('Sun, Oct 18, 2026'), findsOneWidget);
    final saved = (await harness.readBoard(tester, harness.today)).cards;
    expect(saved.single.title, '买牛奶和面包');

    await harness.dispose(tester);
  });

  testWidgets('正在编辑时「今天」变了：显示的日期不被重置，编辑的内容还在', (tester) async {
    final card = await seedCard(tester);
    await harness.launch(tester);
    await startEditing(tester, card);
    await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买牛奶和面包');

    await harness.changeNow(tester, DateTime(2026, 10, 21, 0, 5));

    expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);
    expect(find.widgetWithText(TextField, '买牛奶和面包'), findsOneWidget);

    await harness.dispose(tester);
  });

  testWidgets('看着别的日期时「今天」变了：仍然停在选的那天', (tester) async {
    await harness.launch(tester);
    await harness.showDay(tester, DayKey(2026, 12, 1));

    await harness.changeNow(tester, DateTime(2026, 10, 21, 0, 5));

    expect(titleOf('Tue, Dec 1, 2026'), findsOneWidget);

    await harness.dispose(tester);
  });
}
