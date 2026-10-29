import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuaa_timetable/data/local/prefs_store.dart';
import 'package:nuaa_timetable/data/models/course_session.dart';
import 'package:nuaa_timetable/data/models/semester.dart';
import 'package:nuaa_timetable/data/models/timetable_snapshot.dart';
import 'package:nuaa_timetable/features/today/today_page.dart';
import 'package:nuaa_timetable/state/app_controller.dart';
import 'package:nuaa_timetable/state/app_scope.dart';
import 'package:nuaa_timetable/theme/app_theme.dart';
import 'package:nuaa_timetable/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 回归：今日页曾因 Row(stretch) 在无界高度下只渲染首张卡片。
void main() {
  Future<AppController> buildController() async {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    CourseSession session(
      String name,
      int start,
      int end,
      int day, {
      double? credit,
      String courseCode = '',
    }) =>
        CourseSession(
          name: name,
          code: '0001',
          teacher: '菅利荣',
          place: 'T2411(天目湖)',
          campus: '天目湖',
          dayOfWeek: day,
          startRow: start,
          endRow: end,
          weeks: 0xFFFFF,
          weekText: '第1-20周',
          credit: credit,
          courseCode: courseCode,
        );

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await PrefsStore.open();
    final controller =
        AppController(prefs: prefs, theme: ThemeController(prefs));
    controller.snapshot = TimetableSnapshot(
      semester: Semester(
        id: 402,
        name: '2026-2027 学年第1学期',
        weekCount: 20,
        week1Monday: monday,
      ),
      sessions: <CourseSession>[
        session('应用统计学', 2, 3, now.weekday,
            credit: 5, courseCode: '09102450'),
        session('基础会计学Ⅰ', 6, 7, now.weekday,
            credit: 3.5, courseCode: '09402130'),
        session('社会研究方法', 8, 9, now.weekday),
      ],
      fetchedAt: DateTime.now(),
    );
    return controller;
  }

  testWidgets('今天有 3 节课时三张卡片都要渲染出来', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = await buildController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: AppScope(controller: controller, child: const TodayPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('共 3 节课'), findsOneWidget);
    expect(find.text('应用统计学'), findsOneWidget);
    expect(find.text('基础会计学Ⅰ'), findsOneWidget);
    expect(find.text('社会研究方法'), findsOneWidget);
    // 教师名必须解析为真实姓名而非 JS 表达式
    expect(find.text('菅利荣'), findsNWidgets(3));

    // 学分：卡片胶囊逐门课展示，顶部给出当日合计（5 + 3.5）。
    expect(find.text('5 学分'), findsOneWidget);
    expect(find.text('3.5 学分'), findsOneWidget);
    expect(find.text('共 3 节课'), findsOneWidget);
    expect(find.text('8.5学分'), findsOneWidget);
  });
}
