import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';
import 'package:my_personal_use_app/planner/task_card.dart';

import 'board_harness.dart';

/// 深色主题跟随系统切换（#65、AC-52）。
void main() {
  late BoardHarness harness;

  setUp(() => harness = BoardHarness());

  /// 页面现在用的主题。
  ThemeData pageTheme(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(BoardCanvas)));

  /// 页面现在的背景色：Scaffold 不单独设背景色，用主题的。
  Color pageBackground(WidgetTester tester) =>
      pageTheme(tester).scaffoldBackgroundColor;

  void expectDarkPage(WidgetTester tester) {
    expect(pageTheme(tester).brightness, Brightness.dark);
    expect(pageBackground(tester).computeLuminance(), lessThan(0.1));
  }

  void expectLightPage(WidgetTester tester) {
    expect(pageTheme(tester).brightness, Brightness.light);
    expect(pageBackground(tester), const Color(0xFFF5F5F7));
  }

  /// 把系统切到 [brightness]，等主题切换的动画播完。
  Future<void> switchSystemTo(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    await harness.settle(tester);
  }

  testWidgets('系统是深色时用深色主题', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await harness.launch(tester);

    expectDarkPage(tester);

    await harness.dispose(tester);
  });

  testWidgets('App 运行中系统在深浅之间切换，主题跟着切换，不用重启', (tester) async {
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await harness.launch(tester);
    expectLightPage(tester);

    await switchSystemTo(tester, Brightness.dark);
    expectDarkPage(tester);

    await switchSystemTo(tester, Brightness.light);
    expectLightPage(tester);

    await harness.dispose(tester);
  });

  group('深色下卡片的颜色不变', () {
    Finder cardFinder(TaskCard card) =>
        find.byKey(BoardCanvas.cardKey(card.id));

    /// 画布上这张卡片现在的底色。
    Color shownColor(WidgetTester tester, TaskCard card) {
      final frame = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: cardFinder(card),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      return (frame.decoration as BoxDecoration).color!;
    }

    /// 卡片标题现在的文字颜色。
    Color? titleColor(WidgetTester tester, TaskCard card) => tester
        .widget<Text>(
          find.descendant(
            of: cardFinder(card),
            matching: find.text(card.title),
          ),
        )
        .style
        ?.color;

    testWidgets('浅色便签仍然显示保存的颜色，文字仍然是近黑色', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final card = await harness.seed(
        tester,
        (service) => service.createCard(
          harness.today,
          title: '买牛奶',
          x: 40,
          y: 60,
          colorArgb: 0xFFFFF0B8,
        ),
      );
      await harness.launch(tester);
      expectDarkPage(tester);

      expect(shownColor(tester, card), const Color(0xFFFFF0B8));
      expect(titleColor(tester, card), const Color(0xFF1C1C1E));
      final saved = (await harness.readBoard(
        tester,
        harness.today,
      )).cards.single;
      expect(saved.colorArgb, 0xFFFFF0B8);

      await harness.dispose(tester);
    });

    testWidgets('深色的卡片在深色主题下文字仍然是白色', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final card = await harness.seed(
        tester,
        (service) => service.createCard(
          harness.today,
          title: '交报告',
          x: 40,
          y: 60,
          colorArgb: 0xFF0D47A1,
        ),
      );
      await harness.launch(tester);

      expect(shownColor(tester, card), const Color(0xFF0D47A1));
      expect(titleColor(tester, card), const Color(0xFFFFFFFF));

      await harness.dispose(tester);
    });
  });
}
