import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/card_drag.dart';
import 'package:my_personal_use_app/board/completed_page.dart';
import 'package:my_personal_use_app/planner/carry_over_record.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 今天（假时钟一开始的那天）。卡片建在这一天，顺延以后它就是"昨天"。
  late DayKey yesterday;

  /// 在今天的画布上准备一张卡片，还没顺延。
  Future<TaskCard> seedCard(
    WidgetTester tester, {
    String title = '写周报',
    double x = 300,
    double y = 200,
  }) => harness.seed(
    tester,
    (service) => service.createCard(harness.today, title: title, x: x, y: y),
  );

  /// 把时钟拨到第二天并执行每日维护：昨天没完成的卡片顺延到今天，昨天的
  /// 画布上留下历史记录。返回昨天的历史记录。
  Future<List<CarryOverRecord>> carryOverToNextDay(WidgetTester tester) async {
    yesterday = harness.today;
    harness.now = harness.now.add(const Duration(days: 1));
    await harness.seed(tester, (service) => service.runDailyMaintenance());
    return (await harness.readBoard(tester, yesterday)).carryOverRecords;
  }

  Finder recordFinder(CarryOverRecord record) =>
      find.byKey(BoardCanvas.carryOverRecordKey(record.id));

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  Finder handleFinder(TaskCard card) =>
      find.byKey(BoardCanvas.resizeHandleKey(card.id));

  /// 标题栏上显示的日期。
  Finder titleOf(String text) =>
      find.descendant(of: find.byType(AppBar), matching: find.text(text));

  /// 单击历史记录，等过了双击判定时间、跳转和画布内容都完成。
  Future<void> tapRecord(WidgetTester tester, CarryOverRecord record) async {
    await tester.tap(recordFinder(record));
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);
  }

  /// 正在新建的卡片的标题输入框。
  Finder titleField() => find.widgetWithText(TextField, '标题');

  /// 存储里这张卡片现在的样子。
  Future<TaskCard> savedCard(WidgetTester tester, TaskCard card) async =>
      (await harness.readBoard(
        tester,
        (await harness.seed(tester, (s) => s.findCard(card.id))).dayKey,
      )).cards.singleWhere((c) => c.id == card.id);

  /// 把时钟拨回前一天（系统时钟回拨）：昨天又变成了今天，昨天的画布上可以
  /// 新建卡片，历史记录也还在。用它测双击历史记录不会新建卡片。
  void rollBackClock() =>
      harness.now = harness.now.subtract(const Duration(days: 1));

  group('历史记录的显示', () {
    testWidgets('顺延后，前一天的画布在原位置按顺延前的大小显示历史记录：标题快照和「→ 已顺延至 Oct 21」（AC-27）', (
      tester,
    ) async {
      final card = await seedCard(tester);
      await harness.seed(tester, (service) async {
        await service.resizeCard(card.id, width: 220, height: 100);
        await service.setCardColor(card.id, 0xFFB3E5FC);
      });
      final record = (await carryOverToNextDay(tester)).single;
      harness.displayedDay = yesterday;
      await harness.launch(tester);

      // 画布没有平移和缩放时，画布坐标就是可视区域里的坐标。
      final viewport = tester.getTopLeft(find.byType(InteractiveViewer));
      expect(
        tester.getRect(recordFinder(record)),
        Rect.fromLTWH(viewport.dx + 300, viewport.dy + 200, 220, 100),
      );
      expect(
        find.descendant(of: recordFinder(record), matching: find.text('写周报')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: recordFinder(record),
          matching: find.text('→ 已顺延至 Oct 21'),
        ),
        findsOneWidget,
      );
      // 当时的颜色，不透明度 40%。
      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: recordFinder(record),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacity.opacity, 0.4);
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: recordFinder(record),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect((box.decoration as BoxDecoration).color, const Color(0xFFB3E5FC));
      // 历史记录不是卡片：前一天的画布上没有卡片。
      expect(find.byKey(BoardCanvas.cardKey(card.id)), findsNothing);

      await harness.dispose(tester);
    });
  });

  group('单击历史记录', () {
    testWidgets('卡片还在画布上：跳到它现在所在的日期并选中它（AC-29）', (tester) async {
      final card = await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);

      await tapRecord(tester, record);

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);
      expect(recordFinder(record), findsNothing);
      expect(cardFinder(card), findsOneWidget);
      expect(handleFinder(card), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('卡片已完成：跳到它所在的日期并打开那一天的「已完成」列表（AC-29）', (tester) async {
      final card = await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      await harness.seed(tester, (service) => service.completeCard(card.id));
      harness.displayedDay = yesterday;
      await harness.launch(tester);

      await tapRecord(tester, record);

      expect(titleOf('Wed, Oct 21, 2026 · 已完成 1 项'), findsOneWidget);
      expect(find.byKey(CompletedPage.itemKey(card.id)), findsOneWidget);
      await tester.pageBack();
      await harness.settle(tester);
      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);
      expect(cardFinder(card), findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('卡片在回收站里：提示「该任务在回收站中」，不跳转，也不选中（AC-29）', (tester) async {
      final card = await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      await harness.seed(tester, (service) => service.deleteCard(card.id));
      harness.displayedDay = yesterday;
      await harness.launch(tester);

      await tapRecord(tester, record);

      expect(find.text('该任务在回收站中'), findsOneWidget);
      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);
      expect(recordFinder(record), findsOneWidget);
      expect(cardFinder(card), findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('卡片已经不存在：提示「该任务已不存在」，不跳转', (tester) async {
      final card = await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      // 画布显示出来以后，卡片才被永久删除（正常情况下历史记录会一起删掉，
      // 这里画布还没来得及刷新）。
      await harness.seed(tester, (service) async {
        await service.deleteCard(card.id);
        await service.deleteForever(card.id);
      });

      await tapRecord(tester, record);

      expect(find.text('该任务已不存在'), findsOneWidget);
      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('查询卡片现在在哪时读取失败：提示「读取失败，请重试」，不跳转', (tester) async {
      await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      harness.failReads = true;

      await tapRecord(tester, record);

      expect(find.text('读取失败，请重试'), findsOneWidget);
      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);
      expect(recordFinder(record), findsOneWidget);

      harness.failReads = false;
      await harness.dispose(tester);
    });
  });

  group('历史记录只读（AC-28）', () {
    testWidgets('拖着卡片停在历史记录上：没有连线预览；松手是普通移动', (tester) async {
      await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      // 昨天的画布上还有一张有效卡片（每日维护接入 App 之前会有这种情况）。
      final other = await seedCard(tester, title: '回邮件', x: 40, y: 400);
      await harness.moveCardToDay(tester, other.id, yesterday);
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      final target = tester.getCenter(recordFinder(record));

      final gesture = await tester.startGesture(
        tester.getCenter(cardFinder(other)),
      );
      await gesture.moveBy(const Offset(30, 0));
      await gesture.moveTo(target);
      await tester.pump();
      await tester.pump(CardDragMachine.armDelay);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byKey(BoardCanvas.linkPreviewKey), findsNothing);
      expect(find.byKey(BoardCanvas.unlinkPreviewKey), findsNothing);

      await gesture.up();
      await harness.settle(tester);
      expect(tester.getCenter(cardFinder(other)), target);
      expect(recordFinder(record), findsOneWidget);
      expect((await harness.readBoard(tester, yesterday)).links, isEmpty);

      await harness.dispose(tester);
    });

    testWidgets('长按或右键历史记录：不弹菜单，也不跳转', (tester) async {
      await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      harness.displayedDay = yesterday;
      await harness.launch(tester);

      await tester.longPress(recordFinder(record));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      expect(find.text('删除'), findsNothing);
      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);

      await tester.tap(recordFinder(record), buttons: kSecondaryButton);
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      expect(find.text('删除'), findsNothing);
      expect(find.text('断开连线'), findsNothing);
      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('从历史记录上开始拖动：平移画布，不跳转，记录本身不动', (tester) async {
      await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      harness.displayedDay = yesterday;
      await harness.launch(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(recordFinder(record)),
      );
      // 先越过拖动判定的距离，之后的移动才全部用来平移。
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
      final before = tester.getRect(recordFinder(record));
      await gesture.moveBy(const Offset(-100, -50));
      await tester.pump();
      final after = tester.getRect(recordFinder(record));
      await gesture.up();
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expect(after.topLeft - before.topLeft, const Offset(-100, -50));
      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);
      final saved = (await harness.readBoard(
        tester,
        yesterday,
      )).carryOverRecords.single;
      expect((saved.x, saved.y), (record.x, record.y));

      await harness.dispose(tester);
    });

    testWidgets('双击历史记录：和单击一样跳转，不完成卡片，也不新建卡片', (tester) async {
      final card = await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      rollBackClock();
      await harness.launch(tester);
      expect(titleOf('Tue, Oct 20, 2026 · 今天'), findsOneWidget);

      await tester.tap(recordFinder(record));
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(recordFinder(record));
      await harness.settle(tester);

      expect(titleField(), findsNothing);
      expect(titleOf('Wed, Oct 21, 2026'), findsOneWidget);
      expect(handleFinder(card), findsOneWidget);
      expect((await savedCard(tester, card)).status, CardStatus.active);
      expect((await harness.readBoard(tester, yesterday)).cards, isEmpty);

      await harness.dispose(tester);
    });

    testWidgets('双击时第一下点在历史记录上、第二下偏出落在空白处：算双击历史记录，不新建卡片', (tester) async {
      final card = await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      rollBackClock();
      await harness.launch(tester);
      final rect = tester.getRect(recordFinder(record));

      await tester.tapAt(rect.centerRight - const Offset(20, 0));
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(rect.centerRight + const Offset(20, 0));
      await harness.settle(tester);

      expect(titleField(), findsNothing);
      expect((await harness.readBoard(tester, yesterday)).cards, isEmpty);
      expect(titleOf('Wed, Oct 21, 2026'), findsOneWidget);
      expect(handleFinder(card), findsOneWidget);

      await harness.dispose(tester);
    });
  });

  group('点击优先级：✂️ > 卡片 > 历史记录 > 连线 > 空白处', () {
    /// 昨天的画布：历史记录在 (300, 200)，180 × 88；左右两张有效卡片连着，
    /// 连线横穿历史记录。返回记录、两张卡片和连线 ID。
    Future<(CarryOverRecord, TaskCard, TaskCard, String)> seedLinkUnderRecord(
      WidgetTester tester,
    ) async {
      await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      final a = await seedCard(tester, title: 'A', x: 40, y: 200);
      final b = await seedCard(tester, title: 'B', x: 600, y: 200);
      final link = await harness.seed(
        tester,
        (service) => service.toggleLink(a.id, b.id),
      );
      await harness.moveCardToDay(tester, a.id, yesterday);
      await harness.moveCardToDay(tester, b.id, yesterday);
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      return (record, a, b, link.linkId);
    }

    /// 连线在历史记录中间横穿过去的那一点（屏幕坐标）。
    Offset linkOnRecord(WidgetTester tester, CarryOverRecord record) =>
        tester.getCenter(recordFinder(record));

    testWidgets('卡片盖在历史记录上：点重叠处算点卡片，选中它，不跳转', (tester) async {
      await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      final other = await seedCard(tester, title: '回邮件', x: 340, y: 230);
      await harness.moveCardToDay(tester, other.id, yesterday);
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      final overlap = tester
          .getRect(recordFinder(record))
          .intersect(tester.getRect(cardFinder(other)))
          .center;

      await tester.tapAt(overlap);
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);
      expect(handleFinder(other), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('点在历史记录旁边的空白处：不跳转', (tester) async {
      await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      harness.displayedDay = yesterday;
      await harness.launch(tester);

      await tester.tapAt(
        tester.getRect(recordFinder(record)).centerRight + const Offset(20, 0),
      );
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);
      expect(recordFinder(record), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('连线从历史记录下面穿过：点在记录上算点历史记录，跳转，不选中连线', (tester) async {
      final (record, _, _, _) = await seedLinkUnderRecord(tester);

      await tester.tapAt(linkOnRecord(tester, record));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);
      expect(find.byKey(BoardCanvas.linkScissorsKey), findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('选中的连线的 ✂️ 在历史记录上：点 ✂️ 断开连线，不跳转', (tester) async {
      final (record, a, _, linkId) = await seedLinkUnderRecord(tester);
      // 在历史记录外面点连线选中它，✂️ 出现在连线中点，正好在记录上。
      final outside =
          tester.getRect(recordFinder(record)).centerLeft - const Offset(30, 0);
      await tester.tapAt(outside);
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      final scissors = find.byKey(BoardCanvas.linkScissorsKey);
      expect(scissors, findsOneWidget);
      expect(
        tester
            .getRect(recordFinder(record))
            .contains(tester.getCenter(scissors)),
        isTrue,
      );

      await tester.tap(scissors);
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);
      expect(
        (await harness.readBoard(tester, yesterday)).links.map((l) => l.id),
        isNot(contains(linkId)),
      );
      expect(cardFinder(a), findsOneWidget);

      await harness.dispose(tester);
    });
  });

  group('跳转后画布的位置', () {
    /// 画布的可视区域（屏幕坐标），不含标题栏。
    Rect viewport(WidgetTester tester) =>
        tester.getRect(find.byType(InteractiveViewer));

    /// 从空白处 [from] 拖动平移画布，返回画布实际移动了多少。
    Future<Offset> pan(
      WidgetTester tester,
      Offset from,
      Offset by,
      Finder probe,
    ) async {
      final before = tester.getTopLeft(probe);
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(Offset(by.dx.sign * 20, by.dy.sign * 20));
      await gesture.moveBy(by);
      await gesture.up();
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      return tester.getTopLeft(probe) - before;
    }

    testWidgets('卡片跳过去以后已经在可视区域里：平移保持原样', (tester) async {
      final card = await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      final moved = await pan(
        tester,
        viewport(tester).bottomRight - const Offset(100, 100),
        const Offset(40, 30),
        recordFinder(record),
      );

      await tapRecord(tester, record);

      // 顺延过来的卡片在今天画布的 (24, 24)。
      expect(
        tester.getTopLeft(cardFinder(card)),
        viewport(tester).topLeft + const Offset(24, 24) + moved,
      );

      await harness.dispose(tester);
    });

    testWidgets('缩放过的画布：跳过去以后缩放比例不变', (tester) async {
      final card = await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(
        mouse.hover(tester.getCenter(recordFinder(record))),
      );
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 2000)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await harness.settle(tester);
      expect(tester.getRect(recordFinder(record)).width, 90);

      await tapRecord(tester, record);

      final shown = tester.getRect(cardFinder(card));
      expect(shown.size, const Size(90, 44));
      expect(viewport(tester).intersect(shown), shown);

      await harness.dispose(tester);
    });

    testWidgets('卡片跳过去以后在可视区域外：最少地平移画布，让卡片完整出现，缩放不变', (tester) async {
      final card = await seedCard(tester, x: 900, y: 500);
      final record = (await carryOverToNextDay(tester)).single;
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      // 往左上平移，让历史记录露出来；今天画布左上角的卡片就到可视区域外了。
      await pan(
        tester,
        viewport(tester).center,
        const Offset(-400, -300),
        recordFinder(record),
      );
      expect(
        viewport(tester).contains(tester.getCenter(recordFinder(record))),
        isTrue,
      );

      await tapRecord(tester, record);

      final shown = tester.getRect(cardFinder(card));
      expect(shown.size, const Size(180, 88));
      final view = viewport(tester);
      expect(view.intersect(shown), shown);
      // 只平移到刚好露出来（留一点边距），不是把画布整个复位。
      expect(shown.left - view.left, lessThanOrEqualTo(48));
      expect(shown.top - view.top, lessThanOrEqualTo(48));
      expect(shown.left - view.left, greaterThan(0));

      await harness.dispose(tester);
    });

    testWidgets('卡片就在当前显示的这一天、在可视区域外：同样平移到能看见它', (tester) async {
      final card = await seedCard(tester, x: 900, y: 500);
      final record = (await carryOverToNextDay(tester)).single;
      // 正常顺延不会出现这种情况，直接改数据库把卡片放回昨天。
      await harness.moveCardToDay(tester, card.id, yesterday);
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      await pan(
        tester,
        viewport(tester).center,
        const Offset(-400, -300),
        recordFinder(record),
      );
      final view = viewport(tester);
      expect(view.intersect(tester.getRect(cardFinder(card))).isEmpty, isTrue);

      await tapRecord(tester, record);

      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);
      expect(handleFinder(card), findsOneWidget);
      final shown = tester.getRect(cardFinder(card));
      expect(view.intersect(shown), shown);

      await harness.dispose(tester);
    });
  });

  group('切换日期后不留下上一天的状态', () {
    testWidgets('今天选中了连线，切到昨天再切回来：连线不再选中', (tester) async {
      final a = await seedCard(tester, title: 'A', x: 40, y: 60);
      final b = await seedCard(tester, title: 'B', x: 400, y: 60);
      await harness.seed(tester, (service) => service.toggleLink(a.id, b.id));
      await harness.launch(tester);
      // 连线是 (220, 104) 到 (400, 104) 的直线段。
      final viewport = tester.getTopLeft(find.byType(InteractiveViewer));
      await tester.tapAt(viewport + const Offset(310, 104));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      expect(find.byKey(BoardCanvas.linkScissorsKey), findsOneWidget);

      await harness.showDay(tester, harness.today.addDays(-1));
      await harness.settle(tester);
      await harness.showDay(tester, harness.today);
      await harness.settle(tester);

      expect(find.byKey(BoardCanvas.linkScissorsKey), findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('正在编辑昨天的卡片时点历史记录：先保存编辑再跳转；切回昨天时不在编辑', (tester) async {
      final card = await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      final other = await seedCard(tester, title: '回邮件', x: 40, y: 400);
      await harness.moveCardToDay(tester, other.id, yesterday);
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      await tester.tap(cardFinder(other));
      await tester.pump(kDoubleTapTimeout);
      await tester.tap(cardFinder(other));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      await tester.enterText(find.widgetWithText(TextField, '回邮件'), '回邮件给老板');

      await tapRecord(tester, record);

      expect(titleOf('Wed, Oct 21, 2026 · 今天'), findsOneWidget);
      expect(handleFinder(card), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect((await savedCard(tester, other)).title, '回邮件给老板');

      await harness.showDay(tester, yesterday);
      await harness.settle(tester);
      expect(find.byType(TextField), findsNothing);
      expect(handleFinder(other), findsNothing);
      expect(find.text('回邮件给老板'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('正在编辑时点历史记录、保存失败：停在编辑状态，不跳转，提示「保存失败，请重试」', (tester) async {
      await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      final other = await seedCard(tester, title: '回邮件', x: 40, y: 400);
      await harness.moveCardToDay(tester, other.id, yesterday);
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      await tester.tap(cardFinder(other));
      await tester.pump(kDoubleTapTimeout);
      await tester.tap(cardFinder(other));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      await tester.enterText(find.widgetWithText(TextField, '回邮件'), '回邮件给老板');
      harness.failWrites = true;

      await tapRecord(tester, record);

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);
      expect(find.widgetWithText(TextField, '回邮件给老板'), findsOneWidget);

      harness.failWrites = false;
      await harness.dispose(tester);
    });

    testWidgets('正在编辑时点历史记录、卡片在回收站里：保存编辑并退出编辑，不跳转', (tester) async {
      final card = await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      await harness.seed(tester, (service) => service.deleteCard(card.id));
      final other = await seedCard(tester, title: '回邮件', x: 40, y: 400);
      await harness.moveCardToDay(tester, other.id, yesterday);
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      await tester.tap(cardFinder(other));
      await tester.pump(kDoubleTapTimeout);
      await tester.tap(cardFinder(other));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      await tester.enterText(find.widgetWithText(TextField, '回邮件'), '回邮件给老板');

      await tapRecord(tester, record);

      expect(find.text('该任务在回收站中'), findsOneWidget);
      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('回邮件给老板'), findsOneWidget);
      expect((await savedCard(tester, other)).title, '回邮件给老板');

      await harness.dispose(tester);
    });

    testWidgets('正在编辑时点历史记录、卡片在回收站里、保存失败：停在编辑状态，输入的内容还在', (tester) async {
      final card = await seedCard(tester);
      final record = (await carryOverToNextDay(tester)).single;
      await harness.seed(tester, (service) => service.deleteCard(card.id));
      final other = await seedCard(tester, title: '回邮件', x: 40, y: 400);
      await harness.moveCardToDay(tester, other.id, yesterday);
      harness.displayedDay = yesterday;
      await harness.launch(tester);
      await tester.tap(cardFinder(other));
      await tester.pump(kDoubleTapTimeout);
      await tester.tap(cardFinder(other));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      await tester.enterText(find.widgetWithText(TextField, '回邮件'), '回邮件给老板');
      harness.failWrites = true;

      await tapRecord(tester, record);

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(titleOf('Tue, Oct 20, 2026'), findsOneWidget);
      expect(find.widgetWithText(TextField, '回邮件给老板'), findsOneWidget);

      harness.failWrites = false;
      await harness.dispose(tester);
    });
  });

  group('「顺延」标记（AC-47 画布部分）', () {
    Finder tagFinder(TaskCard card) =>
        find.byKey(BoardCanvas.carriedOverTagKey(card.id));

    /// 两个矩形有没有重叠（只碰到边不算）。
    bool overlaps(Rect a, Rect b) =>
        a.intersect(b).width > 0 && a.intersect(b).height > 0;

    testWidgets('顺延过来的卡片右上角显示「顺延」，今天新建的卡片不显示', (tester) async {
      final carried = await seedCard(tester);
      await carryOverToNextDay(tester);
      final fresh = await seedCard(tester, title: '今天的', x: 500, y: 300);
      await harness.launch(tester);

      expect(
        find.descendant(of: tagFinder(carried), matching: find.text('顺延')),
        findsOneWidget,
      );
      final card = tester.getRect(cardFinder(carried));
      final tag = tester.getRect(tagFinder(carried));
      expect(card.intersect(tag), tag);
      expect(card.right - tag.right, lessThanOrEqualTo(16));
      expect(tag.top - card.top, lessThan(16));
      expect(tagFinder(fresh), findsNothing);
      expect(find.text('顺延'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('标记不挡住标题、备注和手柄', (tester) async {
      final card = await seedCard(tester, title: '整理这周所有的会议记录并发给大家');
      await harness.seed(
        tester,
        (service) => service.updateCardContent(
          card.id,
          title: '整理这周所有的会议记录并发给大家',
          note: '先整理周一和周二的那几份会议记录',
        ),
      );
      await carryOverToNextDay(tester);
      await harness.launch(tester);
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      final tag = tester.getRect(tagFinder(card));
      for (final text in ['整理这周所有的会议记录并发给大家', '先整理周一和周二的那几份会议记录']) {
        final shown = tester.getRect(
          find.descendant(of: cardFinder(card), matching: find.text(text)),
        );
        expect(overlaps(tag, shown), isFalse, reason: text);
      }
      expect(overlaps(tag, tester.getRect(handleFinder(card))), isFalse);

      await harness.dispose(tester);
    });

    testWidgets('编辑时标记还在，不挡住输入框', (tester) async {
      final card = await seedCard(tester);
      await carryOverToNextDay(tester);
      await harness.launch(tester);
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      expect(find.byType(TextField), findsWidgets);

      final tag = tester.getRect(tagFinder(card));
      for (final field in find.byType(TextField).evaluate()) {
        expect(
          overlaps(tag, tester.getRect(find.byWidget(field.widget))),
          isFalse,
        );
      }

      await harness.dispose(tester);
    });

    testWidgets('完成后再取消完成：卡片回到画布上，仍然带「顺延」标记', (tester) async {
      final card = await seedCard(tester);
      await carryOverToNextDay(tester);
      await harness.launch(tester);
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(cardFinder(card));
      await harness.settle(tester);
      expect(cardFinder(card), findsNothing);

      await harness.seed(tester, (service) => service.uncompleteCard(card.id));
      // 重新启动 App，读出取消完成以后的画布。
      await tester.pumpWidget(const SizedBox());
      await harness.launch(tester);

      expect(cardFinder(card), findsOneWidget);
      expect(tagFinder(card), findsOneWidget);

      await harness.dispose(tester);
    });
  });
}
