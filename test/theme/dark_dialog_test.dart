import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuaa_timetable/data/local/prefs_store.dart';
import 'package:nuaa_timetable/features/settings/settings_page.dart';
import 'package:nuaa_timetable/state/app_controller.dart';
import 'package:nuaa_timetable/state/app_scope.dart';
import 'package:nuaa_timetable/theme/app_semantic_colors.dart';
import 'package:nuaa_timetable/theme/app_theme.dart';
import 'package:nuaa_timetable/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户反馈的核心缺陷回归：
/// 深色模式下"切换主题"提示弹窗的文字颜色过深、被深色背景遮挡。
void main() {
  Future<AppController> buildController() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await PrefsStore.open();
    final theme = ThemeController(prefs);
    await theme.setMode(ThemeMode.dark);
    return AppController(prefs: prefs, theme: theme);
  }

  Future<void> pumpSettings(WidgetTester tester, AppController controller) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: AppScope(controller: controller, child: const SettingsPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('深色模式下主题弹窗文字为浅色（可读）', (tester) async {
    final controller = await buildController();
    await pumpSettings(tester, controller);

    await tester.scrollUntilVisible(
      find.text('主题模式'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('主题模式'));
    await tester.pumpAndSettle();

    // 弹窗内的说明文案
    const description = '浅色 / 深色可手动指定，也可跟随系统的深浅色设置自动切换';
    final textWidget = tester.widget<Text>(find.text(description));
    expect(textWidget.style?.color, AppSemanticColors.dark.textSecondary);

    // 弹窗标题
    final titleFinder = find.text('主题模式');
    expect(titleFinder, findsNWidgets(2)); // 设置项 + 弹窗标题
    final titleWidget = tester.widgetList<Text>(titleFinder).last;
    expect(titleWidget.style?.color, AppSemanticColors.dark.textPrimary);

    // 三个选项均存在且可读
    for (final label in <String>['跟随系统', '浅色', '深色']) {
      final finder = find.text(label);
      expect(finder, findsOneWidget, reason: '缺少选项 $label');
      final style = tester.widget<Text>(finder).style;
      expect(style?.color, AppSemanticColors.dark.textPrimary);
    }
  });

  testWidgets('在弹窗中选择浅色后主题立即切换', (tester) async {
    final controller = await buildController();
    await pumpSettings(tester, controller);

    await tester.scrollUntilVisible(
      find.text('主题模式'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('主题模式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();

    expect(controller.theme.mode, ThemeMode.light);
  });

  testWidgets('浅色模式下同样的文字取浅色主题令牌', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await PrefsStore.open();
    final theme = ThemeController(prefs);
    final controller = AppController(prefs: prefs, theme: theme);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        home: AppScope(controller: controller, child: const SettingsPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await tester.scrollUntilVisible(
      find.text('主题模式'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('主题模式'));
    await tester.pumpAndSettle();

    const description = '浅色 / 深色可手动指定，也可跟随系统的深浅色设置自动切换';
    final textWidget = tester.widget<Text>(find.text(description));
    expect(textWidget.style?.color, AppSemanticColors.light.textSecondary);
  });
}
