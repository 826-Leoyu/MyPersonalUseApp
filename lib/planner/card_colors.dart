import 'dart:math' as math;

import 'task_card.dart';

/// 卡片颜色：预设色板，以及按背景决定文字颜色。颜色都是 ARGB 整数。
abstract final class CardColors {
  /// 浅色背景上的文字：近黑色。
  static const darkText = 0xFF1C1C1E;

  /// 深色背景上的文字：白色。
  static const lightText = 0xFFFFFFFF;

  /// 色板里的 8 种预设颜色，第一种是新卡片的默认颜色。色值是暂定的。
  static const presets = <({String name, int argb})>[
    (name: '淡黄', argb: TaskCard.defaultColorArgb),
    (name: '淡橙', argb: 0xFFFFD8A8),
    (name: '淡粉', argb: 0xFFFFCCD9),
    (name: '淡紫', argb: 0xFFE2D5F8),
    (name: '淡蓝', argb: 0xFFCCE4FF),
    (name: '淡绿', argb: 0xFFD3F0C8),
    (name: '淡灰', argb: 0xFFE5E5EA),
    (name: '白', argb: 0xFFFFFFFF),
  ];
}

/// 背景 [backgroundArgb] 上的文字颜色：背景的相对亮度大于 0.5 时用近黑色，
/// 否则用白色。透明度不参与计算。
int cardTextColorArgb(int backgroundArgb) =>
    _relativeLuminance(backgroundArgb) > 0.5
    ? CardColors.darkText
    : CardColors.lightText;

/// sRGB 颜色的相对亮度（WCAG 的定义），0 是黑，1 是白。
double _relativeLuminance(int argb) {
  double channel(int shift) {
    final value = ((argb >> shift) & 0xFF) / 255;
    return value <= 0.04045
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}
