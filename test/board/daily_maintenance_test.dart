import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

/// 每日维护接入 App 生命周期：冷启动时先维护再显示今天的画布；回到前台时
/// 跨过了午夜就顺延并切到新的今天。
void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

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
  });
}
