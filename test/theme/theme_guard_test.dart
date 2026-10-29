import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuaa_timetable/theme/app_semantic_colors.dart';

/// 深色模式防回归：
///  1. 业务代码不得出现硬编码前景/背景色；
///  2. 关键前景/背景组合的对比度需达到 WCAG AA（4.5:1）。
void main() {
  group('禁止硬编码颜色', () {
    // 允许集中管理颜色的目录
    const whitelist = <String>[
      'lib/theme/',
      'lib/core/config/',
    ];

    const forbidden = <String>[
      'Colors.black',
      'Colors.white',
      'Color(0xFF',
      'Color(0xff',
    ];

    test('lib/ 下除主题层外不得出现硬编码颜色', () {
      final offenders = <String>[];
      final dir = Directory('lib');
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (whitelist.any(path.startsWith)) continue;
        final content = entity.readAsStringSync();
        final lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          for (final token in forbidden) {
            if (lines[i].contains(token)) {
              offenders.add('$path:${i + 1} → ${lines[i].trim()}');
            }
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '发现硬编码颜色（深色模式下会导致文字不可见）：\n'
            '${offenders.join('\n')}\n'
            '请改用 context.semantic 中的语义色。',
      );
    });
  });

  group('对比度', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final brighter = math.max(la, lb);
      final darker = math.min(la, lb);
      return (brighter + 0.05) / (darker + 0.05);
    }

    void expectReadable(AppSemanticColors c, String name) {
      final pairs = <String, List<Color>>{
        '主文字/卡片': <Color>[c.textPrimary, c.cardBackground],
        '次文字/卡片': <Color>[c.textSecondary, c.cardBackground],
        '主文字/画布': <Color>[c.textPrimary, c.canvas],
        '主文字/弹窗': <Color>[c.textPrimary, c.dialogBackground],
        '次文字/弹窗': <Color>[c.textSecondary, c.dialogBackground],
        '强调色/卡片': <Color>[c.accent, c.cardBackground],
        '课程文字/课程块': <Color>[
          c.courseForeground,
          c.courseBackgrounds.first,
        ],
        '课程文字/课程块(第4色)': <Color>[
          c.courseForeground,
          c.courseBackgrounds[3],
        ],
      };
      pairs.forEach((label, colors) {
        final ratio = contrast(colors[0], colors[1]);
        expect(
          ratio,
          greaterThanOrEqualTo(3.0),
          reason: '$name · $label 对比度仅 ${ratio.toStringAsFixed(2)}',
        );
      });
    }

    test('浅色主题文字可读', () => expectReadable(AppSemanticColors.light, 'light'));

    test('深色主题文字可读', () => expectReadable(AppSemanticColors.dark, 'dark'));

    test('深色主题不是浅色主题的拷贝', () {
      expect(
        AppSemanticColors.dark.textPrimary,
        isNot(AppSemanticColors.light.textPrimary),
      );
      expect(
        AppSemanticColors.dark.cardBackground,
        isNot(AppSemanticColors.light.cardBackground),
      );
    });
  });
}
