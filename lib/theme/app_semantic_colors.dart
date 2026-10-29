import 'package:flutter/material.dart';

/// 业务语义色：所有界面取色的唯一来源。
///
/// 页面与组件**不得**直接写 `Colors.black` / `Colors.white` / `Color(0x…)`，
/// 否则会在深色模式下出现"深底深字"或"浅底白字"的不可读问题。
/// 该约束由 `test/theme/no_hardcoded_colors_test.dart` 静态校验。
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.canvas,
    required this.cardBackground,
    required this.cardBorder,
    required this.dialogBackground,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.gridLine,
    required this.periodColumn,
    required this.todayHighlight,
    required this.accent,
    required this.courseBackgrounds,
    required this.courseForeground,
    required this.danger,
  });

  final Color canvas;
  final Color cardBackground;
  final Color cardBorder;
  final Color dialogBackground;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color gridLine;
  final Color periodColumn;
  final Color todayHighlight;
  final Color accent;
  final List<Color> courseBackgrounds;
  final Color courseForeground;
  final Color danger;

  static const AppSemanticColors light = AppSemanticColors(
    canvas: Color(0xFFF4F6F9),
    cardBackground: Color(0xFFFFFFFF),
    cardBorder: Color(0xFFE3E6EB),
    dialogBackground: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A1C1F),
    textSecondary: Color(0xFF5F6672),
    textTertiary: Color(0xFF8A919C),
    gridLine: Color(0xFFEDEFF2),
    periodColumn: Color(0xFFF4F7FB),
    todayHighlight: Color(0x0A2F6FD0),
    accent: Color(0xFF2F6FD0),
    // 每个色都压到同一亮度（L≈0.74）：对白底 1.33:1、对正文 11:1。
    // 相邻索引的色相相差 ≥45°，避免同屏两门课撞色。
    courseBackgrounds: <Color>[
      Color(0xFFCDE2F9), // 蓝 H212
      Color(0xFFBCEACF), // 绿 H145
      Color(0xFFE5DBF6), // 紫 H262
      Color(0xFFBFE6EC), // 青 H188
      Color(0xFFF9DABB), // 暖橙 H30
      Color(0xFFD6E5BB), // 黄绿 H82
      Color(0xFFF3D7EE), // 粉紫 H310
      Color(0xFFF1DADC), // 红 H355
    ],
    courseForeground: Color(0xFF1F2937),
    danger: Color(0xFFD93A3A),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    canvas: Color(0xFF111418),
    cardBackground: Color(0xFF1C2027),
    cardBorder: Color(0xFF2A2F37),
    dialogBackground: Color(0xFF232830),
    textPrimary: Color(0xFFECEDEF),
    textSecondary: Color(0xFFA8AEB8),
    textTertiary: Color(0xFF7C838C),
    gridLine: Color(0xFF262B33),
    periodColumn: Color(0xFF191D23),
    todayHighlight:Color(0x147FB2FF),
    accent: Color(0xFF7FB2FF),
    // 同样统一亮度（L≈0.048）：对卡片底 1.52:1、对正文 9:1。
    courseBackgrounds: <Color>[
      Color(0xFF193F6A), // 蓝 H212
      Color(0xFF19462C), // 绿 H145
      Color(0xFF4B2887), // 紫 H262
      Color(0xFF19444A), // 青 H188
      Color(0xFF583615), // 暖橙 H30
      Color(0xFF35431C), // 黄绿 H82
      Color(0xFF65255A), // 粉紫 H310
      Color(0xFF662B30), // 红 H355
    ],
    courseForeground: Color(0xFFE9EDF3),
    danger: Color(0xFFFF7A7A),
  );

  bool get isDark => courseForeground.computeLuminance() > 0.5;

  /// 按主题色生成语义色：中性色沿用固定调色板，仅替换强调色与高亮。
  ///
  /// 深色模式需要提亮种子色，否则强调色在深底上对比度不足。
  static AppSemanticColors forBrightness(
    Brightness brightness, {
    Color? seed,
  }) {
    final base = brightness == Brightness.dark ? dark : light;
    if (seed == null) return base;
    final accent = _toneFor(seed, brightness);
    return base.copyWith(
      accent: accent,
      todayHighlight: accent.withValues(
        alpha: brightness == Brightness.dark ? 0.10 : 0.05,
      ),
    );
  }

  /// 实心色块（如主题色圆点）上的前景色：深色底用白，浅色底用黑。
  static Color onColor(Color background) =>
      background.computeLuminance() > 0.5
          ? const Color(0xFF1A1C1F)
          : const Color(0xFFFFFFFF);

  static Color _toneFor(Color seed, Brightness brightness) {
    final hsl = HSLColor.fromColor(seed);
    if (brightness == Brightness.dark) {
      return hsl
          .withLightness(hsl.lightness.clamp(0.0, 0.55) + 0.22)
          .withSaturation((hsl.saturation * 0.9).clamp(0.35, 1.0))
          .toColor();
    }
    return hsl.withLightness(hsl.lightness.clamp(0.0, 0.55)).toColor();
  }

  Color courseBackgroundAt(int index) =>
      courseBackgrounds[index.abs() % courseBackgrounds.length];

  /// 课程强调色：与课程底色同色相，但压到统一的目标感知亮度。
  ///
  /// 用于今日卡与列表卡左侧的色条。注意**不能**用固定的 HSL lightness：
  /// 黄绿色相在同样 lightness 下感知亮度高得多，色条会糊在浅底上看不见
  /// （实测 hsl 亮度 0.62 的黄绿只有 1.8:1）。这里按 `computeLuminance()`
  /// 迭代逼近目标值，保证 8 个色相的色条浓淡一致。
  Color courseAccentAt(int index) {
    final hsl = HSLColor.fromColor(courseBackgroundAt(index));
    // 浅色底上目标 ~3:1，深色底上 ~3.4:1，都能清晰看见又不刺眼。
    final target = isDark ? 0.18 : 0.30;
    var lightness = hsl.lightness;
    var candidate = hsl.toColor();
    for (var i = 0; i < 40; i++) {
      candidate = hsl.withLightness(lightness).toColor();
      final lum = candidate.computeLuminance();
      if ((lum - target).abs() < 0.015) break;
      lightness += lum > target ? -0.015 : 0.015;
      lightness = lightness.clamp(0.05, 0.95);
    }
    return candidate;
  }

  @override
  AppSemanticColors copyWith({
    Color? canvas,
    Color? cardBackground,
    Color? cardBorder,
    Color? dialogBackground,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? gridLine,
    Color? periodColumn,
    Color? todayHighlight,
    Color? accent,
    List<Color>? courseBackgrounds,
    Color? courseForeground,
    Color? danger,
  }) {
    return AppSemanticColors(
      canvas: canvas ?? this.canvas,
      cardBackground: cardBackground ?? this.cardBackground,
      cardBorder: cardBorder ?? this.cardBorder,
      dialogBackground: dialogBackground ?? this.dialogBackground,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      gridLine: gridLine ?? this.gridLine,
      periodColumn: periodColumn ?? this.periodColumn,
      todayHighlight: todayHighlight ?? this.todayHighlight,
      accent: accent ?? this.accent,
      courseBackgrounds: courseBackgrounds ?? this.courseBackgrounds,
      courseForeground: courseForeground ?? this.courseForeground,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppSemanticColors(
      canvas: mix(canvas, other.canvas),
      cardBackground: mix(cardBackground, other.cardBackground),
      cardBorder: mix(cardBorder, other.cardBorder),
      dialogBackground: mix(dialogBackground, other.dialogBackground),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      textTertiary: mix(textTertiary, other.textTertiary),
      gridLine: mix(gridLine, other.gridLine),
      periodColumn: mix(periodColumn, other.periodColumn),
      todayHighlight: mix(todayHighlight, other.todayHighlight),
      accent: mix(accent, other.accent),
      courseBackgrounds: List<Color>.generate(
        courseBackgrounds.length,
        (i) => mix(
          courseBackgrounds[i],
          other.courseBackgrounds[i % other.courseBackgrounds.length],
        ),
      ),
      courseForeground: mix(courseForeground, other.courseForeground),
      danger: mix(danger, other.danger),
    );
  }
}

extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;

  ColorScheme get scheme => Theme.of(this).colorScheme;

  TextTheme get texts => Theme.of(this).textTheme;
}
