import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/card_drag.dart';
import 'package:my_personal_use_app/board/drop_zones.dart';
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

  /// 正在新建、还没保存的卡片。
  Finder draftFinder() =>
      find.ancestor(of: titleField(), matching: find.byType(Positioned)).first;

  /// 画布的可视区域，不含标题栏。
  Finder viewport() => find.byType(InteractiveViewer);

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

    testWidgets('过去的日期上第一下点卡片、第二下偏出：同样完成这张卡片（#50）', (tester) async {
      final card = await seedCard(tester);
      // 今天已经维护过：之后才放到过去日期的卡片，启动时不会被顺延走。
      await harness.seed(tester, (service) => service.runDailyMaintenance());
      await harness.moveCardToDay(tester, card.id, harness.today.addDays(-1));
      harness.displayedDay = harness.today.addDays(-1);
      await harness.launch(tester);
      final rect = tester.getRect(cardFinder(card));

      await tester.tapAt(rect.centerRight - const Offset(20, 0));
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(rect.centerRight + const Offset(20, 0));
      await harness.settle(tester);

      expect(cardFinder(card), findsNothing);
      expect((await locate(tester, card)).status, CardStatus.completed);

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

    testWidgets('新建还没保存的卡片：第一下点它、第二下偏出落在旁边的空白处，不新建另一张，输入的内容不丢', (tester) async {
      await harness.launch(tester);
      await tester.tapAt(blankSpot);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(blankSpot);
      await harness.settle(tester);
      await tester.enterText(titleField(), '买牛奶');
      final draft = tester.getRect(draftFinder());

      await tester.tapAt(draft.centerRight - const Offset(20, 0));
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(draft.centerRight + const Offset(20, 0));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expect(titleField(), findsOneWidget);
      expect(find.text('买牛奶'), findsOneWidget);
      expect(tester.getRect(draftFinder()), draft);
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

    testWidgets('选中的卡片：第一下点手柄、第二下偏出落在旁边的空白处：算双击卡片，完成它，不新建卡片（#50）', (
      tester,
    ) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);
      final handle = tester.getCenter(
        find.byKey(BoardCanvas.resizeHandleKey(card.id)),
      );

      await tester.tapAt(handle);
      await tester.pump(kDoubleTapMinTime);
      await tester.tapAt(handle + const Offset(30, 30));
      await harness.settle(tester);

      expect(titleField(), findsNothing);
      expect(cardFinder(card), findsNothing);
      expect((await locate(tester, card)).status, CardStatus.completed);
      expect((await harness.readBoard(tester, harness.today)).cards, isEmpty);

      await harness.dispose(tester);
    });
  });

  Finder zoneFinder(DropZone zone) => find.byKey(DropZoneBar.zoneKey(zone));

  Finder addButton() => find.byTooltip('新建卡片');

  /// 按住卡片往上拖一点，开始拖动，还不松手。
  Future<TestGesture> startDragging(WidgetTester tester, TaskCard card) async {
    final gesture = await tester.startGesture(
      tester.getCenter(cardFinder(card)),
    );
    await gesture.moveBy(const Offset(0, -30));
    await gesture.moveBy(const Offset(0, -10));
    await tester.pump();
    return gesture;
  }

  /// 把卡片拖进投放区 [zone] 松手，等保存和动画都结束。
  Future<void> dropInto(
    WidgetTester tester,
    TaskCard card,
    DropZone zone,
  ) async {
    final gesture = await startDragging(tester, card);
    await gesture.moveTo(tester.getCenter(zoneFinder(zone)));
    await tester.pump();
    await gesture.up();
    await harness.settle(tester);
  }

  /// 以卡片中心为中心，用 Ctrl+滚轮把画布缩放到上限或下限 [scale]
  /// （[BoardCanvas.minScale] 或 [BoardCanvas.maxScale]）。
  Future<void> zoomTo(WidgetTester tester, TaskCard card, double scale) async {
    if (scale == 1) return;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      mouse.hover(tester.getCenter(cardFinder(card))),
    );
    await tester.sendEventToBinding(
      mouse.scroll(Offset(0, scale > 1 ? -2000 : 2000)),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await harness.settle(tester);
    expect(
      tester.getRect(cardFinder(card)).width,
      moreOrLessEquals(TaskCard.defaultWidth * scale),
    );
  }

  group('底部投放区', () {
    for (final scale in [BoardCanvas.minScale, 1.0, BoardCanvas.maxScale]) {
      testWidgets('画布缩放 $scale 倍时拖进 ✅ 区松手：卡片从画布消失，标记为完成', (tester) async {
        final card = await seedCard(tester);
        await harness.launch(tester);
        await zoomTo(tester, card, scale);

        await dropInto(tester, card, DropZone.complete);

        expect(cardFinder(card), findsNothing);
        expect((await locate(tester, card)).status, CardStatus.completed);

        await harness.dispose(tester);
      });
    }

    testWidgets('拖动卡片时底部出现 ✅ 和 🗑️ 区，「＋」隐藏；松手后恢复', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      expect(zoneFinder(DropZone.complete), findsNothing);
      expect(zoneFinder(DropZone.trash), findsNothing);
      expect(addButton(), findsOneWidget);

      final gesture = await startDragging(tester, card);
      // 「＋」由 Scaffold 缩小隐藏，等它的动画播完。
      await tester.pump(const Duration(milliseconds: 300));

      expect(zoneFinder(DropZone.complete), findsOneWidget);
      expect(zoneFinder(DropZone.trash), findsOneWidget);
      expect(addButton(), findsNothing);
      final canvas = tester.getRect(viewport());
      expect(
        tester.getRect(zoneFinder(DropZone.complete)).bottom,
        lessThanOrEqualTo(canvas.bottom),
      );
      expect(
        tester.getRect(zoneFinder(DropZone.complete)).bottom,
        greaterThan(canvas.center.dy),
      );

      await gesture.up();
      await harness.settle(tester);
      expect(zoneFinder(DropZone.complete), findsNothing);
      expect(addButton(), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('已经准备连线时拖进 ✅ 区：连线预览消失；松手完成卡片，不连线', (tester) async {
      final card = await seedCard(tester);
      final other = await seedCard(tester, title: '回邮件', x: 400);
      await harness.launch(tester);

      final gesture = await startDragging(tester, card);
      await gesture.moveTo(tester.getCenter(cardFinder(other)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(find.byKey(BoardCanvas.linkPreviewKey), findsOneWidget);

      await gesture.moveTo(tester.getCenter(zoneFinder(DropZone.complete)));
      await tester.pump();
      expect(find.byKey(BoardCanvas.linkPreviewKey), findsNothing);

      await gesture.up();
      await harness.settle(tester);

      expect((await locate(tester, card)).status, CardStatus.completed);
      final board = await harness.readBoard(tester, harness.today);
      expect(board.links, isEmpty);
      expect(cardFinder(other), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('拖进投放区再拖出来松手：普通移动，卡片停在松手的位置', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      final before = tester.getRect(cardFinder(card));

      final gesture = await startDragging(tester, card);
      await gesture.moveTo(tester.getCenter(zoneFinder(DropZone.trash)));
      await tester.pump();
      await gesture.moveTo(before.center + const Offset(100, 150));
      await tester.pump();
      await gesture.up();
      await harness.settle(tester);

      expect(
        tester.getRect(cardFinder(card)),
        before.shift(const Offset(100, 150)),
      );
      final location = await locate(tester, card);
      expect(location.inTrash, isFalse);
      expect(location.status, CardStatus.active);
      expect(find.textContaining('已移到回收站'), findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('连线后的弹回还没播完，另一张卡片拖进投放区保存失败弹回：弹回动画被顶替，但位置、连线和存储都正确', (
      tester,
    ) async {
      final card = await seedCard(tester);
      final target = await seedCard(tester, title: '回邮件', x: 400);
      final other = await seedCard(tester, title: '交水费', y: 300);
      await harness.launch(tester);
      final before = {
        for (final c in [card, target, other]) c: tester.getRect(cardFinder(c)),
      };

      // 拖到另一张卡片上连线，松手后卡片开始弹回，只让保存跑完、不推进动画。
      final link = await startDragging(tester, card);
      await link.moveTo(tester.getCenter(cardFinder(target)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      await link.up();
      await harness.pumpData(tester);
      expect(tester.getRect(cardFinder(card)), isNot(before[card]));

      harness.failWrites = true;
      final drop = await startDragging(tester, other);
      await drop.moveTo(tester.getCenter(zoneFinder(DropZone.trash)));
      await tester.pump();
      await drop.up();
      await harness.pumpData(tester);
      // 已知限制：第一张卡片的弹回被顶替，直接回到起点。
      expect(tester.getRect(cardFinder(card)), before[card]);

      await harness.settle(tester);
      for (final c in [card, target, other]) {
        expect(tester.getRect(cardFinder(c)), before[c]);
      }
      final board = await harness.readBoard(tester, harness.today);
      expect(board.links.single.fromCardId, card.id);
      expect(board.links.single.toCardId, target.id);
      for (final c in [card, target, other]) {
        final saved = board.cards.singleWhere((s) => s.id == c.id);
        expect((saved.x, saved.y), (c.x, c.y));
        expect(saved.status, CardStatus.active);
      }
      expect((await locate(tester, other)).inTrash, isFalse);
      expect(find.text('保存失败，请重试'), findsOneWidget);

      await harness.dispose(tester);
    });

    for (final zone in DropZone.values) {
      testWidgets('拖进 ${zone.name} 区后保存失败：卡片回到拖动前的位置，提示「保存失败，请重试」', (
        tester,
      ) async {
        final card = await seedCard(tester);
        await harness.launch(tester);
        final before = tester.getRect(cardFinder(card));
        harness.failWrites = true;

        await dropInto(tester, card, zone);

        expect(tester.getRect(cardFinder(card)), before);
        expect(find.text('保存失败，请重试'), findsOneWidget);
        expect(find.textContaining('已移到回收站'), findsNothing);
        final location = await locate(tester, card);
        expect(location.status, CardStatus.active);
        expect(location.inTrash, isFalse);

        await harness.dispose(tester);
      });
    }
  });

  group('删除的撤销提示', () {
    Finder undoButton() => find.widgetWithText(SnackBarAction, '撤销');

    /// 点撤销提示上的「撤销」，等恢复保存好。
    Future<void> tapUndo(WidgetTester tester) async {
      await tester.tap(undoButton());
      await harness.settle(tester);
    }

    testWidgets('拖进 🗑️ 区：卡片消失，提示「已移到回收站：『标题』」；点撤销，卡片和连线都回来', (tester) async {
      final card = await seedCard(tester);
      final other = await seedCard(tester, title: '回邮件', x: 400);
      await harness.seed(
        tester,
        (service) => service.toggleLink(card.id, other.id),
      );
      await harness.launch(tester);
      final before = tester.getRect(cardFinder(card));

      await dropInto(tester, card, DropZone.trash);

      expect(cardFinder(card), findsNothing);
      expect((await locate(tester, card)).inTrash, isTrue);
      expect(find.text('已移到回收站：『买牛奶』'), findsOneWidget);
      expect(undoButton(), findsOneWidget);

      await tapUndo(tester);

      expect(tester.getRect(cardFinder(card)), before);
      expect((await locate(tester, card)).inTrash, isFalse);
      final board = await harness.readBoard(tester, harness.today);
      expect(board.links.single.fromCardId, card.id);
      expect(board.links.single.toCardId, other.id);

      await harness.dispose(tester);
    });

    /// 长按卡片，在菜单里点「删除」，等保存好。
    Future<void> deleteFromMenu(WidgetTester tester, TaskCard card) async {
      await tester.longPress(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      await tester.tap(find.text('删除'));
      await harness.settle(tester);
    }

    testWidgets('菜单里删除：显示同样的撤销提示，点撤销卡片回来', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      await deleteFromMenu(tester, card);

      expect(cardFinder(card), findsNothing);
      expect(find.text('已移到回收站：『买牛奶』'), findsOneWidget);

      await tapUndo(tester);

      expect(cardFinder(card), findsOneWidget);
      expect((await locate(tester, card)).inTrash, isFalse);

      await harness.dispose(tester);
    });

    testWidgets('连续删除两张卡片：提示换成后删的那张，点撤销只恢复它', (tester) async {
      final first = await seedCard(tester);
      final second = await seedCard(tester, title: '回邮件', x: 400);
      await harness.launch(tester);

      await deleteFromMenu(tester, first);
      await dropInto(tester, second, DropZone.trash);

      expect(find.text('已移到回收站：『回邮件』'), findsOneWidget);
      expect(find.text('已移到回收站：『买牛奶』'), findsNothing);

      await tapUndo(tester);

      expect(cardFinder(second), findsOneWidget);
      expect(cardFinder(first), findsNothing);
      expect((await locate(tester, second)).inTrash, isFalse);
      expect((await locate(tester, first)).inTrash, isTrue);

      await harness.dispose(tester);
    });

    testWidgets('撤销时恢复失败：提示「恢复失败，请重试」，卡片仍在回收站', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await dropInto(tester, card, DropZone.trash);
      harness.failWrites = true;

      await tapUndo(tester);

      expect(find.text('恢复失败，请重试'), findsOneWidget);
      expect(cardFinder(card), findsNothing);
      expect((await locate(tester, card)).inTrash, isTrue);

      await harness.dispose(tester);
    });

    for (final (name, size, bottomInset) in [
      ('Windows 默认窗口', const Size(800, 600), 0.0),
      ('窄窗口', const Size(360, 640), 0.0),
      ('Android 底部有手势导航条', const Size(360, 640), 24.0),
    ]) {
      testWidgets('$name：撤销提示和「＋」都完整显示，互不遮挡', (tester) async {
        tester.view
          ..devicePixelRatio = 1
          ..physicalSize = size
          ..padding = FakeViewPadding(bottom: bottomInset)
          ..viewPadding = FakeViewPadding(bottom: bottomInset);
        addTearDown(tester.view.reset);
        final card = await seedCard(tester);
        await harness.launch(tester);

        await dropInto(tester, card, DropZone.trash);

        final snackBar = tester.getRect(find.byType(SnackBar));
        final add = tester.getRect(addButton());
        expect(snackBar.overlaps(add), isFalse, reason: '$snackBar 和 $add');
        final screen = Offset.zero & size;
        expect(screen.contains(add.bottomRight), isTrue);
        expect(add.bottom, lessThanOrEqualTo(size.height - bottomInset));
        expect(snackBar.bottom, lessThanOrEqualTo(size.height));

        // 提示消失后「＋」回到右下角。
        await tester.pump(BoardCanvas.undoDuration);
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        final restored = tester.getRect(addButton());
        expect(restored.bottom, greaterThan(add.bottom));
        expect(restored.bottom, lessThanOrEqualTo(size.height - bottomInset));

        await harness.dispose(tester);
      });
    }

    testWidgets('保存失败的提示也不遮挡「＋」', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      harness.failWrites = true;

      await doubleTapCard(tester, card);

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(
        tester
            .getRect(find.byType(SnackBar))
            .overlaps(tester.getRect(addButton())),
        isFalse,
      );

      await harness.dispose(tester);
    });

    testWidgets('撤销提示显示约 4 秒后自己消失', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await dropInto(tester, card, DropZone.trash);

      await tester.pump(const Duration(milliseconds: 3500));
      expect(undoButton(), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(undoButton(), findsNothing);
      expect((await locate(tester, card)).inTrash, isTrue);

      await harness.dispose(tester);
    });

    testWidgets('过去的日期上删除后撤销：卡片按顺延规则回到今天，提示「已恢复至今天（Oct 20）」', (tester) async {
      final yesterday = harness.today.addDays(-1);
      final card = await seedCard(tester);
      // 今天已经维护过：之后才放到过去日期的卡片，启动时不会被顺延走。
      await harness.seed(tester, (service) => service.runDailyMaintenance());
      await harness.moveCardToDay(tester, card.id, yesterday);
      harness.displayedDay = yesterday;
      await harness.launch(tester);

      await deleteFromMenu(tester, card);
      await tapUndo(tester);

      expect(find.text('已恢复至今天（Oct 20）'), findsOneWidget);
      expect(cardFinder(card), findsNothing);
      final location = await locate(tester, card);
      expect(location.inTrash, isFalse);
      expect(location.dayKey, harness.today);

      await harness.dispose(tester);
    });

    testWidgets('删除还在保存时切换了日期：保存成功后仍然显示撤销提示，点撤销卡片回来', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      final gesture = await startDragging(tester, card);
      await gesture.moveTo(tester.getCenter(zoneFinder(DropZone.trash)));
      await tester.pump();
      await gesture.up();
      // 不等保存完成就换到前一天。
      await harness.showDay(tester, harness.today.addDays(-1));
      await harness.settle(tester);

      expect(find.text('已移到回收站：『买牛奶』'), findsOneWidget);

      await tapUndo(tester);

      expect((await locate(tester, card)).inTrash, isFalse);
      expect(find.text('恢复失败，请重试'), findsNothing);

      await harness.dispose(tester);
    });
  });
}
