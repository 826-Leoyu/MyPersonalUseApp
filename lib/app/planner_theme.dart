import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// 按 `docs/ui/` 参考图定的视觉规范（spec「视觉规范」）：灰白背景加淡淡的
/// 点阵、白色内容区、系统字体（不指定字体）、大圆角、几乎不用阴影、金黄色强调色。颜色、
/// 圆角、间距都在这里定义，组件里不写死。
abstract final class PlannerTheme {
  /// 页面和画布的背景。
  static const background = Color(0xFFF5F5F7);

  /// 画布背景点阵的点，见 `DotGrid`。
  static const dot = Color(0xFFD1D1D6);

  /// 点阵里点的间距（画布坐标），跟着画布缩放。
  static const dotSpacing = 24.0;

  /// 点阵里点的半径（屏幕上的逻辑像素），缩放时不变，缩小时点不会糊成一片。
  static const dotRadius = 1.25;

  /// 内容表面：日期抽屉、对话框、菜单。
  static const surface = Color(0xFFFFFFFF);

  /// 日期侧栏的面板，比背景深一级的灰。
  static const panel = Color(0xFFECECF0);

  /// 主文字。
  static const text = Color(0xFF1C1C1E);

  /// 次要文字：星期、周的日期范围、为 0 的未完成数。
  static const secondaryText = Color(0xFF8E8E93);

  /// 强调色：新增按钮、选中的卡片和连线、今天的标记。
  static const accent = Color(0xFFD9A441);

  /// 浅色表面上强调色的小字和文字按钮：[accent] 本身做小字对比度太低。
  static const accentText = Color(0xFF9A6A12);

  /// 强调色上的文字和图标。
  static const onAccent = Color(0xFFFFFFFF);

  /// 日期列表里选中那一天的米色高亮。
  static const selectedDay = Color(0xFFEFE2C8);

  /// 低对比的分隔线。
  static const divider = Color(0xFFE5E5EA);

  /// 颜色选择里每个色块的细边框，浅色的色块也看得出边界。
  static const swatchBorder = Color(0x1F000000);

  /// 「完成」投放区的颜色和它上面的文字。
  static const completeZone = Color(0xFF4CAF50);
  static const completeZoneText = Color(0xFF2E7D32);

  /// 「回收站」投放区的颜色和它上面的文字。
  static const trashZone = Color(0xFFF44336);
  static const trashZoneText = Color(0xFFC62828);

  /// 指针移到投放区上、投放区变实心时的文字和图标。
  static const onZone = Color(0xFFFFFFFF);

  /// 连线的颜色：半透明的深灰（主文字的 60%）。选中时用 [accent]。
  static const linkColor = Color(0x991C1C1E);

  /// 卡片的圆角。
  static const cardRadius = BorderRadius.all(Radius.circular(18));

  /// 侧栏、面板的圆角。
  static const panelRadius = BorderRadius.all(Radius.circular(20));

  /// 日期列表里一行的圆角。
  static const rowRadius = BorderRadius.all(Radius.circular(12));

  /// 拖动卡片时底部「完成」「回收站」投放区的圆角。
  static const zoneRadius = BorderRadius.all(Radius.circular(16));

  /// 「顺延」这类小标签的圆角。
  static const tagRadius = BorderRadius.all(Radius.circular(4));

  /// 间距，都是 4 的倍数（小标签的上下内边距除外，见 [tagPadding]）。
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;

  /// 卡片的内边距。
  static const cardPadding = EdgeInsets.symmetric(
    horizontal: space4,
    vertical: space3,
  );

  /// 「顺延」这类小标签的内边距。上下只留 1，不按 4 的倍数，标签才够矮。
  static const tagPadding = EdgeInsets.symmetric(
    horizontal: space1,
    vertical: 1,
  );

  /// 选中的卡片的描边宽度。平时不用阴影，选中靠描边区分。
  static const selectedBorderWidth = 2.0;

  /// 拖动中的卡片、剪刀这类浮起来的东西的轻微阴影。
  static const liftShadow = [
    BoxShadow(color: Color(0x24000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// 卡片外面一圈强调色的光晕：[accent] 的 60%。
  static const glowShadow = [
    BoxShadow(color: Color(0x99D9A441), blurRadius: 16, spreadRadius: 2),
  ];

  /// 浅色主题。
  static ThemeData light() {
    final base = FlexThemeData.light(
      colors: FlexSchemeColor.from(primary: accent),
      surface: surface,
      scaffoldBackground: background,
      appBarBackground: background,
      appBarElevation: 0,
      subThemesData: const FlexSubThemesData(
        defaultRadius: 16,
        appBarScrolledUnderElevation: 0,
        appBarCenterTitle: true,
        drawerBackgroundSchemeColor: SchemeColor.surface,
        drawerElevation: 0,
        dialogElevation: 0,
        fabUseShape: true,
        fabAlwaysCircular: true,
        fabSchemeColor: SchemeColor.primary,
      ),
    );
    return base.copyWith(
      dividerColor: divider,
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
      appBarTheme: base.appBarTheme.copyWith(
        foregroundColor: text,
        shape: const Border(bottom: BorderSide(color: divider)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accentText),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: accent,
        foregroundColor: onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 2,
        highlightElevation: 0,
      ),
    );
  }
}
