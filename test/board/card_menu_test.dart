import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/board/board_selection.dart';
import 'package:my_personal_use_app/planner/card_colors.dart';
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

  Finder handleFinder(TaskCard card) =>
      find.byKey(BoardCanvas.resizeHandleKey(card.id));

  /// 长按卡片，等菜单弹出来。
  Future<void> longPressCard(WidgetTester tester, TaskCard card) async {
    await tester.longPress(cardFinder(card));
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);
  }

  /// 长按卡片，在菜单里选 [item]。
  Future<void> chooseFromMenu(
    WidgetTester tester,
    TaskCard card,
    String item,
  ) async {
    await longPressCard(tester, card);
    await tester.tap(find.text(item));
    await harness.settle(tester);
  }

  /// 画布上这张卡片现在的底色。
  Color shownColor(WidgetTester tester, TaskCard card) {
    final frame = tester.widget<DecoratedBox>(
      find
          .descendant(of: cardFinder(card), matching: find.byType(DecoratedBox))
          .first,
    );
    return (frame.decoration as BoxDecoration).color!;
  }

  /// 存储里这张卡片现在的样子（用新开的数据库连接读出来）。
  Future<TaskCard> savedCard(WidgetTester tester, TaskCard card) async =>
      (await harness.readBoard(
        tester,
        harness.today,
      )).cards.singleWhere((c) => c.id == card.id);

  /// 卡片标题现在的文字颜色。
  Color? titleColor(WidgetTester tester, TaskCard card) => tester
      .widget<Text>(
        find.descendant(of: cardFinder(card), matching: find.text(card.title)),
      )
      .style
      ?.color;

  /// 打开「自定义」色轮，选中 [color]。色轮靠拖动选色，测试里直接调用
  /// 它的颜色回调。
  Future<void> pickCustomColor(WidgetTester tester, Color color) async {
    await tester.tap(find.text('自定义…'));
    await tester.pumpAndSettle();
    tester.widget<ColorPicker>(find.byType(ColorPicker)).onColorChanged(color);
    await tester.pumpAndSettle();
  }

  /// 深蓝，相对亮度远低于 0.5。
  const darkBlue = Color(0xFF1F3A93);

  /// 回收站里卡片的 id（用新开的数据库连接读出来）。
  Future<List<String>> trashedIds(WidgetTester tester) => harness.seed(
    tester,
    (service) async => [
      for (final trashed in await service.watchTrash().first) trashed.card.id,
    ],
  );

  /// 画布现在的选中和编辑状态。
  BoardSelection selection(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(BoardCanvas)))
          .read(boardSelectionProvider);

  /// 预设色 [name] 的 ARGB 值。
  int preset(String name) =>
      CardColors.presets.singleWhere((p) => p.name == name).argb;

  void expectMenuShown() {
    expect(find.text('改颜色'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
  }

  testWidgets('长按卡片弹出菜单：改颜色、编辑、删除；卡片不动，也不选中', (tester) async {
    final card = await seedCard(tester);
    await harness.launch(tester);
    final before = tester.getRect(cardFinder(card));

    await longPressCard(tester, card);

    expectMenuShown();
    expect(tester.getRect(cardFinder(card)), before);
    expect(handleFinder(card), findsNothing);

    await harness.dispose(tester);
  });

  testWidgets('右键卡片弹出同样的菜单，不选中也不进入编辑', (tester) async {
    final card = await seedCard(tester);
    await harness.launch(tester);
    final before = tester.getRect(cardFinder(card));

    await tester.tap(
      cardFinder(card),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);

    expectMenuShown();
    expect(tester.getRect(cardFinder(card)), before);
    expect(handleFinder(card), findsNothing);
    expect(find.byType(TextField), findsNothing);

    await harness.dispose(tester);
  });

  /// 现在选中的是 [card]。
  void expectSelected(WidgetTester tester, TaskCard card) => expect(
    selection(tester),
    isA<CardSelected>().having((s) => s.cardId, 'cardId', card.id),
  );

  /// 单击卡片选中它。
  Future<void> selectCard(WidgetTester tester, TaskCard card) async {
    await tester.tap(cardFinder(card));
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);
    expect(selection(tester), isA<CardSelected>());
    expect(handleFinder(card), findsOneWidget);
  }

  /// 按 Esc 关掉菜单，什么也不选。
  Future<void> dismissMenu(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await harness.settle(tester);
    expect(find.text('改颜色'), findsNothing);
  }

  group('已选中的卡片弹出菜单后仍然选中', () {
    testWidgets('长按', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await selectCard(tester, card);

      await longPressCard(tester, card);

      expectMenuShown();
      expectSelected(tester, card);
      await dismissMenu(tester);
      expectSelected(tester, card);
      expect(handleFinder(card), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('右键', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await selectCard(tester, card);

      await tester.tap(
        cardFinder(card),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expectMenuShown();
      expectSelected(tester, card);
      await dismissMenu(tester);
      expectSelected(tester, card);
      expect(handleFinder(card), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('选中另一张卡片时长按这张：还是选中那张', (tester) async {
      final first = await seedCard(tester);
      final second = await seedCard(tester, title: '回邮件', x: 400);
      await harness.launch(tester);
      await selectCard(tester, first);

      await longPressCard(tester, second);
      await dismissMenu(tester);

      expectSelected(tester, first);
      expect(handleFinder(first), findsOneWidget);
      expect(handleFinder(second), findsNothing);

      await harness.dispose(tester);
    });
  });

  group('长按不算双击', () {
    testWidgets('长按关掉菜单后马上单击卡片：是单击，选中卡片', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      // 长按松手后不等双击判定时间，马上关菜单、单击。
      await tester.longPress(cardFinder(card));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expectSelected(tester, card);
      expect(handleFinder(card), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('单击空白处后马上长按旁边的卡片：弹出菜单，不新建卡片', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      final rect = tester.getRect(cardFinder(card));

      // 点在卡片左边一点的空白处，和长按的位置离得够近，能凑成双击。
      await tester.tapAt(rect.centerLeft - const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.longPressAt(rect.centerLeft + const Offset(20, 0));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expectMenuShown();
      expect(find.widgetWithText(TextField, '标题'), findsNothing);
      expect(selection(tester), isA<NothingSelected>());
      final board = await harness.readBoard(tester, harness.today);
      expect(board.cards.map((c) => c.id), [card.id]);

      await harness.dispose(tester);
    });
  });

  testWidgets('长按时手指在判定距离以内轻微移动：仍然弹出菜单，卡片不动，画布不平移', (tester) async {
    final card = await seedCard(tester);
    final other = await seedCard(tester, title: '回邮件', x: 400);
    await harness.launch(tester);
    final before = tester.getRect(cardFinder(card));
    final otherBefore = tester.getRect(cardFinder(other));

    final gesture = await tester.startGesture(
      tester.getCenter(cardFinder(card)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(3, 2));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pump(kDoubleTapTimeout);
    await harness.settle(tester);

    expectMenuShown();
    expect(tester.getRect(cardFinder(card)), before);
    expect(tester.getRect(cardFinder(other)), otherBefore);
    expect(selection(tester), isA<NothingSelected>());
    final saved = await savedCard(tester, card);
    expect((saved.x, saved.y), (card.x, card.y));

    await harness.dispose(tester);
  });

  group('开始拖动后停住也不弹菜单', () {
    for (final (kind, distance) in [
      (PointerDeviceKind.touch, 60.0),
      // 鼠标的拖动判定距离比长按允许的移动范围小得多，挪一点就是拖动。
      (PointerDeviceKind.mouse, 10.0),
    ]) {
      testWidgets('${kind.name}：拖动 $distance 后停住 700ms', (tester) async {
        final card = await seedCard(tester);
        await harness.launch(tester);
        final before = tester.getRect(cardFinder(card));

        final gesture = await tester.startGesture(
          tester.getCenter(cardFinder(card)),
          kind: kind,
        );
        await gesture.moveBy(Offset(distance / 2, 0));
        await gesture.moveBy(Offset(distance / 2, 0));
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('改颜色'), findsNothing);
        await gesture.up();
        await tester.pump(kDoubleTapTimeout);
        await harness.settle(tester);

        expect(find.text('改颜色'), findsNothing);
        expect(
          tester.getRect(cardFinder(card)),
          before.shift(Offset(distance, 0)),
        );

        await harness.dispose(tester);
      });
    }
  });

  group('改颜色', () {
    testWidgets('色板有 8 种预设色和「自定义」', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      await chooseFromMenu(tester, card, '改颜色');

      for (final name in ['淡黄', '淡橙', '淡粉', '淡紫', '淡蓝', '淡绿', '淡灰', '白']) {
        expect(find.byTooltip(name), findsOneWidget, reason: name);
      }
      expect(find.text('自定义…'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('选预设色后卡片立即变色、色板关闭，重新打开数据库后仍然是这个颜色', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      await chooseFromMenu(tester, card, '改颜色');
      await tester.tap(find.byTooltip('淡蓝'));
      await harness.settle(tester);

      expect(shownColor(tester, card), Color(preset('淡蓝')));
      expect(find.byTooltip('淡蓝'), findsNothing);
      expect((await savedCard(tester, card)).colorArgb, preset('淡蓝'));

      await harness.dispose(tester);
    });

    testWidgets('保存颜色失败时提示「保存失败，请重试」，界面和存储里都还是原来的颜色', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      harness.failWrites = true;

      await chooseFromMenu(tester, card, '改颜色');
      await tester.tap(find.byTooltip('淡蓝'));
      await harness.settle(tester);

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(shownColor(tester, card), Color(card.colorArgb));
      expect((await savedCard(tester, card)).colorArgb, card.colorArgb);

      await harness.dispose(tester);
    });

    testWidgets('自定义颜色点「确定」后卡片变成这个颜色并保存', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      await chooseFromMenu(tester, card, '改颜色');
      await pickCustomColor(tester, darkBlue);
      await tester.tap(find.text('确定'));
      await harness.settle(tester);

      expect(find.byType(ColorPicker), findsNothing);
      expect(shownColor(tester, card), darkBlue);
      expect((await savedCard(tester, card)).colorArgb, darkBlue.toARGB32());

      await harness.dispose(tester);
    });

    testWidgets('自定义颜色点「取消」后关闭色板，颜色不变', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      await chooseFromMenu(tester, card, '改颜色');
      await pickCustomColor(tester, darkBlue);
      await tester.tap(find.text('取消'));
      await harness.settle(tester);

      expect(find.byType(ColorPicker), findsNothing);
      expect(find.byTooltip('淡蓝'), findsNothing);
      expect(shownColor(tester, card), Color(card.colorArgb));
      expect((await savedCard(tester, card)).colorArgb, card.colorArgb);

      await harness.dispose(tester);
    });
  });

  group('文字颜色跟着背景切换黑白（AC-10）', () {
    testWidgets('浅色背景上标题和备注是近黑色', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      expect(titleColor(tester, card), const Color(CardColors.darkText));

      await harness.dispose(tester);
    });

    testWidgets('改成深色背景后，标题、备注和编辑框里的文字都变白', (tester) async {
      final card = await harness.seed(tester, (service) async {
        final card = await service.createCard(
          harness.today,
          title: '买牛奶',
          x: 40,
          y: 60,
        );
        await service.updateCardContent(card.id, title: '买牛奶', note: '两盒');
        return card;
      });
      await harness.launch(tester);
      const white = Color(CardColors.lightText);

      await chooseFromMenu(tester, card, '改颜色');
      await pickCustomColor(tester, darkBlue);
      await tester.tap(find.text('确定'));
      await harness.settle(tester);

      expect(titleColor(tester, card), white);
      final note = tester.widget<Text>(
        find.descendant(of: cardFinder(card), matching: find.text('两盒')),
      );
      expect(note.style?.color?.withValues(alpha: 1), white);

      await chooseFromMenu(tester, card, '编辑');
      expect(find.byType(TextField), findsNWidgets(2));
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.style?.color, white);
      }

      await harness.dispose(tester);
    });
  });

  group('编辑', () {
    testWidgets('菜单里点编辑，进入这张卡片的编辑，改的内容能保存', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);

      await chooseFromMenu(tester, card, '编辑');
      expect(find.widgetWithText(TextField, '买牛奶'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买豆浆');
      await tester.tapAt(const Offset(700, 500));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);

      expect((await savedCard(tester, card)).title, '买豆浆');

      await harness.dispose(tester);
    });

    testWidgets('另一张卡片正在编辑时，菜单里点编辑：先保存那张，再编辑这张', (tester) async {
      final first = await seedCard(tester);
      final second = await seedCard(tester, title: '回邮件', x: 400);
      await harness.launch(tester);
      await chooseFromMenu(tester, first, '编辑');
      await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买豆浆');

      await chooseFromMenu(tester, second, '编辑');

      expect((await savedCard(tester, first)).title, '买豆浆');
      expect(find.widgetWithText(TextField, '回邮件'), findsOneWidget);
      expect(find.widgetWithText(TextField, '买豆浆'), findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('另一张卡片保存失败时，停在编辑那张卡片，改的内容不丢', (tester) async {
      final first = await seedCard(tester);
      final second = await seedCard(tester, title: '回邮件', x: 400);
      await harness.launch(tester);
      await chooseFromMenu(tester, first, '编辑');
      await tester.enterText(find.widgetWithText(TextField, '买牛奶'), '买豆浆');
      harness.failWrites = true;

      await chooseFromMenu(tester, second, '编辑');

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(find.widgetWithText(TextField, '买豆浆'), findsOneWidget);
      expect(find.widgetWithText(TextField, '回邮件'), findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('正在编辑的卡片长按、右键都不弹菜单', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await chooseFromMenu(tester, card, '编辑');
      // 按在卡片左下角的内边距上，不按在编辑框上，免得被编辑框抢去选文字。
      final padding =
          tester.getRect(cardFinder(card)).bottomLeft + const Offset(6, -6);

      await tester.longPressAt(padding);
      await harness.settle(tester);
      expect(find.text('改颜色'), findsNothing);

      await tester.tapAt(
        padding,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      expect(find.text('改颜色'), findsNothing);
      expect(find.widgetWithText(TextField, '买牛奶'), findsOneWidget);

      await harness.dispose(tester);
    });

    testWidgets('新建的草稿卡片长按不弹菜单', (tester) async {
      await harness.launch(tester);
      await tester.tap(find.byTooltip('新建卡片'));
      await harness.settle(tester);
      final title = tester.getRect(find.widgetWithText(TextField, '标题'));
      // 按在草稿卡片左下角的内边距上，不按在编辑框上。
      final padding =
          title.topLeft + const Offset(-6, TaskCard.defaultHeight - 12 - 6);

      await tester.longPressAt(padding);
      await harness.settle(tester);

      expect(find.text('改颜色'), findsNothing);
      expect(find.widgetWithText(TextField, '标题'), findsOneWidget);

      await harness.dispose(tester);
    });
  });

  group('删除', () {
    testWidgets('菜单里点删除，卡片从当天画布上消失，进了回收站', (tester) async {
      final card = await seedCard(tester);
      final other = await seedCard(tester, title: '回邮件', x: 400);
      await harness.launch(tester);

      await chooseFromMenu(tester, card, '删除');

      expect(cardFinder(card), findsNothing);
      expect(cardFinder(other), findsOneWidget);
      final board = await harness.readBoard(tester, harness.today);
      expect(board.cards.map((c) => c.id), [other.id]);
      expect(await trashedIds(tester), [card.id]);

      await harness.dispose(tester);
    });

    testWidgets('删除选中的卡片后取消选中', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await tester.tap(cardFinder(card));
      await tester.pump(kDoubleTapTimeout);
      await harness.settle(tester);
      expect(selection(tester), isA<CardSelected>());

      await chooseFromMenu(tester, card, '删除');

      expect(selection(tester), isA<NothingSelected>());

      await harness.dispose(tester);
    });

    testWidgets('删除失败时提示「保存失败，请重试」，卡片还在画布上', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      harness.failWrites = true;

      await chooseFromMenu(tester, card, '删除');

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(cardFinder(card), findsOneWidget);
      expect(await trashedIds(tester), isEmpty);

      await harness.dispose(tester);
    });
  });
}
