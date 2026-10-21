import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// 仿 Apple 备忘录的主题：米白纸张背景、没有点阵、系统字体（不指定字体）、
/// 圆角卡片加轻微阴影。
abstract final class PlannerTheme {
  /// 米白纸张色，画布和页面的背景。
  static const paper = Color(0xFFFBF8F1);

  /// 强调色，取备忘录的琥珀黄。
  static const accent = Color(0xFFD9A400);

  /// 卡片的圆角。
  static const cardRadius = BorderRadius.all(Radius.circular(12));

  /// 卡片的轻微阴影。
  static const cardShadow = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// 浅色主题。深色模式不在 MVP 范围内。
  static ThemeData light() => FlexThemeData.light(
    colors: FlexSchemeColor.from(primary: accent),
    surface: paper,
    scaffoldBackground: paper,
    appBarBackground: paper,
    appBarElevation: 0,
    subThemesData: const FlexSubThemesData(
      defaultRadius: 12,
      appBarScrolledUnderElevation: 0,
    ),
  );
}
