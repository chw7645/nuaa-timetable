import 'package:flutter/material.dart';

import 'app_semantic_colors.dart';

/// 全应用唯一的主题来源。
///
/// 关键约束：`light()` 与 `dark()` 由同一份结构生成，只替换色值，
/// 避免"某处只配了浅色"导致的深色模式破功。
class AppTheme {
  AppTheme._();

  /// 默认主题色（南航蓝）。
  static const Color defaultSeed = Color(0xFF2F6FD0);

  static ThemeData light({Color seed = defaultSeed}) => _build(
        Brightness.light,
        AppSemanticColors.forBrightness(Brightness.light, seed: seed),
        seed,
      );

  static ThemeData dark({Color seed = defaultSeed}) => _build(
        Brightness.dark,
        AppSemanticColors.forBrightness(Brightness.dark, seed: seed),
        seed,
      );

  static ThemeData _build(
    Brightness brightness,
    AppSemanticColors semantic,
    Color seed,
  ) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(
      surface: semantic.canvas,
      onSurface: semantic.textPrimary,
      surfaceContainerHighest: semantic.cardBackground,
      surfaceContainerHigh: semantic.cardBackground,
      surfaceContainer: isDark ? const Color(0xFF191D23) : const Color(0xFFF0F2F5),
      primary: semantic.accent,
      onPrimary: isDark ? const Color(0xFF10233F) : const Color(0xFFFFFFFF),
      error: semantic.danger,
      outlineVariant: semantic.gridLine,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: semantic.canvas,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[semantic],
      textTheme: base.textTheme
          .apply(bodyColor: semantic.textPrimary, displayColor: semantic.textPrimary),
      dialogTheme: DialogThemeData(
        backgroundColor: semantic.dialogBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: base.textTheme.titleMedium?.copyWith(
          color: semantic.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: semantic.textSecondary,
          fontSize: 15,
          height: 1.55,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: semantic.canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: semantic.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: semantic.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      cardTheme: CardThemeData(
        color: semantic.cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: semantic.cardBorder),
        ),
      ),
      dividerTheme: DividerThemeData(color: semantic.gridLine, thickness: 1),
      listTileTheme: ListTileThemeData(
        iconColor: semantic.textSecondary,
        textColor: semantic.textPrimary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: semantic.accent,
          foregroundColor: isDark ? const Color(0xFF10233F) : const Color(0xFFFFFFFF),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: semantic.accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semantic.cardBackground,
        hintStyle: TextStyle(color: semantic.textTertiary),
        labelStyle: TextStyle(color: semantic.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: semantic.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: semantic.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: semantic.accent, width: 1.6),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFF2B323C) : const Color(0xFF2B323C),
        contentTextStyle: const TextStyle(color: Color(0xFFF2F4F7)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: semantic.cardBackground,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}
