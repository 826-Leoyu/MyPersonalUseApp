import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/board_page.dart';
import 'package:my_personal_use_app/board/link_layer.dart';
import 'package:my_personal_use_app/board/trash_page.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/planner_exceptions.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 在 [day]（默认今天）准备一张卡片，在 [at]（默认现在）这个时间把它删除。
  Future<TaskCard> seedTrashed(
    WidgetTester tester, {
    String title = '买牛奶',
    DayKey? day,
    DateTime? at,
  }) async {
    final card = await harness.seed(
      tester,
      (service) =>
          service.createCard(day ?? harness.today, title: title, x: 40, y: 60),
    );
    final now = harness.now;
    harness.now = at ?? now;
    await harness.seed(tester, (service) => service.deleteCard(card.id));
    harness.now = now;
    return card;
  }

  /// 点画布标题栏上的「回收站」。
  Future<void> openTrash(WidgetTester tester) async {
    await tester.tap(find.byKey(BoardPage.trashButtonKey));
    await harness.settle(tester);
  }

  Finder itemFinder(TaskCard card) => find.byKey(TrashPage.itemKey(card.id));

  Finder inItem(TaskCard card, String text) => find.descendant(
    of: itemFinder(card),
    matching: find.textContaining(text),
  );

  /// 列表里这一项上的按钮。
  Finder itemButton(TaskCard card, String tooltip) =>
      find.descendant(of: itemFinder(card), matching: find.byTooltip(tooltip));

  /// 点列表里这一项的「恢复」。
  Future<void> restore(WidgetTester tester, TaskCard card) async {
    await tester.tap(itemButton(card, '恢复'));
    await harness.settle(tester);
  }

  /// 卡片还在不在数据库里（回收站里的也算）。
  Future<bool> exists(WidgetTester tester, TaskCard card) =>
      harness.seed(tester, (service) async {
        try {
          await service.findCard(card.id);
          return true;
        } on NotFound {
          return false;
        }
      });

  Finder dialogButton(String label) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(TextButton, label),
  );

  /// 从回收站回到画布。
  Future<void> backToBoard(WidgetTester tester) async {
    await tester.pageBack();
    await harness.settle(tester);
  }

  /// 连线层现在画着的连线 ID。
  List<String> shownLinkIds(WidgetTester tester) {
    final layer = tester.widget<CustomPaint>(find.byKey(LinkLayer.paintKey));
    return [for (final link in (layer.painter! as LinkPainter).links) link.id];
  }

  group('回收站', () {
    testWidgets('每项显示原日期（完整格式）和「还剩 N 天」，按删除时间倒序，不显示「顺延」（AC-23）', (
      tester,
    ) async {
      final older = await seedTrashed(
        tester,
        title: '买牛奶',
        at: DateTime(2026, 10, 20, 9),
      );
      final newer = await seedTrashed(
        tester,
        title: '写周报',
        day: DayKey(2026, 10, 22),
        at: DateTime(2026, 10, 22, 9),
      );
      // 顺延过的卡片：10-20 → 10-21，然后删除。
      harness.now = DateTime(2026, 10, 21, 8);
      final carried = await harness.seed(
        tester,
        (service) => service.createCard(
          DayKey(2026, 10, 21),
          title: '交房租',
          x: 40,
          y: 60,
        ),
      );
      harness.now = DateTime(2026, 10, 22, 8);
      await harness.seed(tester, (service) => service.runDailyMaintenance());
      await harness.seed(tester, (service) => service.deleteCard(carried.id));
      // 买牛奶删了 3 天 1 小时：还剩 6 天 23 小时，向上取整是 7 天。
      harness.now = DateTime(2026, 10, 23, 10);
      await harness.launch(tester);

      await openTrash(tester);

      expect(inItem(older, '买牛奶'), findsOneWidget);
      expect(inItem(older, 'Tue, Oct 20, 2026'), findsOneWidget);
      expect(inItem(older, '还剩 7 天'), findsOneWidget);
      expect(inItem(newer, 'Thu, Oct 22, 2026'), findsOneWidget);
      expect(inItem(newer, '还剩 9 天'), findsOneWidget);
      expect(inItem(carried, 'Thu, Oct 22, 2026'), findsOneWidget);
      expect(inItem(carried, '顺延'), findsNothing);
      expect(
        tester.getTopLeft(itemFinder(newer)).dy,
        lessThan(tester.getTopLeft(itemFinder(older)).dy),
      );

      await harness.dispose(tester);
    });

    testWidgets('恢复：从列表消失，卡片回到原日期和位置，连线也回来（AC-24）', (tester) async {
      final a = await harness.seed(
        tester,
        (service) =>
            service.createCard(harness.today, title: 'A', x: 40, y: 60),
      );
      final b = await harness.seed(
        tester,
        (service) =>
            service.createCard(harness.today, title: 'B', x: 400, y: 60),
      );
      final linkId = await harness.seed(
        tester,
        (service) async => (await service.toggleLink(a.id, b.id)).linkId,
      );
      await harness.seed(tester, (service) => service.deleteCard(a.id));
      await harness.launch(tester);
      expect(shownLinkIds(tester), isEmpty);
      await openTrash(tester);

      await restore(tester, a);

      expect(itemFinder(a), findsNothing);
      final restored = (await harness.readBoard(
        tester,
        harness.today,
      )).cards.singleWhere((c) => c.id == a.id);
      expect((restored.x, restored.y), (40.0, 60.0));
      await backToBoard(tester);
      expect(find.byKey(BoardCanvas.cardKey(a.id)), findsOneWidget);
      expect(shownLinkIds(tester), [linkId]);

      await harness.dispose(tester);
    });

    testWidgets('恢复原日期已经过去的卡片：顺延到今天并提示（AC-24）', (tester) async {
      final yesterday = harness.today;
      final card = await seedTrashed(tester, title: '写周报');
      harness.now = DateTime(2026, 10, 21, 9);
      await harness.launch(tester);
      await openTrash(tester);

      await restore(tester, card);

      expect(itemFinder(card), findsNothing);
      expect(find.text('已恢复至今天（Oct 21）'), findsOneWidget);
      expect(
        (await harness.readBoard(tester, harness.today)).cards.map((c) => c.id),
        [card.id],
      );
      expect(
        (await harness.readBoard(tester, yesterday)).carryOverRecords,
        hasLength(1),
      );

      await harness.dispose(tester);
    });

    testWidgets('恢复保存失败：仍在列表里，提示「恢复失败，请重试」', (tester) async {
      final card = await seedTrashed(tester);
      await harness.launch(tester);
      await openTrash(tester);
      harness.failWrites = true;

      await restore(tester, card);

      expect(itemFinder(card), findsOneWidget);
      expect(find.text('恢复失败，请重试'), findsOneWidget);

      harness.failWrites = false;
      await harness.dispose(tester);
    });

    testWidgets('永久删除先弹确认框：取消时还在，确认后从列表消失、卡片不复存在（AC-25）', (tester) async {
      final card = await seedTrashed(tester, title: '写周报');
      final other = await seedTrashed(tester, title: '买牛奶');
      await harness.launch(tester);
      await openTrash(tester);

      await tester.tap(itemButton(card, '永久删除'));
      await harness.settle(tester);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('写周报'),
        ),
        findsOneWidget,
      );
      await tester.tap(dialogButton('取消'));
      await harness.settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(itemFinder(card), findsOneWidget);
      expect(await exists(tester, card), isTrue);

      await tester.tap(itemButton(card, '永久删除'));
      await harness.settle(tester);
      await tester.tap(dialogButton('永久删除'));
      await harness.settle(tester);

      expect(itemFinder(card), findsNothing);
      expect(await exists(tester, card), isFalse);
      expect(itemFinder(other), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('清空回收站先弹确认框：取消时都还在，确认后全部永久删除（AC-25）', (tester) async {
      final a = await seedTrashed(tester, title: '写周报');
      final b = await seedTrashed(tester, title: '买牛奶');
      await harness.launch(tester);
      await openTrash(tester);

      await tester.tap(find.widgetWithText(TextButton, '清空'));
      await harness.settle(tester);
      await tester.tap(dialogButton('取消'));
      await harness.settle(tester);

      expect(itemFinder(a), findsOneWidget);
      expect(itemFinder(b), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, '清空'));
      await harness.settle(tester);
      await tester.tap(dialogButton('清空'));
      await harness.settle(tester);

      expect(itemFinder(a), findsNothing);
      expect(itemFinder(b), findsNothing);
      expect(await exists(tester, a), isFalse);
      expect(await exists(tester, b), isFalse);
      expect(find.text('回收站是空的'), findsOneWidget);
      final clear = tester.widget<TextButton>(
        find.widgetWithText(TextButton, '清空'),
      );
      expect(clear.onPressed, isNull);

      await harness.dispose(tester);
    });

    testWidgets('永久删除保存失败：仍在列表里，提示「保存失败，请重试」', (tester) async {
      final card = await seedTrashed(tester);
      await harness.launch(tester);
      await openTrash(tester);
      harness.failWrites = true;

      await tester.tap(itemButton(card, '永久删除'));
      await harness.settle(tester);
      await tester.tap(dialogButton('永久删除'));
      await harness.settle(tester);

      expect(itemFinder(card), findsOneWidget);
      expect(find.text('保存失败，请重试'), findsOneWidget);

      harness.failWrites = false;
      await harness.dispose(tester);
    });

    testWidgets('正在编辑卡片时打开回收站：先保存输入的内容', (tester) async {
      final card = await harness.seed(
        tester,
        (service) =>
            service.createCard(harness.today, title: '买牛奶', x: 40, y: 60),
      );
      await harness.launch(tester);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byKey(BoardCanvas.cardKey(card.id)));
        await tester.pump(kDoubleTapTimeout);
        await harness.settle(tester);
      }
      await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买牛奶和面包');

      await openTrash(tester);

      expect(find.byType(TrashPage), findsOneWidget);
      final saved = (await harness.readBoard(tester, harness.today)).cards;
      expect(saved.single.title, '买牛奶和面包');

      await harness.dispose(tester);
    });

    testWidgets('读不出回收站：提示「读取失败，请重试」，点「重试」重新读取', (tester) async {
      final card = await seedTrashed(tester);
      await harness.launch(tester);
      harness.failReads = true;

      await openTrash(tester);

      expect(find.text('读取失败，请重试'), findsOneWidget);
      expect(itemFinder(card), findsNothing);

      harness.failReads = false;
      await tester.tap(find.text('重试'));
      await harness.settle(tester);

      expect(itemFinder(card), findsOneWidget);

      await harness.dispose(tester);
    });
  });
}
