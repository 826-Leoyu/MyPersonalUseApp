import 'package:flutter_test/flutter_test.dart';
import 'package:my_personal_use_app/planner/card_colors.dart';

void main() {
  group('文字颜色按背景相对亮度切换黑白（AC-10）', () {
    test('白色背景用近黑色', () {
      expect(cardTextColorArgb(0xFFFFFFFF), CardColors.darkText);
    });

    test('黑色背景用白色', () {
      expect(cardTextColorArgb(0xFF000000), CardColors.lightText);
    });

    test('深蓝背景用白色', () {
      expect(cardTextColorArgb(0xFF1F3A93), CardColors.lightText);
    });

    test('默认的淡黄背景用近黑色', () {
      expect(cardTextColorArgb(0xFFFFF3B0), CardColors.darkText);
    });

    test('亮度刚过 0.5 的灰（约 0.503）用近黑色', () {
      expect(cardTextColorArgb(0xFFBCBCBC), CardColors.darkText);
    });

    test('亮度刚不到 0.5 的灰（约 0.497）用白色', () {
      expect(cardTextColorArgb(0xFFBBBBBB), CardColors.lightText);
    });
  });
}
