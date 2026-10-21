import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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

    testWidgets('正在编辑的卡片长按不弹菜单', (tester) async {
      final card = await seedCard(tester);
      await harness.launch(tester);
      await chooseFromMenu(tester, card, '编辑');

      await tester.longPress(cardFinder(card), warnIfMissed: false);
      await harness.settle(tester);

      expect(find.text('改颜色'), findsNothing);

      await harness.dispose(tester);
    });

    testWidgets('新建的草稿卡片长按不弹菜单', (tester) async {
      await harness.launch(tester);
      await tester.tap(find.byTooltip('新建卡片'));
      await harness.settle(tester);
      final draft = tester.getRect(find.widgetWithText(TextField, '标题'));

      await tester.longPressAt(draft.center + const Offset(0, 30));
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
