import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/board/board_canvas.dart';

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

  testWidgets('系统是深色时用深色主题', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    await harness.launch(tester);

    expectDarkPage(tester);

    await harness.dispose(tester);
  });
}
