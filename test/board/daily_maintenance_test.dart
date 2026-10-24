import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/board_page.dart';
import 'package:my_personal_use_app/board/trash_page.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

/// 每日维护接入 App 生命周期：冷启动时先维护再显示今天的画布；回到前台时
/// 跨过了午夜就顺延并切到新的今天；一直开在前台时到了午夜也一样。
void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 画布上一块没有卡片的空白处（屏幕坐标）。
  const blankSpot = Offset(500, 400);

  /// 另一块空白处，离新建的草稿够远。
  const otherBlankSpot = Offset(150, 500);

  /// 在今天的画布上准备一张卡片。
  Future<TaskCard> seedCard(
    WidgetTester tester, {
    required String title,
    double x = 300,
    double y = 200,
  }) => harness.seed(
    tester,
    (service) => service.createCard(harness.today, title: title, x: x, y: y),
  );

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  Finder tagFinder(TaskCard card) =>
      find.byKey(BoardCanvas.carriedOverTagKey(card.id));

  /// 标题栏上显示的日期。
  Finder titleOf(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  /// 画布可视区域在屏幕上的位置。
  Rect viewport(WidgetTester tester) =>
      tester.getRect(find.byType(InteractiveViewer));

  /// 假时钟往后拨 [days] 天。
  void advanceDays(int days) =>
      harness.now = harness.now.add(Duration(days: days));

  /// 单击两次卡片进入编辑。
  Future<void> startEditing(WidgetTester tester, TaskCard card) async {
    for (var i = 0; i < 2; i++) {
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
    }
  }

  /// 双击空白处新建一张卡片，输入标题，还没保存。
  Future<void> startDraft(WidgetTester tester, String title) async {
    await tester.tapAt(blankSpot);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(blankSpot);
    await harness.settle(tester);
    await tester.enterText(find.widgetWithText(TextField, '标题'), title);
  }

  /// 关掉 App 再冷启动一次。
  Future<void> restart(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await harness.settle(tester);
    await harness.launch(tester);
  }

  /// 按真实系统的顺序逐个发送生命周期状态。
  void sendLifecycle(WidgetTester tester, List<AppLifecycleState> states) {
    for (final state in states) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
  }

  /// 把 App 切到后台。
  Future<void> sendToBackground(WidgetTester tester) async {
    sendLifecycle(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await tester.pump();
  }

  /// 把 App 切回前台，等每日维护和画布刷新完成。
  Future<void> bringToForeground(WidgetTester tester) async {
    sendLifecycle(tester, [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await harness.settle(tester);
  }

  /// 从假时钟一开始的 9 点到刚过午夜。
  const pastMidnight = Duration(hours: 15, seconds: 1);

  /// App 一直开在前台，时间过去 [duration]：假时钟往后拨，定时器也跟着推进。
  Future<void> letTimePass(WidgetTester tester, Duration duration) async {
    harness.now = harness.now.add(duration);
    await tester.pump(duration);
    await harness.settle(tester);
  }

  group('冷启动', () {
    testWidgets('前一天没完成的卡片出现在今天画布的左上角，带「顺延」标记，今天原有的卡片右移（AC-26）', (
      tester,
    ) async {
      final carried = await seedCard(tester, title: '写周报', x: 300, y: 200);
      advanceDays(1);
      final existing = await seedCard(tester, title: '今天的', x: 40, y: 40);

      await harness.launch(tester);

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);
      expect(
        tester.getTopLeft(cardFinder(carried)),
        viewport(tester).topLeft + const Offset(24, 24),
      );
      expect(
        find.descendant(of: tagFinder(carried), matching: find.text('顺延')),
        findsOneWidget,
      );
      expect(tagFinder(existing), findsNothing);
      expect(
        tester.getTopLeft(cardFinder(existing)).dx,
        greaterThan(tester.getRect(cardFinder(carried)).right),
      );

      await harness.dispose(tester);
    });

    testWidgets('同一天再次启动不会再顺延，也不会产生新的历史记录（AC-31）', (tester) async {
      await seedCard(tester, title: '写周报');
      advanceDays(1);
      await harness.launch(tester);
      // 维护过以后又出现一张前一天没完成的卡片（直接改数据库）。
      final yesterday = harness.today.addDays(-1);
      final missed = await seedCard(tester, title: '后来的', x: 600, y: 400);
      await harness.moveCardToDay(tester, missed.id, yesterday);

      await restart(tester);

      expect(cardFinder(missed), findsNothing);
      final board = await harness.readBoard(tester, yesterday);
      expect(board.cards.map((c) => c.id), [missed.id]);
      expect(board.carryOverRecords, hasLength(1));

      await harness.dispose(tester);
    });
  });

  group('回到前台', () {
    testWidgets('跨过午夜后回到前台：顺延到新的今天，并切到新的今天（AC-46）', (tester) async {
      final carried = await seedCard(tester, title: '写周报', x: 300, y: 200);
      await harness.launch(tester);
      await sendToBackground(tester);

      harness.now = DateTime(2026, 10, 21, 0, 5);
      await bringToForeground(tester);

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);
      expect(
        tester.getTopLeft(cardFinder(carried)),
        viewport(tester).topLeft + const Offset(24, 24),
      );
      expect(
        find.descendant(of: tagFinder(carried), matching: find.text('顺延')),
        findsOneWidget,
      );

      await harness.dispose(tester);
    });

    testWidgets('还是同一天时回到前台：不顺延，画布停在原来的日期（AC-46、AC-31）', (tester) async {
      await harness.launch(tester);
      // 维护过以后又出现一张前一天没完成的卡片（直接改数据库）。
      final yesterday = harness.today.addDays(-1);
      final missed = await seedCard(tester, title: '后来的');
      await harness.moveCardToDay(tester, missed.id, yesterday);
      await sendToBackground(tester);

      harness.now = DateTime(2026, 10, 20, 23, 55);
      await bringToForeground(tester);

      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
      final board = await harness.readBoard(tester, yesterday);
      expect(board.cards.map((c) => c.id), [missed.id]);
      expect(board.carryOverRecords, isEmpty);

      await harness.dispose(tester);
    });

    testWidgets('跨过午夜时正在看别的日期：也切到新的今天', (tester) async {
      harness.displayedDay = DayKey(2026, 12, 1);
      await harness.launch(tester);
      await sendToBackground(tester);

      harness.now = DateTime(2026, 10, 21, 0, 5);
      await bringToForeground(tester);

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('跨过午夜时正在编辑：先保存编辑的内容再顺延，历史记录记下改好的标题', (tester) async {
      final card = await seedCard(tester, title: '买牛奶');
      await harness.launch(tester);
      await startEditing(tester, card);
      await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买牛奶和面包');
      await sendToBackground(tester);

      harness.now = DateTime(2026, 10, 21, 0, 5);
      await bringToForeground(tester);

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);
      expect(find.widgetWithText(TextField, '买牛奶和面包'), findsNothing);
      expect(
        find.descendant(of: cardFinder(card), matching: find.text('买牛奶和面包')),
        findsOneWidget,
      );
      final yesterday = DayKey(2026, 10, 20);
      final record = (await harness.readBoard(
        tester,
        yesterday,
      )).carryOverRecords.single;
      expect(record.titleSnapshot, '买牛奶和面包');

      await harness.dispose(tester);
    });

    testWidgets('跨过午夜时正在新建卡片：草稿保存到新的今天，内容不丢', (tester) async {
      await harness.launch(tester);
      await startDraft(tester, '交房租');
      await sendToBackground(tester);

      harness.now = DateTime(2026, 10, 21, 0, 5);
      await bringToForeground(tester);

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);
      expect(find.widgetWithText(TextField, '交房租'), findsNothing);
      final saved = (await harness.readBoard(tester, harness.today)).cards;
      expect(saved.map((c) => c.title), ['交房租']);
      expect(find.byKey(BoardCanvas.cardKey(saved.single.id)), findsOneWidget);
      expect(find.text('保存失败，请重试'), findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('看着以后的日期新建卡片时跨过午夜：草稿保存在那一天', (tester) async {
      harness.displayedDay = DayKey(2026, 12, 1);
      await harness.launch(tester);
      await startDraft(tester, '交房租');
      await sendToBackground(tester);

      harness.now = DateTime(2026, 10, 21, 0, 5);
      await bringToForeground(tester);

      final saved = await harness.readBoard(tester, DayKey(2026, 12, 1));
      expect(saved.cards.map((c) => c.title), ['交房租']);

      await harness.dispose(tester);
    });

    testWidgets('跨过午夜时新建的草稿保存失败：提示并保留草稿，之后再保存时存到新的今天', (tester) async {
      await harness.launch(tester);
      await startDraft(tester, '交房租');
      harness.failWrites = true;
      await sendToBackground(tester);

      harness.now = DateTime(2026, 10, 21, 0, 5);
      await bringToForeground(tester);

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(find.widgetWithText(TextField, '交房租'), findsOneWidget);

      harness.failWrites = false;
      await tester.tapAt(otherBlankSpot);
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      final saved = await harness.readBoard(tester, DayKey(2026, 10, 21));
      expect(saved.cards.map((c) => c.title), ['交房租']);

      await harness.dispose(tester);
    });

    testWidgets('停在回收站时过了几天再回到前台：「还剩 N 天」按现在的时间更新', (tester) async {
      final card = await seedCard(tester, title: '写周报');
      await harness.seed(tester, (service) => service.deleteCard(card.id));
      await harness.launch(tester);
      await tester.tap(find.byKey(BoardPage.trashButtonKey));
      await harness.settle(tester);
      final item = find.byKey(TrashPage.itemKey(card.id));
      expect(
        find.descendant(of: item, matching: find.textContaining('还剩 10 天')),
        findsOneWidget,
      );
      await sendToBackground(tester);

      advanceDays(3);
      await bringToForeground(tester);

      expect(
        find.descendant(of: item, matching: find.textContaining('还剩 7 天')),
        findsOneWidget,
      );

      await harness.dispose(tester);
    });

    testWidgets('系统时钟被调回前一天后回到前台：画布不跳回过去，原来的日期仍是今天', (tester) async {
      await harness.launch(tester);
      await sendToBackground(tester);

      harness.now = DateTime(2026, 10, 19, 10);
      await bringToForeground(tester);

      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('时钟调回去又调回来：不算跨过午夜，画布停在正在看的日期', (tester) async {
      await harness.launch(tester);
      await sendToBackground(tester);
      harness.now = DateTime(2026, 10, 19, 10);
      await bringToForeground(tester);
      await harness.showDay(tester, DayKey(2026, 12, 1));
      await sendToBackground(tester);

      harness.now = DateTime(2026, 10, 20, 10);
      await bringToForeground(tester);

      expect(titleOf('Tue, Dec 1, 2026'), findsOneWidget);

      await harness.dispose(tester);
    });
  });

  group('前台跨过午夜', () {
    testWidgets('一直开在前台跨过午夜：顺延并切到新的今天', (tester) async {
      final carried = await seedCard(tester, title: '写周报', x: 300, y: 200);
      await harness.launch(tester);

      await letTimePass(tester, pastMidnight);

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);
      expect(
        tester.getTopLeft(cardFinder(carried)),
        viewport(tester).topLeft + const Offset(24, 24),
      );
      expect(
        find.descendant(of: tagFinder(carried), matching: find.text('顺延')),
        findsOneWidget,
      );

      await harness.dispose(tester);
    });

    testWidgets('跨过午夜时正在看别的日期：也切到新的今天', (tester) async {
      harness.displayedDay = DayKey(2026, 12, 1);
      await harness.launch(tester);

      await letTimePass(tester, pastMidnight);

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('跨过午夜时正在编辑：先保存，内容不丢', (tester) async {
      final card = await seedCard(tester, title: '买牛奶');
      await harness.launch(tester);
      await startEditing(tester, card);
      await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买牛奶和面包');

      await letTimePass(tester, pastMidnight);

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);
      expect(
        find.descendant(of: cardFinder(card), matching: find.text('买牛奶和面包')),
        findsOneWidget,
      );
      final record = (await harness.readBoard(
        tester,
        DayKey(2026, 10, 20),
      )).carryOverRecords.single;
      expect(record.titleSnapshot, '买牛奶和面包');

      await harness.dispose(tester);
    });

    testWidgets('跨过午夜时正在新建卡片：草稿保存到新的今天', (tester) async {
      await harness.launch(tester);
      await startDraft(tester, '交房租');

      await letTimePass(tester, pastMidnight);

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);
      final saved = (await harness.readBoard(tester, harness.today)).cards;
      expect(saved.map((c) => c.title), ['交房租']);

      await harness.dispose(tester);
    });

    testWidgets('跨过午夜时保存失败：提示，停在原来的日期，草稿还在', (tester) async {
      await harness.launch(tester);
      await startDraft(tester, '交房租');
      harness.failWrites = true;

      await letTimePass(tester, pastMidnight);

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);
      expect(find.widgetWithText(TextField, '交房租'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('定时器提前触发：不顺延，画布不动，到了午夜再切过去', (tester) async {
      final card = await seedCard(tester, title: '写周报');
      await harness.launch(tester);

      // 定时器到点时时钟还差两秒才到午夜。
      harness.now = DateTime(2026, 10, 20, 23, 59, 58);
      await tester.pump(const Duration(hours: 15));
      await harness.settle(tester);

      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);
      expect(
        (await harness.readBoard(
          tester,
          DayKey(2026, 10, 20),
        )).cards.map((c) => c.id),
        [card.id],
      );

      await letTimePass(tester, const Duration(seconds: 2));

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('时钟被调回前一天：午夜触发时不顺延，画布不跳回过去', (tester) async {
      await harness.launch(tester);

      // 定时器到点时时钟被调回了 10-19。
      harness.now = DateTime(2026, 10, 19, 10);
      await tester.pump(const Duration(hours: 15));
      await harness.settle(tester);

      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);

      // 重新设的定时器之后的午夜照样触发。
      await letTimePass(tester, const Duration(hours: 38));

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('回到前台后按现在的时间重新设定时器，之后的午夜照样触发', (tester) async {
      await harness.launch(tester);
      await sendToBackground(tester);

      // 后台时睡眠了，定时器没有跟着走。
      harness.now = DateTime(2026, 10, 20, 21);
      await bringToForeground(tester);
      await letTimePass(tester, const Duration(hours: 3, seconds: 1));

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('午夜的维护还没做完就回到前台：草稿只保存一次', (tester) async {
      await harness.launch(tester);
      await startDraft(tester, '交房租');

      harness.now = DateTime(2026, 10, 21, 0, 0, 1);
      await tester.pump(pastMidnight);
      await bringToForeground(tester);

      final saved = (await harness.readBoard(tester, harness.today)).cards;
      expect(saved.map((c) => c.title), ['交房租']);

      await harness.dispose(tester);
    });
  });
}
