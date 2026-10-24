import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/board_selection.dart';
import 'package:my_personal_use_app/board/card_drag.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

/// Ctrl+Z 撤销栈（AC-36 到 AC-38）。
void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 在 Windows 上跑的测试。平台要在测试结束前改回来，否则测试框架报错。
  void windowsTest(
    String description,
    Future<void> Function(WidgetTester tester) body,
  ) => testWidgets(description, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  /// 在今天的画布上准备一张卡片（默认 180 × 88）。
  Future<TaskCard> seedCard(
    WidgetTester tester, {
    required String title,
    double x = 40,
    double y = 60,
  }) => harness.seed(
    tester,
    (service) => service.createCard(harness.today, title: title, x: x, y: y),
  );

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  /// 存储里这张卡片现在的位置。
  Future<(double, double)> savedPosition(
    WidgetTester tester,
    TaskCard card,
  ) async {
    final board = await harness.readBoard(tester, harness.today);
    final saved = board.cards.singleWhere((c) => c.id == card.id);
    return (saved.x, saved.y);
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

  /// 按住 [dragged] 拖到 [target] 上，停满 400ms 再松手：切换两者之间的连线。
  Future<void> dragOnto(
    WidgetTester tester,
    TaskCard dragged,
    TaskCard target,
  ) async {
    final gesture = await tester.startGesture(
      tester.getCenter(cardFinder(dragged)),
    );
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveTo(tester.getCenter(cardFinder(target)));
    await tester.pump();
    await tester.pump(CardDragMachine.armDelay);
    await gesture.up();
    await harness.settle(tester);
  }

  /// 单击卡片，等过了双击判定时间，单击才生效。
  Future<void> tapCard(WidgetTester tester, TaskCard card) async {
    await tester.tap(cardFinder(card));
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await harness.settle(tester);
  }

  /// 按住 Ctrl 再按 [key]。
  Future<void> pressWithCtrl(
    WidgetTester tester,
    LogicalKeyboardKey key,
  ) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await harness.settle(tester);
  }

  Future<void> pressUndo(WidgetTester tester) =>
      pressWithCtrl(tester, LogicalKeyboardKey.keyZ);

  /// 存储里今天画布上的样子：每张卡片的位置，和显示着的连线两端。
  Future<({Map<String, (double, double)> cards, Set<(String, String)> links})>
  savedBoard(WidgetTester tester) async {
    final board = await harness.readBoard(tester, harness.today);
    return (
      cards: {for (final c in board.cards) c.id: (c.x, c.y)},
      links: {for (final l in board.links) (l.fromCardId, l.toCardId)},
    );
  }

  windowsTest('移动卡片后按 Ctrl+Z：卡片回到原来的位置', (tester) async {
    final card = await seedCard(tester, title: '买牛奶');
    await harness.launch(tester);
    final before = tester.getRect(cardFinder(card));
    await dragCard(tester, card, const Offset(100, 150));

    await pressUndo(tester);

    expect(tester.getRect(cardFinder(card)), before);
    expect(await savedPosition(tester, card), (40.0, 60.0));

    await harness.dispose(tester);
  });

  windowsTest('依次移动、完成、删除、新建连线、断开连线，再按 5 次 Ctrl+Z：按相反的顺序全部撤销，画布回到最开始（AC-36）', (
    tester,
  ) async {
    final a = await seedCard(tester, title: 'A', x: 40, y: 40);
    final b = await seedCard(tester, title: 'B', x: 260, y: 40);
    final c = await seedCard(tester, title: 'C', x: 480, y: 40);
    final d = await seedCard(tester, title: 'D', x: 40, y: 240);
    final e = await seedCard(tester, title: 'E', x: 260, y: 240);
    final linkId = await harness.seed(
      tester,
      (service) async => (await service.toggleLink(d.id, e.id)).linkId,
    );
    await harness.launch(tester);
    final initial = await savedBoard(tester);
    final shownBefore = {
      for (final card in [a, b, c, d, e])
        card.id: tester.getRect(cardFinder(card)),
    };

    await dragCard(tester, a, const Offset(0, 100));
    await tapCard(tester, b);
    await pressWithCtrl(tester, LogicalKeyboardKey.enter);
    await tapCard(tester, c);
    await press(tester, LogicalKeyboardKey.delete);
    await dragOnto(tester, a, e);
    await harness.selection(tester).tapLink(linkId);
    await harness.settle(tester);
    await tester.tap(find.byKey(BoardCanvas.linkScissorsKey));
    await harness.settle(tester);
    expect((await savedBoard(tester)).links, {(a.id, e.id)});

    for (var i = 0; i < 5; i++) {
      await pressUndo(tester);
    }

    final undone = await savedBoard(tester);
    expect(undone.cards, initial.cards);
    expect(undone.links, initial.links);
    for (final MapEntry(key: id, value: rect) in shownBefore.entries) {
      expect(tester.getRect(find.byKey(BoardCanvas.cardKey(id))), rect);
    }
    expect(find.text('无法撤销'), findsNothing);

    await harness.dispose(tester);
  });

  windowsTest('拖到有连线的卡片上断开后按 Ctrl+Z：连线回来', (tester) async {
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    await harness.seed(tester, (service) => service.toggleLink(a.id, b.id));
    await harness.launch(tester);
    await dragOnto(tester, a, b);
    expect((await savedBoard(tester)).links, isEmpty);

    await pressUndo(tester);

    expect((await savedBoard(tester)).links, {(a.id, b.id)});

    await harness.dispose(tester);
  });

  group('撤销栈清空以后，Ctrl+Z 不撤销之前的操作（AC-37）', () {
    windowsTest('切换日期再回来', (tester) async {
      final card = await seedCard(tester, title: '买牛奶');
      await harness.launch(tester);
      await dragCard(tester, card, const Offset(100, 150));
      final moved = await savedPosition(tester, card);

      await harness.showDay(tester, harness.today.addDays(1));
      await harness.showDay(tester, harness.today);
      await harness.settle(tester);
      await pressUndo(tester);

      expect(await savedPosition(tester, card), moved);

      await harness.dispose(tester);
    });

    windowsTest('重启 App', (tester) async {
      final card = await seedCard(tester, title: '买牛奶');
      await harness.launch(tester);
      await dragCard(tester, card, const Offset(100, 150));
      final moved = await savedPosition(tester, card);

      await tester.pumpWidget(const SizedBox());
      await harness.settle(tester);
      await harness.launch(tester);
      await pressUndo(tester);

      expect(await savedPosition(tester, card), moved);

      await harness.dispose(tester);
    });

    windowsTest('跨过午夜回到前台、执行了顺延', (tester) async {
      final card = await seedCard(tester, title: '买牛奶');
      await harness.launch(tester);
      await dragCard(tester, card, const Offset(100, 150));

      harness.now = harness.now.add(const Duration(days: 1));
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await harness.settle(tester);
      final carried = await savedPosition(tester, card);
      await pressUndo(tester);

      expect(await savedPosition(tester, card), carried);

      await harness.dispose(tester);
    });
  });

  windowsTest('撤销不了时提示「无法撤销」，丢掉这一条，再按 Ctrl+Z 撤销更早的操作（AC-38）', (tester) async {
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    await harness.launch(tester);
    await dragCard(tester, a, const Offset(100, 150));
    await tapCard(tester, b);
    await pressWithCtrl(tester, LogicalKeyboardKey.enter);
    // 在别处（比如「已完成」列表）取消了完成，撤销栈不知道。
    await harness.seed(tester, (service) => service.uncompleteCard(b.id));
    await harness.settle(tester);

    await pressUndo(tester);

    expect(find.text('无法撤销'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pressUndo(tester);

    expect(await savedPosition(tester, a), (40.0, 60.0));

    await harness.dispose(tester);
  });

  windowsTest('超过 50 条时丢掉最早的', (tester) async {
    final card = await seedCard(tester, title: '买牛奶', x: 0, y: 60);
    await harness.launch(tester);
    final selection = harness.selection(tester);
    for (var i = 1; i <= BoardSelectionController.undoLimit + 1; i++) {
      await tester.runAsync(
        () => selection.moveCard(
          card.id,
          from: Offset(i - 1, 60),
          to: Offset(i.toDouble(), 60),
        ),
      );
    }
    await harness.settle(tester);

    for (var i = 0; i <= BoardSelectionController.undoLimit; i++) {
      await pressUndo(tester);
    }

    // 第一次移动（0 → 1）已经被丢掉，撤销不回去。
    expect(await savedPosition(tester, card), (1.0, 60.0));
    expect(find.text('无法撤销'), findsNothing);

    await harness.dispose(tester);
  });

  windowsTest('还在保存时按 Ctrl+Z：等它保存好再撤销它', (tester) async {
    final card = await seedCard(tester, title: '买牛奶', x: 40, y: 60);
    await harness.launch(tester);
    final selection = harness.selection(tester);

    UndoResult? undone;
    await tester.runAsync(() async {
      unawaited(
        selection.moveCard(
          card.id,
          from: const Offset(40, 60),
          to: const Offset(300, 300),
        ),
      );
      unawaited(selection.undo().then((result) => undone = result));
    });
    await harness.pumpData(tester, rounds: 20, until: () => undone != null);
    await harness.settle(tester);

    expect(undone, isA<Undone>());

    expect(await savedPosition(tester, card), (40.0, 60.0));

    await harness.dispose(tester);
  });

  windowsTest('保存期间撤销栈被清空：这次操作也不再撤销', (tester) async {
    final card = await seedCard(tester, title: '买牛奶', x: 40, y: 60);
    await harness.launch(tester);
    final selection = harness.selection(tester);

    await tester.runAsync(() async {
      final moving = selection.moveCard(
        card.id,
        from: const Offset(40, 60),
        to: const Offset(300, 300),
      );
      selection.clearUndo();
      await moving;
    });
    await pressUndo(tester);

    expect(await savedPosition(tester, card), (300.0, 300.0));

    await harness.dispose(tester);
  });

  windowsTest('编辑时按 Ctrl+Z：交给编辑框，不撤销画布上的操作', (tester) async {
    final card = await seedCard(tester, title: '买牛奶');
    await harness.launch(tester);
    await dragCard(tester, card, const Offset(100, 150));
    final moved = await savedPosition(tester, card);
    await tapCard(tester, card);
    await tapCard(tester, card);
    expect(find.byType(TextField), findsWidgets);

    await pressUndo(tester);

    expect(await savedPosition(tester, card), moved);

    await harness.dispose(tester);
  });

  windowsTest('点过删除提示的「撤销」再按 Ctrl+Z：卡片还在，不提示「无法撤销」', (tester) async {
    final card = await seedCard(tester, title: '买牛奶');
    await harness.launch(tester);
    await tapCard(tester, card);
    await press(tester, LogicalKeyboardKey.delete);
    await tester.tap(find.text('撤销'));
    await harness.settle(tester);

    await pressUndo(tester);

    expect(cardFinder(card), findsOneWidget);
    expect(find.text('无法撤销'), findsNothing);

    await harness.dispose(tester);
  });
}
