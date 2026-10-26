import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/planner/card_time.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  /// 在今天的画布上准备一张卡片，带上 [note] 和两个时间。
  Future<TaskCard> seedCard(
    WidgetTester tester, {
    String title = '交作业',
    String? note,
    CardTime? event,
    CardTime? due,
  }) => harness.seed(tester, (service) async {
    final card = await service.createCard(
      harness.today,
      title: title,
      x: 40,
      y: 60,
    );
    await service.updateCardContent(
      card.id,
      title: title,
      note: note,
      times: (event: event, due: due),
    );
    return card;
  });

  /// 卡片上显示的所有文字。
  List<String?> textsOn(WidgetTester tester, TaskCard card) => tester
      .widgetList<Text>(
        find.descendant(of: cardFinder(card), matching: find.byType(Text)),
      )
      .map((t) => t.data)
      .toList();

  group('卡片时间行', () {
    testWidgets('有截止时间时，标题下面只显示截止时间，备注在最后', (tester) async {
      final card = await seedCard(
        tester,
        note: '交到 Brightspace',
        event: CardTime.dateTime(DateTime(2026, 10, 31, 14)),
        due: CardTime.dateTime(DateTime(2026, 10, 30, 23, 59)),
      );
      await harness.launch(tester);

      expect(textsOn(tester, card), [
        '交作业',
        '⏰ 截止 Oct 30 23:59',
        '交到 Brightspace',
      ]);

      await harness.dispose(tester);
    });

    testWidgets('没有截止时间时显示活动时间，只有日期时不显示时刻', (tester) async {
      final card = await seedCard(
        tester,
        event: CardTime.date(DayKey(2026, 10, 31)),
      );
      await harness.launch(tester);

      expect(textsOn(tester, card), ['交作业', '📅 活动 Oct 31']);

      await harness.dispose(tester);
    });

    testWidgets('待确认显示 ⚠', (tester) async {
      final card = await seedCard(tester, due: const CardTime.pending());
      await harness.launch(tester);

      expect(textsOn(tester, card), ['交作业', '⏰ 截止 ⚠ 待确认']);

      await harness.dispose(tester);
    });

    testWidgets('没有时间的卡片只有标题，和以前一样', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      expect(textsOn(tester, card), ['交作业']);

      await harness.dispose(tester);
    });

    testWidgets('最小尺寸的卡片放不下备注时，先不显示备注，标题和时间仍在，不溢出', (tester) async {
      final card = await seedCard(
        tester,
        title: '很长的标题' * 20,
        note: '很长的备注' * 20,
        due: CardTime.dateTime(DateTime(2026, 10, 30, 23, 59)),
      );
      await harness.seed(
        tester,
        (service) => service.resizeCard(
          card.id,
          width: TaskCard.minWidth,
          height: TaskCard.minHeight,
        ),
      );

      await harness.launch(tester);

      expect(tester.takeException(), isNull);
      expect(textsOn(tester, card), ['很长的标题' * 20, '⏰ 截止 Oct 30 23:59']);

      await harness.dispose(tester);
    });
  });

  group('编辑时间', () {
    /// 画布上一块没有卡片的空白处（屏幕坐标）。
    const blankSpot = Offset(700, 500);

    /// 单击屏幕上的 [point]，等过了双击判定时间，单击才生效。
    Future<void> tapAt(WidgetTester tester, Offset point) async {
      await tester.tapAt(point);
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
    }

    /// 单击两次卡片：先选中，再进入编辑。
    Future<void> startEditing(WidgetTester tester, TaskCard card) async {
      for (var i = 0; i < 2; i++) {
        await tester.tap(cardFinder(card));
        await tester.pump(kDoubleTapTimeout);
        await harness.settle(tester);
      }
    }

    Finder dueRow() => find.byKey(BoardCanvas.dueTimeEditorKey);
    Finder eventRow() => find.byKey(BoardCanvas.eventTimeEditorKey);

    /// 点 [row] 里提示为 [tooltip] 的按钮。
    Future<void> tapIn(WidgetTester tester, Finder row, String tooltip) async {
      final button = find.descendant(
        of: row,
        matching: find.byTooltip(tooltip),
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await harness.settle(tester);
    }

    Future<TaskCard> savedCard(WidgetTester tester) async =>
        (await harness.readBoard(tester, harness.today)).cards.single;

    testWidgets('编辑时标题和备注下面有「活动时间」「截止时间」两行', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      await startEditing(tester, card);

      expect(
        find.descendant(of: eventRow(), matching: find.text('活动时间')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dueRow(), matching: find.text('截止时间')),
        findsOneWidget,
      );
      final note = tester.getTopLeft(find.widgetWithText(TextField, '备注'));
      expect(tester.getTopLeft(eventRow()).dy, greaterThan(note.dy));
      expect(
        tester.getTopLeft(dueRow()).dy,
        greaterThan(tester.getTopLeft(eventRow()).dy),
      );

      await harness.dispose(tester);
    });

    testWidgets('选一个日期后保存，卡片上显示截止日期，不显示时刻', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await startEditing(tester, card);

      await tapIn(tester, dueRow(), '选择日期');
      // 日期选择器从卡片所在的那个月开始。
      await tester.tap(find.text('30'));
      await tester.tap(find.text('OK'));
      await harness.settle(tester);
      await tapAt(tester, blankSpot);

      expect(
        (await savedCard(tester)).dueTime,
        CardTime.date(DayKey(2026, 10, 30)),
      );
      expect(find.text('⏰ 截止 Oct 30'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('有日期以后可以加上时刻，截止时间默认 23:59', (tester) async {
      final card = await seedCard(
        tester,
        due: CardTime.date(DayKey(2026, 10, 30)),
      );
      await harness.launch(tester);
      await startEditing(tester, card);

      await tapIn(tester, dueRow(), '选择时刻');
      await tester.tap(find.text('OK'));
      await harness.settle(tester);
      await tapAt(tester, blankSpot);

      expect(
        (await savedCard(tester)).dueTime,
        CardTime.dateTime(DateTime(2026, 10, 30, 23, 59)),
      );
      expect(find.text('⏰ 截止 Oct 30 23:59'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('没有日期时不能选时刻', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      await startEditing(tester, card);

      expect(
        find.descendant(of: dueRow(), matching: find.byTooltip('选择时刻')),
        findsNothing,
      );

      await harness.dispose(tester);
    });

    testWidgets('改日期时保留原来的时刻', (tester) async {
      final card = await seedCard(
        tester,
        event: CardTime.dateTime(DateTime(2026, 10, 31, 14)),
      );
      await harness.launch(tester);
      await startEditing(tester, card);

      await tapIn(tester, eventRow(), '选择日期');
      await tester.tap(find.text('29'));
      await tester.tap(find.text('OK'));
      await harness.settle(tester);
      await tapAt(tester, blankSpot);

      expect(
        (await savedCard(tester)).eventTime,
        CardTime.dateTime(DateTime(2026, 10, 29, 14)),
      );

      await harness.dispose(tester);
    });

    testWidgets('清空后保存，卡片上不再有时间行', (tester) async {
      final card = await seedCard(
        tester,
        event: CardTime.date(DayKey(2026, 10, 31)),
      );
      await harness.launch(tester);
      await startEditing(tester, card);

      await tapIn(tester, eventRow(), '清空');
      await tapAt(tester, blankSpot);

      expect((await savedCard(tester)).eventTime, isNull);
      expect(textsOn(tester, card), ['交作业']);

      await harness.dispose(tester);
    });

    testWidgets('待确认的时间显示 ⚠，选了日期以后就确认了', (tester) async {
      final card = await seedCard(tester, due: const CardTime.pending());
      await harness.launch(tester);
      await startEditing(tester, card);

      expect(
        find.descendant(of: dueRow(), matching: find.text('⚠ 待确认')),
        findsOneWidget,
      );
      await tapIn(tester, dueRow(), '选择日期');
      await tester.tap(find.text('30'));
      await tester.tap(find.text('OK'));
      await harness.settle(tester);
      await tapAt(tester, blankSpot);

      expect(
        (await savedCard(tester)).dueTime,
        CardTime.date(DayKey(2026, 10, 30)),
      );

      await harness.dispose(tester);
    });

    testWidgets('取消日期选择时什么都不改', (tester) async {
      final due = CardTime.date(DayKey(2026, 10, 30));
      final card = await seedCard(tester, due: due);
      await harness.launch(tester);
      await startEditing(tester, card);

      await tapIn(tester, dueRow(), '选择日期');
      await tester.tap(find.text('Cancel'));
      await harness.settle(tester);
      await tapAt(tester, blankSpot);

      expect((await savedCard(tester)).dueTime, due);

      await harness.dispose(tester);
    });

    testWidgets('新建卡片时也可以设截止时间', (tester) async {
      await harness.launch(tester);
      await tester.tapAt(blankSpot);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(blankSpot);
      await harness.settle(tester);

      await tester.enterText(find.widgetWithText(TextField, '标题'), '交表');
      await tapIn(tester, dueRow(), '选择日期');
      await tester.tap(find.text('30'));
      await tester.tap(find.text('OK'));
      await harness.settle(tester);
      await tapAt(tester, const Offset(300, 200));

      final saved = await savedCard(tester);
      expect(saved.title, '交表');
      expect(saved.dueTime, CardTime.date(DayKey(2026, 10, 30)));

      await harness.dispose(tester);
    });
  });
}
