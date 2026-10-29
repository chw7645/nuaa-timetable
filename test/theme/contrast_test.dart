import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuaa_timetable/theme/app_semantic_colors.dart';

/// 课程配色的对比度契约。
///
/// 背景：浅色模式下课程底色曾用过 `#E3F0FD`（亮度 0.86），而画布是 `#F4F6F9`
/// （亮度 0.92）——两者对比只有 **1.07:1**，课程块在屏幕上几乎与背景融成一片。
/// 这里把阈值固化下来，任何"顺手调淡一点"的改动都会立刻失败。
void main() {
  /// WCAG 相对亮度对比度。
  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// 两色的色相环距离（0~180）。
  double hueDistance(Color a, Color b) {
    final d = (HSLColor.fromColor(a).hue - HSLColor.fromColor(b).hue).abs();
    return d > 180 ? 360 - d : d;
  }

  group('浅色模式', () {
    const semantic = AppSemanticColors.light;

    test('课程块与网格白底可分辨（≥1.30:1）', () {
      for (final color in semantic.courseBackgrounds) {
        final ratio = contrast(color, semantic.cardBackground);
        expect(ratio, greaterThanOrEqualTo(1.30),
            reason: '${_hex(color)} 与白底对比仅 ${ratio.toStringAsFixed(2)}:1，'
                '课程块会与背景糊在一起');
      }
    });

    test('课程块与画布灰底也要可分辨（≥1.18:1，兜底）', () {
      for (final color in semantic.courseBackgrounds) {
        final ratio = contrast(color, semantic.canvas);
        expect(ratio, greaterThanOrEqualTo(1.18),
            reason: '${_hex(color)} 与画布对比 ${ratio.toStringAsFixed(2)}:1');
      }
    });

    test('课程文字与课程底色高对比（≥7:1，WCAG AAA 正文）', () {
      for (final color in semantic.courseBackgrounds) {
        final ratio = contrast(semantic.courseForeground, color);
        expect(ratio, greaterThanOrEqualTo(7.0),
            reason: '${_hex(color)} 上的文字对比 ${ratio.toStringAsFixed(1)}:1');
      }
    });

    test('相邻索引的两门课不撞色（色相差 ≥25°）', () {
      final list = semantic.courseBackgrounds;
      for (var i = 0; i < list.length; i++) {
        final d = hueDistance(list[i], list[(i + 1) % list.length]);
        expect(d, greaterThanOrEqualTo(25),
            reason: '索引 $i 与 ${(i + 1) % list.length} 色相仅差 '
                '${d.toStringAsFixed(0)}°，同屏出现会分不清');
      }
    });

    test('课程强调色在浅底上清晰（≥2.5:1）', () {
      for (var i = 0; i < semantic.courseBackgrounds.length; i++) {
        final accent = semantic.courseAccentAt(i);
        expect(contrast(accent, semantic.cardBackground),
            greaterThanOrEqualTo(2.5),
            reason: '第 $i 个课程色条太淡，左侧色条会看不见');
      }
    });
  });

  group('深色模式', () {
    const semantic = AppSemanticColors.dark;

    test('课程块与卡片底可分辨（≥1.35:1）', () {
      for (final color in semantic.courseBackgrounds) {
        final ratio = contrast(color, semantic.cardBackground);
        expect(ratio, greaterThanOrEqualTo(1.35),
            reason: '${_hex(color)} 与深色底对比 ${ratio.toStringAsFixed(2)}:1');
      }
    });

    test('课程文字与课程底色高对比（≥7:1）', () {
      for (final color in semantic.courseBackgrounds) {
        final ratio = contrast(semantic.courseForeground, color);
        expect(ratio, greaterThanOrEqualTo(7.0),
            reason: '${_hex(color)} 上的文字对比 ${ratio.toStringAsFixed(1)}:1');
      }
    });

    test('两套调色板数量一致，便于按索引取色', () {
      expect(AppSemanticColors.dark.courseBackgrounds.length,
          AppSemanticColors.light.courseBackgrounds.length);
    });
  });

  group('中性色', () {
    test('浅色正文与画布对比 ≥ 12:1', () {
      expect(contrast(AppSemanticColors.light.textPrimary,
              AppSemanticColors.light.canvas),
          greaterThanOrEqualTo(12.0));
    });

    test('深色正文与卡片底对比 ≥ 10:1', () {
      expect(contrast(AppSemanticColors.dark.textPrimary,
              AppSemanticColors.dark.cardBackground),
          greaterThanOrEqualTo(10.0));
    });

    test('网格线在白底上可见但不喧宾夺主', () {
      final ratio = contrast(
          AppSemanticColors.light.gridLine, AppSemanticColors.light.cardBackground);
      expect(ratio, greaterThanOrEqualTo(1.10));
      expect(ratio, lessThanOrEqualTo(1.6));
    });
  });
}

String _hex(Color color) =>
    '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
