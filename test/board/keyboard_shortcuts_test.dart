import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/board_page.dart';
import 'package:my_personal_use_app/board/board_selection.dart';
import 'package:my_personal_use_app/planner/day_key.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

/// Windows 快捷键（AC-34、AC-35，AC-6 和 AC-43 的快捷键部分）。
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

  /// 在今天的画布上准备一张卡片。
  Future<TaskCard> seedCard(
    WidgetTester tester, {
    String title = '买牛奶',
    double x = 40,
  }) => harness.seed(
    tester,
    (service) => service.createCard(harness.today, title: title, x: x, y: 60),
  );

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  /// 画布现在的选中状态。
  BoardSelection selection(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(BoardCanvas)))
          .read(boardSelectionProvider);

  /// 画布正在显示哪一天。
  DayKey displayedDay(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(BoardCanvas)))
          .read(displayedDayProvider);

  /// 回收站里卡片的 id。
  Future<List<String>> trashedIds(WidgetTester tester) => harness.seed(
    tester,
    (service) async => [
      for (final trashed in await service.watchTrash().first) trashed.card.id,
    ],
  );

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

  /// 存储里这张卡片现在的样子。
  Future<CardLocation> locate(WidgetTester tester, TaskCard card) =>
      harness.seed(tester, (service) => service.findCard(card.id));

  group('不在编辑时（AC-34）', () {
    windowsTest('选中卡片按 Delete：卡片移到回收站，显示撤销提示', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);

      await press(tester, LogicalKeyboardKey.delete);

      expect(cardFinder(card), findsNothing);
      expect(await trashedIds(tester), [card.id]);
      expect(find.text('已移到回收站：『买牛奶』'), findsOneWidget);
      expect(selection(tester), isA<NothingSelected>());

      await harness.dispose(tester);
    });

    windowsTest('选中卡片按 Backspace：同样移到回收站', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);

      await press(tester, LogicalKeyboardKey.backspace);

      expect(cardFinder(card), findsNothing);
      expect(await trashedIds(tester), [card.id]);

      await harness.dispose(tester);
    });

    windowsTest('选中连线按 Delete：什么都不做', (tester) async {
      final a = await seedCard(tester, title: 'A');
      final b = await seedCard(tester, title: 'B', x: 400);
      final linkId = await harness.seed(
        tester,
        (service) async => (await service.toggleLink(a.id, b.id)).linkId,
      );
      await harness.launch(tester);
      await harness.selection(tester).tapLink(linkId);
      await harness.settle(tester);

      await press(tester, LogicalKeyboardKey.delete);

      expect(selection(tester), isA<LinkSelected>());
      final board = await harness.readBoard(tester, harness.today);
      expect([for (final l in board.links) l.id], [linkId]);
      expect(board.cards, hasLength(2));

      await harness.dispose(tester);
    });

    windowsTest('选中卡片按 Enter：进入编辑', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);

      await press(tester, LogicalKeyboardKey.enter);

      expect(
        selection(tester),
        isA<EditingCard>().having((s) => s.cardId, 'cardId', card.id),
      );
      expect(find.widgetWithText(TextField, '买牛奶'), findsOneWidget);

      await harness.dispose(tester);
    });

    windowsTest('选中卡片按 Ctrl+Enter：完成它', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);

      await pressWithCtrl(tester, LogicalKeyboardKey.enter);

      expect(cardFinder(card), findsNothing);
      expect((await locate(tester, card)).status, CardStatus.completed);
      expect(selection(tester), isA<NothingSelected>());

      await harness.dispose(tester);
    });

    windowsTest('按 → 切到后一天，按 ← 切到前一天', (tester) async {
      await harness.launch(tester);

      await press(tester, LogicalKeyboardKey.arrowRight);
      expect(displayedDay(tester), harness.today.addDays(1));

      await press(tester, LogicalKeyboardKey.arrowLeft);
      await press(tester, LogicalKeyboardKey.arrowLeft);
      expect(displayedDay(tester), harness.today.addDays(-1));

      await harness.dispose(tester);
    });

    windowsTest('按 T 回到今天', (tester) async {
      harness.displayedDay = harness.today.addDays(-3);
      await harness.launch(tester);

      await press(tester, LogicalKeyboardKey.keyT);

      expect(displayedDay(tester), harness.today);

      await harness.dispose(tester);
    });

    windowsTest('选中卡片按 Esc：取消选中', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tapCard(tester, card);

      await press(tester, LogicalKeyboardKey.escape);

      expect(selection(tester), isA<NothingSelected>());
      expect(cardFinder(card), findsOneWidget);

      await harness.dispose(tester);
    });
  });

  group('编辑时（AC-35）', () {
    /// 选中卡片再单击，进入编辑。
    Future<void> editCard(WidgetTester tester, TaskCard card) async {
      await tapCard(tester, card);
      await tapCard(tester, card);
      expect(selection(tester), isA<EditingCard>());
    }

    /// 标题编辑框（编辑框里第一个）。
    Finder titleField() => find.byType(TextField).first;

    windowsTest('按 Ctrl+Enter：先保存改好的标题，再完成', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await editCard(tester, card);
      await tester.enterText(titleField(), '买豆浆');

      await pressWithCtrl(tester, LogicalKeyboardKey.enter);

      expect(cardFinder(card), findsNothing);
      final location = await locate(tester, card);
      expect(location.status, CardStatus.completed);
      final saved = await harness.seed(
        tester,
        (service) async =>
            (await service.watchCompleted(harness.today).first).single,
      );
      expect(saved.title, '买豆浆');

      await harness.dispose(tester);
    });

    windowsTest('新卡片按 Ctrl+Enter：先新建，再完成', (tester) async {
      await harness.launch(tester);
      await pressWithCtrl(tester, LogicalKeyboardKey.keyN);
      await tester.enterText(titleField(), '买面包');

      await pressWithCtrl(tester, LogicalKeyboardKey.enter);

      expect(selection(tester), isA<NothingSelected>());
      expect(find.text('买面包'), findsNothing);
      expect((await harness.readBoard(tester, harness.today)).cards, isEmpty);
      final completed = await harness.seed(
        tester,
        (service) => service.watchCompleted(harness.today).first,
      );
      expect([for (final c in completed) c.title], ['买面包']);

      await harness.dispose(tester);
    });

    windowsTest('按 Backspace 删字，卡片不进回收站', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await editCard(tester, card);
      await tester.enterText(titleField(), '买豆浆');

      await press(tester, LogicalKeyboardKey.backspace);

      expect(tester.widget<TextField>(titleField()).controller!.text, '买豆');
      expect(selection(tester), isA<EditingCard>());
      expect(await trashedIds(tester), isEmpty);

      await harness.dispose(tester);
    });

    windowsTest('按 ←、→、T 不切换日期，仍在编辑', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await editCard(tester, card);

      await press(tester, LogicalKeyboardKey.arrowLeft);
      await press(tester, LogicalKeyboardKey.arrowRight);
      await press(tester, LogicalKeyboardKey.keyT);

      expect(displayedDay(tester), harness.today);
      expect(selection(tester), isA<EditingCard>());

      await harness.dispose(tester);
    });

    windowsTest('按 Esc：保存并退出编辑', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await editCard(tester, card);
      await tester.enterText(titleField(), '买豆浆');

      await press(tester, LogicalKeyboardKey.escape);

      expect(selection(tester), isA<NothingSelected>());
      final board = await harness.readBoard(tester, harness.today);
      expect(board.cards.single.title, '买豆浆');

      await harness.dispose(tester);
    });

    windowsTest('新卡片标题为空时按 Esc：丢弃，不保存', (tester) async {
      await harness.launch(tester);
      await pressWithCtrl(tester, LogicalKeyboardKey.keyN);
      expect(selection(tester), isA<EditingNewCard>());

      await press(tester, LogicalKeyboardKey.escape);

      expect(selection(tester), isA<NothingSelected>());
      expect(find.byType(TextField), findsNothing);
      expect((await harness.readBoard(tester, harness.today)).cards, isEmpty);

      await harness.dispose(tester);
    });
  });

  group('Ctrl+N 新建（AC-6、AC-43）', () {
    windowsTest('在可视区域中间新建卡片并进入标题编辑', (tester) async {
      await harness.launch(tester);

      await pressWithCtrl(tester, LogicalKeyboardKey.keyN);

      final viewport = find.byType(InteractiveViewer);
      final center = tester.getCenter(viewport) - tester.getTopLeft(viewport);
      expect(
        selection(tester),
        isA<EditingNewCard>()
            .having((s) => s.x, 'x', center.dx - TaskCard.defaultWidth / 2)
            .having((s) => s.y, 'y', center.dy - TaskCard.defaultHeight / 2),
      );
      expect(find.widgetWithText(TextField, '标题'), findsOneWidget);

      await harness.dispose(tester);
    });

    windowsTest('过去的日期上不新建', (tester) async {
      harness.displayedDay = harness.today.addDays(-1);
      await harness.launch(tester);

      await pressWithCtrl(tester, LogicalKeyboardKey.keyN);

      expect(selection(tester), isA<NothingSelected>());
      expect(find.byType(TextField), findsNothing);

      await harness.dispose(tester);
    });
  });

  windowsTest('打开别的页面期间换了一天，返回后快捷键仍然有效', (tester) async {
    await harness.launch(tester);
    await tester.tap(find.byKey(BoardPage.trashButtonKey));
    await harness.settle(tester);
    await harness.showDay(tester, harness.today.addDays(1));

    await tester.pageBack();
    await harness.settle(tester);
    await press(tester, LogicalKeyboardKey.arrowRight);

    expect(displayedDay(tester), harness.today.addDays(2));

    await harness.dispose(tester);
  });

  testWidgets('Android 上不启用快捷键', (tester) async {
    final card = await seedCard(tester);
    await harness.launch(tester);
    await tapCard(tester, card);

    await press(tester, LogicalKeyboardKey.delete);
    await press(tester, LogicalKeyboardKey.arrowRight);
    await pressWithCtrl(tester, LogicalKeyboardKey.keyN);

    expect(cardFinder(card), findsOneWidget);
    expect(await trashedIds(tester), isEmpty);
    expect(displayedDay(tester), harness.today);
    expect(selection(tester), isA<CardSelected>());

    await harness.dispose(tester);
  });
}
