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

  /// 画布上一块没有卡片的空白处（屏幕坐标）。
  const blankSpot = Offset(500, 400);

  /// 另一块空白处，用来点空白处退出编辑或取消选中。
  const otherBlankSpot = Offset(700, 500);

  /// 屏幕上的 [point] 在画布上的坐标（画布没有平移和缩放时）。
  Offset toCanvas(WidgetTester tester, Offset point) =>
      point - tester.getTopLeft(find.byType(BoardCanvas));

  /// 双击屏幕上的 [point]。
  Future<void> doubleTapAt(WidgetTester tester, Offset point) async {
    await tester.tapAt(point);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(point);
    await harness.settle(tester);
  }

  /// 单击屏幕上的 [point]，等过了双击判定时间，单击才生效。
  Future<void> tapAt(WidgetTester tester, Offset point) async {
    await tester.tapAt(point);
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);
  }

  Finder titleField() => find.widgetWithText(TextField, '标题');

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

  /// 单击卡片，等过了双击判定时间，单击才生效。
  Future<void> tapCard(WidgetTester tester, TaskCard card) async {
    await tester.tap(cardFinder(card));
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);
  }

  group('新建卡片', () {
    testWidgets('双击空白处在该位置新建卡片，输入标题后点空白处保存', (tester) async {
      await harness.launch(tester);

      await doubleTapAt(tester, blankSpot);
      await tester.enterText(titleField(), '买牛奶');
      await tapAt(tester, otherBlankSpot);

      expect(titleField(), findsNothing);
      expect(find.text('买牛奶'), findsOneWidget);
      final saved = (await harness.readBoard(tester, harness.today)).cards;
      expect(saved, hasLength(1));
      // 卡片的中心在双击的位置。
      final center = toCanvas(tester, blankSpot);
      expect(
        (saved.single.x, saved.single.y),
        (
          center.dx - TaskCard.defaultWidth / 2,
          center.dy - TaskCard.defaultHeight / 2,
        ),
      );
      expect(saved.single.title, '买牛奶');

      await harness.dispose(tester);
    });

    testWidgets('新建后标题为空就点空白处，卡片不保存', (tester) async {
      await harness.launch(tester);

      await doubleTapAt(tester, blankSpot);
      await tester.enterText(titleField(), '   ');
      await tapAt(tester, otherBlankSpot);

      expect(find.byType(TextField), findsNothing);
      final saved = (await harness.readBoard(tester, harness.today)).cards;
      expect(saved, isEmpty);

      await harness.dispose(tester);
    });

    testWidgets('新建时填了备注，标题和备注一起保存', (tester) async {
      await harness.launch(tester);

      await doubleTapAt(tester, blankSpot);
      await tester.enterText(titleField(), '买牛奶');
      await tester.enterText(find.widgetWithText(TextField, '备注'), '全脂的');
      await tapAt(tester, otherBlankSpot);

      expect(find.byType(TextField), findsNothing);
      final saved = (await harness.readBoard(tester, harness.today)).cards;
      expect(saved, hasLength(1));
      expect((saved.single.title, saved.single.note), ('买牛奶', '全脂的'));

      await harness.dispose(tester);
    });

    testWidgets('点「＋」在可视区域中间新建卡片并进入标题编辑', (tester) async {
      await harness.launch(tester);

      await tester.tap(find.byTooltip('新建卡片'));
      await harness.settle(tester);
      await tester.enterText(titleField(), '买牛奶');
      await tapAt(tester, otherBlankSpot);

      final saved = (await harness.readBoard(tester, harness.today)).cards;
      final center = toCanvas(
        tester,
        tester.getCenter(find.byType(BoardCanvas)),
      );
      expect(
        (saved.single.x, saved.single.y),
        (
          center.dx - TaskCard.defaultWidth / 2,
          center.dy - TaskCard.defaultHeight / 2,
        ),
      );
      expect(saved.single.title, '买牛奶');

      await harness.dispose(tester);
    });

    testWidgets('过去的日期上没有「＋」，双击空白处不新建卡片', (tester) async {
      final yesterday = harness.today.addDays(-1);
      harness.displayedDay = yesterday;
      await harness.launch(tester);

      expect(find.text('Mon, Oct 19, 2026'), findsOneWidget);
      expect(find.byTooltip('新建卡片'), findsNothing);
      await doubleTapAt(tester, blankSpot);

      expect(find.byType(TextField), findsNothing);
      final saved = (await harness.readBoard(tester, yesterday)).cards;
      expect(saved, isEmpty);

      await harness.dispose(tester);
    });
  });

  group('选中和编辑', () {
    testWidgets('单击未选中的卡片，过了双击判定时间后选中并显示手柄', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      expect(handleFinder(card), findsNothing);

      await tester.tap(cardFinder(card));
      await tester.pump();
      // 还在双击判定时间里，单击还没生效。
      expect(handleFinder(card), findsNothing);
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expect(handleFinder(card), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('单击空白处取消选中', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);

      await tapAt(tester, blankSpot);

      expect(handleFinder(card), findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('同一时间最多选中一张卡片：单击另一张卡片，选中换到它上面', (tester) async {
      final first = await seedCard(tester);
      final second = await seedCard(tester, title: '交电费', x: 300);
      await harness.launch(tester);
      await tapCard(tester, first);

      await tapCard(tester, second);

      expect(handleFinder(first), findsNothing);
      expect(handleFinder(second), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('单击已选中的卡片进入编辑，改完标题和备注后点空白处保存', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);

      await tapCard(tester, card);
      expect(handleFinder(card), findsNothing);
      await tester.enterText(
        find
            .descendant(of: cardFinder(card), matching: find.byType(TextField))
            .first,
        '买两盒牛奶',
      );
      await tester.enterText(find.widgetWithText(TextField, '备注'), '全脂的');
      await tapAt(tester, blankSpot);

      expect(find.byType(TextField), findsNothing);
      final saved = (await harness.readBoard(
        tester,
        harness.today,
      )).cards.single;
      expect((saved.title, saved.note), ('买两盒牛奶', '全脂的'));
      expect(find.text('买两盒牛奶'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('编辑时把标题清空再点空白处，保留原来的标题', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);
      await tapCard(tester, card);

      await tester.enterText(
        find
            .descendant(of: cardFinder(card), matching: find.byType(TextField))
            .first,
        '',
      );
      await tapAt(tester, blankSpot);

      expect(find.byType(TextField), findsNothing);
      expect(find.text('买牛奶'), findsOneWidget);
      final saved = (await harness.readBoard(
        tester,
        harness.today,
      )).cards.single;
      expect(saved.title, '买牛奶');

      await harness.dispose(tester);
    });

    testWidgets('双击卡片不选中也不进入编辑（双击完成由 #20 接上）', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expect(handleFinder(card), findsNothing);
      expect(find.byType(TextField), findsNothing);

      await harness.dispose(tester);
    });
  });

  group('卡片内容', () {
    /// 卡片上显示的所有文字组件。
    List<Text> textsOn(WidgetTester tester, TaskCard card) => tester
        .widgetList<Text>(
          find.descendant(of: cardFinder(card), matching: find.byType(Text)),
        )
        .toList();

    testWidgets('备注只显示第一个非空行，单行、超出用省略号', (tester) async {
      final card = await seedCard(tester);
      await harness.seed(
        tester,
        (service) => service.updateCardContent(
          card.id,
          title: '买牛奶',
          note: '\n   \n全脂的，两盒\n第三行',
        ),
      );
      await harness.launch(tester);

      final texts = textsOn(tester, card);
      expect(texts.map((t) => t.data), ['买牛奶', '全脂的，两盒']);
      expect(
        (texts.last.maxLines, texts.last.overflow),
        (1, TextOverflow.ellipsis),
      );

      await harness.dispose(tester);
    });

    testWidgets('最小尺寸的卡片上，长标题和备注都放得下，不溢出', (tester) async {
      final card = await seedCard(tester, title: '很长的标题' * 20);
      await harness.seed(tester, (service) async {
        await service.updateCardContent(
          card.id,
          title: '很长的标题' * 20,
          note: '很长的备注' * 20,
        );
        await service.resizeCard(
          card.id,
          width: TaskCard.minWidth,
          height: TaskCard.minHeight,
        );
      });

      await harness.launch(tester);

      expect(tester.takeException(), isNull);
      expect(textsOn(tester, card), hasLength(2));

      await harness.dispose(tester);
    });

    testWidgets('没有备注时只显示标题', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      expect(textsOn(tester, card).map((t) => t.data), ['买牛奶']);

      await harness.dispose(tester);
    });
  });

  group('调整大小', () {
    late TaskCard card;

    /// 准备一张卡片并选中它。
    Future<void> launchWithSelectedCard(WidgetTester tester) async {
      card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);
    }

    /// 按住手柄拖动 [offset]（屏幕上的距离）再松手。
    Future<void> dragHandle(WidgetTester tester, Offset offset) async {
      await tester.drag(handleFinder(card), offset);
      await harness.settle(tester);
    }

    Future<TaskCard> savedCard(WidgetTester tester) async =>
        (await harness.readBoard(tester, harness.today)).cards.single;

    testWidgets('拖动手柄调整卡片大小并保存，卡片位置和画布都不动', (tester) async {
      await launchWithSelectedCard(tester);
      final before = tester.getRect(cardFinder(card));

      await dragHandle(tester, const Offset(100, 50));

      final after = tester.getRect(cardFinder(card));
      expect(after.topLeft, before.topLeft);
      expect(after.size, before.size + const Offset(100, 50));
      final saved = await savedCard(tester);
      expect((saved.x, saved.y), (card.x, card.y));
      expect(
        (saved.width, saved.height),
        (TaskCard.defaultWidth + 100, TaskCard.defaultHeight + 50),
      );

      await harness.dispose(tester);
    });

    testWidgets('最大只能拉到 600×400', (tester) async {
      await launchWithSelectedCard(tester);

      await dragHandle(tester, const Offset(1000, 1000));

      expect(tester.getSize(cardFinder(card)), const Size(600, 400));
      final saved = await savedCard(tester);
      expect((saved.width, saved.height), (600, 400));

      await harness.dispose(tester);
    });

    testWidgets('最小只能缩到 120×60', (tester) async {
      await launchWithSelectedCard(tester);

      await dragHandle(tester, const Offset(-500, -500));

      expect(tester.getSize(cardFinder(card)), const Size(120, 60));
      final saved = await savedCard(tester);
      expect((saved.width, saved.height), (120, 60));

      await harness.dispose(tester);
    });

    testWidgets('画布放大后，拖动距离按缩放比例换算成卡片大小', (tester) async {
      await launchWithSelectedCard(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      // 以卡片中心为中心放大，手柄留在屏幕上。
      await tester.sendEventToBinding(
        mouse.hover(tester.getCenter(cardFinder(card))),
      );
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await harness.settle(tester);
      final scale =
          tester.getRect(cardFinder(card)).width / TaskCard.defaultWidth;
      expect(scale, greaterThan(1));

      await dragHandle(tester, Offset(60 * scale, 30 * scale));

      final saved = await savedCard(tester);
      expect(saved.width, moreOrLessEquals(TaskCard.defaultWidth + 60));
      expect(saved.height, moreOrLessEquals(TaskCard.defaultHeight + 30));

      await harness.dispose(tester);
    });
  });
}
