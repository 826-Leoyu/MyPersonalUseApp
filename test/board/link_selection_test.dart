import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/board_selection.dart';
import 'package:my_personal_use_app/board/card_drag.dart';
import 'package:my_personal_use_app/board/link_layer.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 在今天的画布上准备一张卡片（默认 180 × 88）。
  Future<TaskCard> seedCard(
    WidgetTester tester, {
    required String title,
    required double x,
    double y = 60,
  }) => harness.seed(
    tester,
    (service) => service.createCard(harness.today, title: title, x: x, y: y),
  );

  /// 在启动 App 之前连一条 [from] → [to] 的线，返回连线 ID。
  Future<String> seedLink(WidgetTester tester, TaskCard from, TaskCard to) =>
      harness.seed(
        tester,
        (service) async => (await service.toggleLink(from.id, to.id)).linkId,
      );

  Finder cardFinder(TaskCard card) => find.byKey(BoardCanvas.cardKey(card.id));

  final scissorsFinder = find.byKey(BoardCanvas.linkScissorsKey);

  /// 连线层现在画着的连线。
  List<PaintedLink> shownLinks(WidgetTester tester) {
    final layer = tester.widget<CustomPaint>(find.byKey(LinkLayer.paintKey));
    return (layer.painter! as LinkPainter).links;
  }

  /// 现在高亮的连线的 ID。
  List<String> highlighted(WidgetTester tester) => [
    for (final link in shownLinks(tester))
      if (link.selected) link.id,
  ];

  /// 画布现在的选中状态。
  BoardSelection selection(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(BoardCanvas)))
          .read(boardSelectionProvider);

  /// 画布上的点 [canvas] 在屏幕上的位置。[anchor] 是画布上的任意一张卡片，
  /// 用它在屏幕上的位置和大小算出平移和缩放。
  Offset onScreen(WidgetTester tester, TaskCard anchor, Offset canvas) {
    final rect = tester.getRect(cardFinder(anchor));
    final scale = rect.width / anchor.width;
    return rect.topLeft + (canvas - Offset(anchor.x, anchor.y)) * scale;
  }

  /// 存储里今天还连着的连线的 ID。
  Future<List<String>> savedLinkIds(WidgetTester tester) async => [
    for (final link in (await harness.readBoard(tester, harness.today)).links)
      link.id,
  ];

  /// 单击屏幕上的 [at]，等过双击判定时间，让单击生效。
  Future<void> tapAt(WidgetTester tester, Offset at) async {
    await tester.tapAt(at);
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);
  }

  /// 单击 A、B 之间连线的中段，选中它。
  Future<void> selectLink(
    WidgetTester tester,
    TaskCard a,
    String linkId,
  ) async {
    await tapAt(tester, onScreen(tester, a, const Offset(310, 110)));
    expect(highlighted(tester), [linkId]);
  }

  // A 在左、B 在右，同样高：连线是 (220, 104) 到 (400, 104) 的直线段。
  Future<(TaskCard, TaskCard, String)> seedPair(WidgetTester tester) async {
    final a = await seedCard(tester, title: 'A', x: 40);
    final b = await seedCard(tester, title: 'B', x: 400);
    final linkId = await seedLink(tester, a, b);
    return (a, b, linkId);
  }

  testWidgets('单击连线：连线高亮，中点出现 ✂️（AC-15）', (tester) async {
    final (a, _, linkId) = await seedPair(tester);
    await harness.launch(tester);
    expect(highlighted(tester), isEmpty);
    expect(scissorsFinder, findsNothing);

    await tapAt(tester, onScreen(tester, a, const Offset(310, 110)));

    expect(highlighted(tester), [linkId]);
    expect(
      tester.getCenter(scissorsFinder),
      onScreen(tester, a, const Offset(310, 104)),
    );

    await harness.dispose(tester);
  });

  testWidgets('单击 ✂️：连线断开，保存好之后淡出，取消选中（AC-15）', (tester) async {
    final (a, _, linkId) = await seedPair(tester);
    await harness.launch(tester);
    await selectLink(tester, a, linkId);

    await tester.tap(scissorsFinder);
    // ✂️ 不用等双击判定，保存好就开始淡出。
    await harness.pumpData(tester);

    expect(await savedLinkIds(tester), isEmpty);
    expect(scissorsFinder, findsNothing);
    await tester.pump(LinkLayer.fadeDuration ~/ 2);
    expect(shownLinks(tester).single.opacity, inExclusiveRange(0, 1));
    await tester.pump(
      LinkLayer.fadeDuration + const Duration(milliseconds: 16),
    );
    expect(shownLinks(tester), isEmpty);

    await harness.dispose(tester);
  });

  testWidgets('选中连线后单击空白处：取消高亮，✂️ 消失，连线不变（AC-15）', (tester) async {
    final (a, _, linkId) = await seedPair(tester);
    await harness.launch(tester);
    await selectLink(tester, a, linkId);

    await tapAt(tester, onScreen(tester, a, const Offset(310, 300)));

    expect(selection(tester), isA<NothingSelected>());
    expect(highlighted(tester), isEmpty);
    expect(scissorsFinder, findsNothing);
    expect(await savedLinkIds(tester), [linkId]);

    await harness.dispose(tester);
  });

  testWidgets('离连线 13 逻辑像素单击算点空白处：不选中连线，取消选中的卡片', (tester) async {
    final (a, _, _) = await seedPair(tester);
    await harness.launch(tester);
    await tapAt(tester, tester.getCenter(cardFinder(a)));
    expect(selection(tester), isA<CardSelected>());

    await tapAt(tester, onScreen(tester, a, const Offset(310, 117)));

    expect(selection(tester), isA<NothingSelected>());
    expect(highlighted(tester), isEmpty);
    expect(scissorsFinder, findsNothing);

    await harness.dispose(tester);
  });

  /// 画布放大或缩小到 [scale] 倍，以屏幕上的 [focal] 为中心。
  Future<void> zoomTo(WidgetTester tester, double scale, Offset focal) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(mouse.hover(focal));
    // Ctrl+滚轮每滚动 200 逻辑像素缩放 e 倍，见 BoardCanvas。
    await tester.sendEventToBinding(
      mouse.scroll(Offset(0, -200 * math.log(scale))),
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await harness.settle(tester);
  }

  /// 屏幕大一些，画布放大到 3 倍时连线还在屏幕里。
  void useLargeView(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(2400, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  for (final scale in [0.5, 1.0, 3.0]) {
    testWidgets('画布 $scale 倍：离连线屏幕上 13 像素不算点中，11 像素算；'
        '✂️ 在中点，图标 32、点击范围 44 × 44（屏幕上）', (tester) async {
      useLargeView(tester);
      final (a, _, linkId) = await seedPair(tester);
      await harness.launch(tester);
      await zoomTo(tester, scale, onScreen(tester, a, const Offset(310, 104)));
      expect(
        tester.getRect(cardFinder(a)).width,
        moreOrLessEquals(TaskCard.defaultWidth * scale),
      );
      final middle = onScreen(tester, a, const Offset(310, 104));

      await tapAt(tester, middle + const Offset(0, 13));
      expect(highlighted(tester), isEmpty);
      await tapAt(tester, middle + const Offset(0, -13));
      expect(highlighted(tester), isEmpty);

      await tapAt(tester, middle + const Offset(0, 11));
      expect(highlighted(tester), [linkId]);
      final scissors = tester.getRect(scissorsFinder);
      expect(scissors.center.dx, moreOrLessEquals(middle.dx));
      expect(scissors.center.dy, moreOrLessEquals(middle.dy));
      expect(scissors.size, const Size(44, 44));
      final icon = find.descendant(
        of: scissorsFinder,
        matching: find.byType(DecoratedBox),
      );
      expect(tester.getRect(icon).size, const Size(32, 32));

      await harness.dispose(tester);
    });
  }

  /// A、B 之间的连线中段被 C 盖住：C 占 (260, 80) 到 (440, 168)，
  /// 连线只有 x 在 220 到 260 之间露在外面。
  Future<(TaskCard, TaskCard, String)> seedCovered(WidgetTester tester) async {
    final (a, _, linkId) = await seedPair(tester);
    final c = await seedCard(tester, title: 'C', x: 260, y: 80);
    return (a, c, linkId);
  }

  testWidgets('卡片盖在连线上：点在卡片范围内算点卡片，不选中连线（AC-17）', (tester) async {
    final (a, c, _) = await seedCovered(tester);
    await harness.launch(tester);

    await tapAt(tester, onScreen(tester, a, const Offset(300, 104)));

    expect(
      selection(tester),
      isA<CardSelected>().having((s) => s.cardId, 'cardId', c.id),
    );
    expect(highlighted(tester), isEmpty);

    await harness.dispose(tester);
  });

  testWidgets('✂️ 盖在卡片上：单击 ✂️ 断开连线，不选中下面的卡片', (tester) async {
    final (a, _, linkId) = await seedCovered(tester);
    await harness.launch(tester);
    await tapAt(tester, onScreen(tester, a, const Offset(240, 106)));
    expect(highlighted(tester), [linkId]);

    await tester.tap(scissorsFinder);
    await harness.pumpData(tester);
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);

    expect(await savedLinkIds(tester), isEmpty);
    expect(selection(tester), isA<NothingSelected>());
    expect(find.byType(TextField), findsNothing);

    await harness.dispose(tester);
  });

  testWidgets('双击连线：和单击一样选中连线，不会当成双击空白处新建卡片', (tester) async {
    final (a, _, linkId) = await seedPair(tester);
    await harness.launch(tester);
    final at = onScreen(tester, a, const Offset(310, 110));

    await tester.tapAt(at);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(at);
    await harness.settle(tester);

    expect(highlighted(tester), [linkId]);
    expect(scissorsFinder, findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(
      (await harness.readBoard(tester, harness.today)).cards,
      hasLength(2),
    );

    await harness.dispose(tester);
  });

  testWidgets('双击连线时第二下偏出了判定范围：仍然只选中连线，不新建卡片', (tester) async {
    final (a, _, linkId) = await seedPair(tester);
    await harness.launch(tester);

    await tester.tapAt(onScreen(tester, a, const Offset(310, 110)));
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(onScreen(tester, a, const Offset(310, 140)));
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);

    expect(find.byType(TextField), findsNothing);
    expect(
      (await harness.readBoard(tester, harness.today)).cards,
      hasLength(2),
    );
    expect(highlighted(tester), [linkId]);

    await harness.dispose(tester);
  });

  group('同一时间只选中一张卡片或一条连线', () {
    testWidgets('选中卡片后单击连线：卡片取消选中，选中连线', (tester) async {
      final (a, _, linkId) = await seedPair(tester);
      await harness.launch(tester);
      await tapAt(tester, tester.getCenter(cardFinder(a)));
      expect(find.byKey(BoardCanvas.resizeHandleKey(a.id)), findsOneWidget);

      await selectLink(tester, a, linkId);

      expect(selection(tester), isA<LinkSelected>());
      expect(find.byKey(BoardCanvas.resizeHandleKey(a.id)), findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('选中连线后单击卡片：连线取消高亮，✂️ 消失，选中卡片', (tester) async {
      final (a, _, linkId) = await seedPair(tester);
      await harness.launch(tester);
      await selectLink(tester, a, linkId);

      await tapAt(tester, tester.getCenter(cardFinder(a)));

      expect(
        selection(tester),
        isA<CardSelected>().having((s) => s.cardId, 'cardId', a.id),
      );
      expect(highlighted(tester), isEmpty);
      expect(scissorsFinder, findsNothing);

      await harness.dispose(tester);
    });
  });

  group('编辑卡片时单击连线，先结束编辑', () {
    Finder titleField() => find.widgetWithText(TextField, '标题');

    /// 进入编辑 [card]，把标题改成 [title]。
    Future<void> editTitle(
      WidgetTester tester,
      TaskCard card,
      String title,
    ) async {
      await tapAt(tester, tester.getCenter(cardFinder(card)));
      await tapAt(tester, tester.getCenter(cardFinder(card)));
      await tester.enterText(titleField(), title);
    }

    testWidgets('保存编辑的内容，再选中连线', (tester) async {
      final (a, _, linkId) = await seedPair(tester);
      await harness.launch(tester);
      await editTitle(tester, a, '改过的 A');

      await selectLink(tester, a, linkId);

      expect(find.byType(TextField), findsNothing);
      final saved = (await harness.readBoard(
        tester,
        harness.today,
      )).cards.singleWhere((c) => c.id == a.id);
      expect(saved.title, '改过的 A');

      await harness.dispose(tester);
    });

    testWidgets('保存失败：提示「保存失败，请重试」，仍在编辑，内容不丢，不选中连线', (tester) async {
      final (a, _, _) = await seedPair(tester);
      await harness.launch(tester);
      await editTitle(tester, a, '改过的 A');
      harness.failWrites = true;

      await tapAt(tester, onScreen(tester, a, const Offset(310, 110)));

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(find.widgetWithText(TextField, '改过的 A'), findsOneWidget);
      expect(selection(tester), isA<EditingCard>());
      expect(highlighted(tester), isEmpty);
      expect(scissorsFinder, findsNothing);

      await harness.dispose(tester);
    });
  });

  group('Windows 上右键连线：弹出「断开连线」菜单（AC-16）', () {
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

    /// 右键屏幕上的 [at]。
    Future<void> rightClickAt(WidgetTester tester, Offset at) async {
      await tester.tapAt(
        at,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
    }

    final menuItem = find.text('断开连线');

    windowsTest('选「断开连线」：连线断开', (tester) async {
      final (a, _, _) = await seedPair(tester);
      await harness.launch(tester);

      await rightClickAt(tester, onScreen(tester, a, const Offset(310, 110)));
      expect(menuItem, findsOneWidget);
      await tester.tap(menuItem);
      await harness.settle(tester);

      expect(menuItem, findsNothing);
      expect(await savedLinkIds(tester), isEmpty);
      expect(shownLinks(tester), isEmpty);

      await harness.dispose(tester);
    });

    windowsTest('右键不改变选中：选中的卡片仍然选中，连线不高亮；按 Esc 关掉菜单，连线不变', (tester) async {
      final (a, _, linkId) = await seedPair(tester);
      await harness.launch(tester);
      await tapAt(tester, tester.getCenter(cardFinder(a)));

      await rightClickAt(tester, onScreen(tester, a, const Offset(310, 110)));

      expect(menuItem, findsOneWidget);
      expect(
        selection(tester),
        isA<CardSelected>().having((s) => s.cardId, 'cardId', a.id),
      );
      expect(highlighted(tester), isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await harness.settle(tester);
      expect(menuItem, findsNothing);
      expect(selection(tester), isA<CardSelected>());
      expect(await savedLinkIds(tester), [linkId]);

      await harness.dispose(tester);
    });

    windowsTest('右键选中的连线断开后取消选中，✂️ 消失', (tester) async {
      final (a, _, linkId) = await seedPair(tester);
      await harness.launch(tester);
      await selectLink(tester, a, linkId);

      await rightClickAt(tester, onScreen(tester, a, const Offset(260, 100)));
      await tester.tap(menuItem);
      await harness.settle(tester);

      expect(await savedLinkIds(tester), isEmpty);
      expect(selection(tester), isA<NothingSelected>());
      expect(scissorsFinder, findsNothing);

      await harness.dispose(tester);
    });

    windowsTest('离连线 13 逻辑像素右键：不弹菜单', (tester) async {
      final (a, _, _) = await seedPair(tester);
      await harness.launch(tester);

      await rightClickAt(tester, onScreen(tester, a, const Offset(310, 117)));

      expect(menuItem, findsNothing);

      await harness.dispose(tester);
    });
  });

  testWidgets('断开失败：提示「保存失败，请重试」，连线和选中都不变', (tester) async {
    final (a, _, linkId) = await seedPair(tester);
    await harness.launch(tester);
    await selectLink(tester, a, linkId);
    harness.failWrites = true;

    await tester.tap(scissorsFinder);
    await harness.settle(tester);

    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(await savedLinkIds(tester), [linkId]);
    expect(highlighted(tester), [linkId]);
    expect(scissorsFinder, findsOneWidget);
    expect(shownLinks(tester).single.opacity, 1);

    await harness.dispose(tester);
  });

  group('选中的连线不再显示时取消选中', () {
    testWidgets('一端的卡片删除了', (tester) async {
      final (a, b, linkId) = await seedPair(tester);
      await harness.launch(tester);
      await selectLink(tester, a, linkId);

      await tester.longPress(cardFinder(b));
      await harness.settle(tester);
      await tester.tap(find.text('删除'));
      await harness.settle(tester);

      expect(selection(tester), isA<NothingSelected>());
      expect(scissorsFinder, findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('一端的卡片完成了（#20）', (tester) async {
      final (a, b, linkId) = await seedPair(tester);
      await harness.launch(tester);
      await selectLink(tester, a, linkId);

      await tester.tap(cardFinder(b));
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(cardFinder(b));
      await harness.settle(tester);

      expect(cardFinder(b), findsNothing);
      expect(selection(tester), isA<NothingSelected>());
      expect(scissorsFinder, findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('拖着一端的卡片碰另一端，断开了', (tester) async {
      final (a, b, linkId) = await seedPair(tester);
      await harness.launch(tester);
      await selectLink(tester, a, linkId);

      final gesture = await tester.startGesture(
        tester.getCenter(cardFinder(b)),
      );
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveTo(tester.getCenter(cardFinder(a)));
      await tester.pump();
      await tester.pump(CardDragMachine.armDelay);
      await gesture.up();
      await harness.settle(tester);

      expect(await savedLinkIds(tester), isEmpty);
      expect(selection(tester), isA<NothingSelected>());
      expect(scissorsFinder, findsNothing);

      await harness.dispose(tester);
    });
  });

  testWidgets('拖动卡片时选中的连线保持选中，✂️ 跟着连线中点走', (tester) async {
    final (a, b, linkId) = await seedPair(tester);
    await harness.launch(tester);
    await selectLink(tester, a, linkId);

    // 把 B 往右拖 100：连线变成 (220, 104) 到 (500, 104)，中点 (360, 104)。
    final gesture = await tester.startGesture(tester.getCenter(cardFinder(b)));
    await gesture.moveBy(const Offset(30, 0));
    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();

    expect(highlighted(tester), [linkId]);
    expect(
      tester.getCenter(scissorsFinder),
      onScreen(tester, a, const Offset(360, 104)),
    );
    await gesture.up();
    await harness.settle(tester);
    expect(selection(tester), isA<LinkSelected>());

    await harness.dispose(tester);
  });

  testWidgets('从连线上开始拖动鼠标：平移画布，不选中也不断开连线', (tester) async {
    final (a, _, linkId) = await seedPair(tester);
    await harness.launch(tester);

    final gesture = await tester.startGesture(
      onScreen(tester, a, const Offset(310, 110)),
      kind: PointerDeviceKind.mouse,
    );
    // 先越过拖动判定的距离，之后的移动才全部用来平移。
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    final before = tester.getRect(cardFinder(a));
    await gesture.moveBy(const Offset(100, 50));
    await tester.pump();
    final after = tester.getRect(cardFinder(a));
    await gesture.up();
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);

    expect(after.topLeft - before.topLeft, const Offset(100, 50));
    expect(selection(tester), isA<NothingSelected>());
    expect(highlighted(tester), isEmpty);
    expect(await savedLinkIds(tester), [linkId]);

    await harness.dispose(tester);
  });

  testWidgets('单击 ✂️ 后马上在同一位置再点一下：不会和 ✂️ 凑成双击空白处新建卡片', (tester) async {
    final (a, _, linkId) = await seedPair(tester);
    await harness.launch(tester);
    await selectLink(tester, a, linkId);
    final at = tester.getCenter(scissorsFinder);

    await tester.tapAt(at);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(at);
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);

    expect(await savedLinkIds(tester), isEmpty);
    expect(find.byType(TextField), findsNothing);
    expect(
      (await harness.readBoard(tester, harness.today)).cards,
      hasLength(2),
    );

    await harness.dispose(tester);
  });

  testWidgets('平移画布、改变窗口大小后，✂️ 仍在连线中点', (tester) async {
    final (a, _, linkId) = await seedPair(tester);
    await harness.launch(tester);
    await selectLink(tester, a, linkId);

    final gesture = await tester.startGesture(
      onScreen(tester, a, const Offset(310, 400)),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(20, 0));
    await gesture.moveBy(const Offset(-120, 70));
    await gesture.up();
    await harness.settle(tester);
    expect(
      tester.getCenter(scissorsFinder),
      onScreen(tester, a, const Offset(310, 104)),
    );

    tester.view
      ..physicalSize = const Size(1000, 700)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await harness.settle(tester);

    expect(highlighted(tester), [linkId]);
    expect(
      tester.getCenter(scissorsFinder),
      onScreen(tester, a, const Offset(310, 104)),
    );

    await harness.dispose(tester);
  });
}
