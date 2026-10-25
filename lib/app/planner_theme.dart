import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

/// 按 `docs/ui/` 参考图定的视觉规范（spec「视觉规范」）：灰白背景加淡淡的
/// 点阵、白色内容区、系统字体（不指定字体）、大圆角、几乎不用阴影、金黄色强调色。颜色
/// 在 [PlannerColors] 里，分浅色和深色两套；圆角、间距这些和深浅无关的在这里。
/// 组件里不写死。
abstract final class PlannerTheme {
  /// 点阵里点的间距（画布坐标），跟着画布缩放。
  static const dotSpacing = 24.0;

  /// 点阵里点的半径（屏幕上的逻辑像素），缩放时不变，缩小时点不会糊成一片。
  static const dotRadius = 1.25;

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

  /// 卡片外面一圈强调色的光晕：强调色 [accent] 的 60%。
  static List<BoxShadow> glowShadow(Color accent) => [
    BoxShadow(
      color: accent.withValues(alpha: 0.6),
      blurRadius: 16,
      spreadRadius: 2,
    ),
  ];

  /// 浅色主题。
  static ThemeData light() => _theme(Brightness.light, PlannerColors.light);

  /// 深色主题：和浅色同样的层次（背景、内容表面、强调色），跟随系统切换。
  static ThemeData dark() => _theme(Brightness.dark, PlannerColors.dark);

  static ThemeData _theme(Brightness brightness, PlannerColors colors) {
    const subThemes = FlexSubThemesData(
      defaultRadius: 16,
      appBarScrolledUnderElevation: 0,
      appBarCenterTitle: true,
      drawerElevation: 0,
      dialogElevation: 0,
      fabUseShape: true,
      fabAlwaysCircular: true,
      fabSchemeColor: SchemeColor.primary,
    );
    final flexTheme = brightness == Brightness.light
        ? FlexThemeData.light
        : FlexThemeData.dark;
    final base = flexTheme(
      colors: FlexSchemeColor.from(
        primary: colors.accent,
        brightness: brightness,
      ),
      surface: colors.surface,
      scaffoldBackground: colors.background,
      appBarBackground: colors.background,
      appBarElevation: 0,
      subThemesData: subThemes,
    );
    return base.copyWith(
      extensions: [colors],
      dividerColor: colors.divider,
      dividerTheme: DividerThemeData(color: colors.divider, thickness: 1),
      appBarTheme: base.appBarTheme.copyWith(
        foregroundColor: colors.primaryText,
        shape: Border(bottom: BorderSide(color: colors.divider)),
      ),
      // 窄屏的日期抽屉和宽屏的日期侧栏一样，用比背景深一级的面板色。
      drawerTheme: base.drawerTheme.copyWith(backgroundColor: colors.panel),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.accentText),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 2,
        highlightElevation: 0,
      ),
    );
  }
}

/// 主题里的颜色，分浅色 [light] 和深色 [dark] 两套，跟着系统切换。组件用
/// [PlannerColors.of] 取。卡片的颜色不在这里：深色下便签仍然是浅色。
@immutable
class PlannerColors extends ThemeExtension<PlannerColors> {
  const PlannerColors({
    required this.background,
    required this.gridDot,
    required this.surface,
    required this.panel,
    required this.primaryText,
    required this.secondaryText,
    required this.accent,
    required this.accentText,
    required this.onAccent,
    required this.selectedDay,
    required this.divider,
    required this.swatchBorder,
    required this.completeZone,
    required this.completeZoneText,
    required this.trashZone,
    required this.trashZoneText,
    required this.onZone,
    required this.link,
  });

  /// 浅色：`docs/ui/` 参考图的颜色（spec「视觉规范」）。
  static const light = PlannerColors(
    background: Color(0xFFF5F5F7),
    gridDot: Color(0xFFD1D1D6),
    surface: Color(0xFFFFFFFF),
    panel: Color(0xFFECECF0),
    primaryText: Color(0xFF1C1C1E),
    secondaryText: Color(0xFF8E8E93),
    accent: Color(0xFFD9A441),
    accentText: Color(0xFF9A6A12),
    onAccent: Color(0xFFFFFFFF),
    selectedDay: Color(0xFFEFE2C8),
    divider: Color(0xFFE5E5EA),
    swatchBorder: Color(0x1F000000),
    completeZone: Color(0xFF4CAF50),
    completeZoneText: Color(0xFF2E7D32),
    trashZone: Color(0xFFF44336),
    trashZoneText: Color(0xFFC62828),
    onZone: Color(0xFFFFFFFF),
    link: Color(0x991C1C1E),
  );

  /// 深色：按浅色的层次推出来。背景最暗，侧栏面板、对话框依次亮一级；
  /// 强调色不变。
  static const dark = PlannerColors(
    background: Color(0xFF141416),
    gridDot: Color(0xFF333338),
    surface: Color(0xFF242427),
    panel: Color(0xFF1F1F22),
    primaryText: Color(0xFFF2F2F7),
    secondaryText: Color(0xFF98989F),
    accent: Color(0xFFD9A441),
    accentText: Color(0xFFE8BC62),
    onAccent: Color(0xFFFFFFFF),
    selectedDay: Color(0xFF4A3D24),
    divider: Color(0xFF2E2E32),
    swatchBorder: Color(0x33FFFFFF),
    completeZone: Color(0xFF4CAF50),
    completeZoneText: Color(0xFF81C784),
    trashZone: Color(0xFFF44336),
    trashZoneText: Color(0xFFEF9A9A),
    onZone: Color(0xFFFFFFFF),
    link: Color(0x99F2F2F7),
  );

  /// 当前主题的颜色。
  static PlannerColors of(BuildContext context) =>
      Theme.of(context).extension<PlannerColors>()!;

  /// 页面和画布的背景。
  final Color background;

  /// 画布背景点阵的点，见 `DotGrid`。
  final Color gridDot;

  /// 内容表面：对话框、菜单。
  final Color surface;

  /// 日期侧栏和日期抽屉的面板：浅色下比背景深一级的灰，深色下比背景亮
  /// 一级。
  final Color panel;

  /// 主文字。
  final Color primaryText;

  /// 次要文字：星期、周的日期范围、为 0 的未完成数。
  final Color secondaryText;

  /// 强调色：新增按钮、选中的卡片和连线、今天的标记。
  final Color accent;

  /// 强调色的小字和文字按钮：浅色表面上 [accent] 本身做小字对比度太低，
  /// 用深一点的金色；深色表面上用亮一点的。
  final Color accentText;

  /// 强调色上的文字和图标。
  final Color onAccent;

  /// 日期列表里选中那一天的高亮：浅色下是米色，深色下是暗金色。
  final Color selectedDay;

  /// 低对比的分隔线。
  final Color divider;

  /// 颜色选择里每个色块的细边框，和背景相近的色块也看得出边界。
  final Color swatchBorder;

  /// 「完成」投放区的颜色。
  final Color completeZone;

  /// 「完成」投放区上的文字。
  final Color completeZoneText;

  /// 「回收站」投放区的颜色。
  final Color trashZone;

  /// 「回收站」投放区上的文字。
  final Color trashZoneText;

  /// 指针移到投放区上、投放区变实心时的文字和图标。
  final Color onZone;

  /// 连线的颜色：半透明的主文字（60%）。选中时用 [accent]。
  final Color link;

  /// 没有用到改单个颜色的地方，不提供参数。
  @override
  PlannerColors copyWith() => this;

  @override
  PlannerColors lerp(PlannerColors? other, double t) {
    if (other == null) return this;
    Color mix(Color Function(PlannerColors c) pick) =>
        Color.lerp(pick(this), pick(other), t)!;
    return PlannerColors(
      background: mix((c) => c.background),
      gridDot: mix((c) => c.gridDot),
      surface: mix((c) => c.surface),
      panel: mix((c) => c.panel),
      primaryText: mix((c) => c.primaryText),
      secondaryText: mix((c) => c.secondaryText),
      accent: mix((c) => c.accent),
      accentText: mix((c) => c.accentText),
      onAccent: mix((c) => c.onAccent),
      selectedDay: mix((c) => c.selectedDay),
      divider: mix((c) => c.divider),
      swatchBorder: mix((c) => c.swatchBorder),
      completeZone: mix((c) => c.completeZone),
      completeZoneText: mix((c) => c.completeZoneText),
      trashZone: mix((c) => c.trashZone),
      trashZoneText: mix((c) => c.trashZoneText),
      onZone: mix((c) => c.onZone),
      link: mix((c) => c.link),
    );
  }
}
