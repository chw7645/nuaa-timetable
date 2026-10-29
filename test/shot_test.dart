import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuaa_timetable/data/local/prefs_store.dart';
import 'package:nuaa_timetable/data/models/semester.dart';
import 'package:nuaa_timetable/data/models/timetable_snapshot.dart';
import 'package:nuaa_timetable/data/parsers/course_table_parser.dart';
import 'package:nuaa_timetable/features/home/home_page.dart';
import 'package:nuaa_timetable/features/home/timetable_view.dart';
import 'package:nuaa_timetable/features/settings/settings_page.dart';
import 'package:nuaa_timetable/features/today/today_page.dart';
import 'package:nuaa_timetable/state/app_controller.dart';
import 'package:nuaa_timetable/state/app_scope.dart';
import 'package:nuaa_timetable/theme/app_theme.dart';
import 'package:nuaa_timetable/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 视觉快照：把真实教务数据渲染成 PNG，供人工核对排版（默认跳过）。
///
/// 运行方式：
/// ```
/// RUN_SHOTS=1 flutter test test/shot_test.dart --update-goldens
/// ```
/// 产物在 `artifacts/visual/`。
void main() {
  // 默认不跑：快照对字体/平台渲染敏感，只在需要人工核对排版时开启。
  final runShots = Platform.environment['RUN_SHOTS'] == '1';

  setUpAll(() async {
    // 视觉快照默认不跑；真要跑时通常在本机。CI（Linux）没有该字体，直接跳过加载，
    // 否则 setUpAll 抛异常会把整份测试判为失败。
    if (!runShots) return;
    final font = File('C:/Windows/Fonts/simhei.ttf');
    if (!font.existsSync()) return;
    // 测试环境默认只有 Ahem 字体（中文会变方块），加载系统黑体才能看清排版。
    final bytes = font.readAsBytesSync();
    final loader = FontLoader('SimHei')
      ..addFont(Future<ByteData>.value(ByteData.view(bytes.buffer)));
    await loader.load();
  });

  Future<AppController> buildController() async {
    final parsed = CourseTableParser.parse(
      File('test/fixtures/course_table_all.html').readAsStringSync(),
    );
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await PrefsStore.open();
    final controller = AppController(
      prefs: prefs,
      theme: ThemeController(prefs),
    );
    controller.snapshot = TimetableSnapshot(
      semester: Semester(
        id: 402,
        name: '2026-2027 学年第1学期',
        weekCount: 20,
        week1Monday: DateTime(2026, 8, 31),
      ),
      sessions: parsed.sessions,
      fetchedAt: DateTime(2026, 10, 29, 9),
    );
    controller.week = 9;
    return controller;
  }

  Future<void> shoot(
    WidgetTester tester,
    String name, {
    required Widget page,
    bool dark = false,
  }) async {
    final controller = await buildController();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final theme = dark ? AppTheme.dark() : AppTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'SimHei'),
        ),
        home: AppScope(controller: controller, child: page),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../artifacts/visual/$name.png'),
    );
  }

  testWidgets('周课表 · 浅色', skip: !runShots, (tester) async {
    await shoot(tester, 'timetable_light', page: const TimetableView());
  });

  testWidgets('周课表 · 深色', skip: !runShots, (tester) async {
    await shoot(tester, 'timetable_dark',
        page: const TimetableView(), dark: true);
  });

  testWidgets('今日课程 · 浅色', skip: !runShots, (tester) async {
    await shoot(tester, 'today_light', page: const TodayPage());
  });

  testWidgets('设置 · 浅色', skip: !runShots, (tester) async {
    await shoot(tester, 'settings_light', page: const SettingsPage());
  });

  testWidgets('课表 Tab · 含底部导航（真实外壳）', skip: !runShots, (tester) async {
    final controller = await buildController();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final theme = AppTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'SimHei'),
        ),
        home: AppScope(controller: controller, child: const HomePage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('课表').last);
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../artifacts/visual/tab_timetable.png'),
    );
  });

  testWidgets('三 Tab 外壳 · 深色', skip: !runShots, (tester) async {
    await shoot(tester, 'home_dark', page: const HomePage(), dark: true);
  });
}
