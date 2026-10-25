import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/board_layout.dart';
import 'package:my_personal_use_app/board/board_page.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

/// 「显示全部卡片」：只平移、缩放画布，让当天所有卡片都在可视区域里（#67）。
void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 把窗口设成 [width] × [height] 逻辑像素。
  void useWindow(WidgetTester tester, double width, [double height = 700]) {
    tester.view
      ..physicalSize = Size(width, height)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> resizeTo(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, tester.view.physicalSize.height);
    await harness.settle(tester);
  }

  Future<TaskCard> seedCard(
    WidgetTester tester, {
    required double x,
    required double y,
    String title = '买牛奶',
  }) => harness.seed(
    tester,
    (service) => service.createCard(harness.today, title: title, x: x, y: y),
  );

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  /// 画布的可视区域在屏幕上的范围。
  Rect canvasRect(WidgetTester tester) =>
      tester.getRect(find.byType(InteractiveViewer));

  bool isShown(WidgetTester tester, TaskCard card) {
    final shown = tester.getRect(cardFinder(card));
    return canvasRect(tester).intersect(shown) == shown;
  }

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

  Future<void> pressCtrl0(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await harness.settle(tester);
  }

  IconButton showAllButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.byKey(BoardPage.showAllCardsButtonKey));

  Future<void> showAll(WidgetTester tester) async {
    await tester.tap(find.byKey(BoardPage.showAllCardsButtonKey));
    await harness.settle(tester);
  }

  testWidgets('窗口变窄后卡片跑到可视区域外面，点「显示全部卡片」又看得见', (tester) async {
    useWindow(tester, 800);
    final card = await seedCard(tester, x: 600, y: 60);
    await harness.launch(tester);
    await resizeTo(tester, 400);
    expect(isShown(tester, card), isFalse);

    await showAll(tester);

    expect(isShown(tester, card), isTrue);
    await harness.dispose(tester);
  });

  testWidgets('卡片铺得比可视区域宽：缩小画布，两头的卡片都看得见', (tester) async {
    useWindow(tester, 400);
    final left = await seedCard(tester, x: 0, y: 60, title: '左边');
    final right = await seedCard(tester, x: 400, y: 300, title: '右边');
    await harness.launch(tester);

    await showAll(tester);

    expect(isShown(tester, left), isTrue);
    expect(isShown(tester, right), isTrue);
    await harness.dispose(tester);
  });

  testWidgets('缩到最小（0.5）也放不下：停在 0.5，最左上的卡片看得见', (tester) async {
    useWindow(tester, 400);
    final first = await seedCard(tester, x: 0, y: 60, title: '左上');
    await seedCard(tester, x: 3000, y: 2000, title: '很远');
    await harness.launch(tester);

    await showAll(tester);

    expect(isShown(tester, first), isTrue);
    expect(
      tester.getRect(cardFinder(first)).width,
      first.width * BoardCanvas.minScale,
    );
    await harness.dispose(tester);
  });

  testWidgets('本来放得下时按原大小显示，不放大', (tester) async {
    useWindow(tester, 400);
    final card = await seedCard(tester, x: 40, y: 60);
    await harness.launch(tester);

    await showAll(tester);

    expect(tester.getRect(cardFinder(card)).width, card.width);
    expect(isShown(tester, card), isTrue);
    await harness.dispose(tester);
  });

  testWidgets('画布放大以后点「显示全部卡片」，回到原大小，卡片放在中间', (tester) async {
    useWindow(tester, 400);
    final card = await seedCard(tester, x: 40, y: 60);
    await harness.launch(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(const Offset(200, 300)));
    await tester.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await harness.settle(tester);
    expect(tester.getRect(cardFinder(card)).width, greaterThan(card.width));

    await showAll(tester);

    final shown = tester.getRect(cardFinder(card));
    expect(shown.size, Size(card.width, card.height));
    expect(shown.center, canvasRect(tester).center);
    await harness.dispose(tester);
  });

  testWidgets('宽屏时侧栏挡住的部分不算看得见，卡片放进侧栏右边的画布里', (tester) async {
    useWindow(tester, 1000);
    final left = await seedCard(tester, x: -100, y: 60, title: '左边');
    final right = await seedCard(tester, x: 900, y: 60, title: '右边');
    await harness.launch(tester);
    expect(canvasRect(tester).left, dateSidebarWidth);

    await showAll(tester);

    expect(isShown(tester, left), isTrue);
    expect(isShown(tester, right), isTrue);
    await harness.dispose(tester);
  });

  testWidgets('历史记录也算在里面', (tester) async {
    useWindow(tester, 400);
    final yesterday = harness.today;
    await seedCard(tester, x: 900, y: 600);
    harness.now = harness.now.add(const Duration(days: 1));
    await harness.seed(tester, (service) => service.runDailyMaintenance());
    final record = (await harness.readBoard(
      tester,
      yesterday,
    )).carryOverRecords.single;
    harness.displayedDay = yesterday;
    await harness.launch(tester);
    final recordFinder = find.byKey(BoardCanvas.carryOverRecordKey(record.id));
    final before = tester.getRect(recordFinder);
    expect(canvasRect(tester).intersect(before), isNot(before));

    await showAll(tester);

    final shown = tester.getRect(recordFinder);
    expect(canvasRect(tester).intersect(shown), shown);
    await harness.dispose(tester);
  });

  testWidgets('这一天没有卡片时按钮不能点', (tester) async {
    useWindow(tester, 400);
    await harness.launch(tester);

    expect(showAllButton(tester).onPressed, isNull);
    await harness.dispose(tester);
  });

  testWidgets('只改视图：卡片的坐标、大小都不变，不写数据库', (tester) async {
    useWindow(tester, 400);
    final card = await seedCard(tester, x: 600, y: 900);
    await harness.launch(tester);

    await showAll(tester);

    final saved = (await harness.readBoard(tester, harness.today)).cards;
    expect((saved.single.x, saved.single.y), (card.x, card.y));
    expect(
      (saved.single.width, saved.single.height),
      (card.width, card.height),
    );
    expect(saved.single.updatedAt, card.updatedAt);
    await harness.dispose(tester);
  });

  windowsTest('Windows 上按 Ctrl+0 显示全部卡片', (tester) async {
    useWindow(tester, 400);
    final card = await seedCard(tester, x: 600, y: 60);
    await harness.launch(tester);
    expect(isShown(tester, card), isFalse);

    await pressCtrl0(tester);

    expect(isShown(tester, card), isTrue);
    await harness.dispose(tester);
  });

  windowsTest('编辑时 Ctrl+0 不起作用，交给编辑框', (tester) async {
    useWindow(tester, 400);
    final card = await seedCard(tester, x: 300, y: 60);
    await harness.launch(tester);
    final before = tester.getRect(cardFinder(card));
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text(card.title));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
    }
    expect(find.widgetWithText(TextField, card.title), findsOneWidget);

    await pressCtrl0(tester);

    expect(tester.getRect(cardFinder(card)), before);
    await harness.dispose(tester);
  });
}
