import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuaa_timetable/data/local/prefs_store.dart';
import 'package:nuaa_timetable/data/models/course_session.dart';
import 'package:nuaa_timetable/data/models/semester.dart';
import 'package:nuaa_timetable/data/models/timetable_snapshot.dart';
import 'package:nuaa_timetable/features/home/grid_metrics.dart';
import 'package:nuaa_timetable/features/home/timetable_view.dart';
import 'package:nuaa_timetable/state/app_controller.dart';
import 'package:nuaa_timetable/state/app_scope.dart';
import 'package:nuaa_timetable/theme/app_theme.dart';
import 'package:nuaa_timetable/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 无真机环境下的界面冒烟测试：确保周视图能真实布局、课程块可点击。
void main() {
  TimetableSnapshot buildSnapshot() {
    CourseSession session({
      required String name,
      required int day,
      required int start,
      required int end,
      String place = 'T1403(天目湖)',
      double? credit,
      String courseCode = '',
    }) =>
        CourseSession(
          name: name,
          code: '5617',
          teacher: '袁泉',
          place: place,
          campus: '天目湖',
          dayOfWeek: day,
          startRow: start,
          endRow: end,
          weeks: 0xFFFFF,
          weekText: '4-18周',
          credit: credit,
          courseCode: courseCode,
          category: credit == null ? '' : '学科基础必修课',
        );

    return TimetableSnapshot(
      semester: Semester(
        id: 402,
        name: '2026-2027 学年第1学期',
        weekCount: 20,
        week1Monday: DateTime(2026, 8, 31),
      ),
      sessions: <CourseSession>[
        session(
          name: '基础会计学Ⅰ',
          day: 4,
          start: 8,
          end: 9,
          credit: 3.5,
          courseCode: '09402130',
        ),
        session(name: '线性代数', day: 2, start: 2, end: 3, place: 'T2111(天目湖)'),
        session(name: '应用统计学', day: 4, start: 2, end: 3, place: 'T2411(天目湖)'),
        session(name: '午间加课', day: 1, start: 4, end: 5),
        // 冲突课：与基础会计学Ⅰ同一时间，验证并排布局不抛异常
        session(name: '社会研究方法', day: 4, start: 8, end: 9, place: 'T2217(天目湖)'),
      ],
      fetchedAt: DateTime(2026, 10, 29, 9),
    );
  }

  Future<AppController> buildController() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await PrefsStore.open();
    final theme = ThemeController(prefs);
    final controller = AppController(prefs: prefs, theme: theme);
    controller.snapshot = buildSnapshot();
    controller.week = 9;
    return controller;
  }

  Future<void> pumpTimetable(WidgetTester tester, AppController controller) async {
    // 默认 800x600 画布装不下 13 行网格，放大到手机比例避免点击落在屏幕外。
    tester.view.physicalSize = const Size(1000, 1700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        home: AppScope(controller: controller, child: const TimetableView()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('周视图正常渲染：周次、日期头、课程块', (tester) async {
    final controller = await buildController();
    await pumpTimetable(tester, controller);

    expect(find.textContaining('第 9 周'), findsWidgets);
    expect(find.textContaining('10/26'), findsWidgets);
    expect(find.text('基础会计学Ⅰ'), findsOneWidget);
    expect(find.text('线性代数'), findsOneWidget);
    expect(find.text('周四'), findsOneWidget);
  });

  testWidgets('点击课程块弹出详情，含「上课安排」', (tester) async {
    final controller = await buildController();
    await pumpTimetable(tester, controller);

    await tester.tap(find.text('基础会计学Ⅰ'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('上课安排'), findsOneWidget);
    expect(find.textContaining('T1403'), findsWidgets);
    expect(find.textContaining('4-18周'), findsWidgets);
  });

  testWidgets('切换周次：点击下一周按钮后标题更新', (tester) async {
    final controller = await buildController();
    await pumpTimetable(tester, controller);

    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();

    expect(find.textContaining('第 10 周'), findsWidgets);
  });

  testWidgets('课程块只覆盖自己的节次，不染色空课与午休行', (tester) async {
    final controller = await buildController();
    await pumpTimetable(tester, controller);

    final blocks = tester
        .widgetList<Positioned>(find.byWidgetPredicate(
          (w) =>
              w is Positioned &&
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('block-'),
        ))
        .toList();
    expect(blocks, isNotEmpty);

    final table = controller.periodTable;
    for (final block in blocks) {
      final top = block.top!;
      final height = block.height!;
      final firstRow = GridMetrics.rowOfTop(top);
      final lastRow = GridMetrics.rowOfBottom(top, height);
      for (var row = firstRow; row <= lastRow; row++) {
        expect(table.isNoonRow(row), isFalse,
            reason: '课程块覆盖了午间占位行 $row');
      }
    }

    // 应用统计学在周四为第 2-3 行（第三、四节），块必须从第 2 行开始。
    final accounting = blocks.where((b) => (b.key! as ValueKey<String>)
        .value
        .contains('应用统计学'));
    expect(accounting, isNotEmpty);
    for (final block in accounting) {
      expect(GridMetrics.rowOfTop(block.top!), 2);
      expect((block.height! / GridMetrics.rowHeight).round(), 2);
    }
  });

  testWidgets('纵向滚动使用钳制物理，Android 上不会回弹', (tester) async {
    final controller = await buildController();
    await pumpTimetable(tester, controller);

    final view = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    expect(view.physics, isA<AlwaysScrollableScrollPhysics>());
    expect(
      (view.physics! as AlwaysScrollableScrollPhysics).parent,
      isA<ClampingScrollPhysics>(),
      reason: '必须钳制边界，BouncingScrollPhysics 会在 Android 上"拉出去再弹回"',
    );
  });

  testWidgets('翻页不重建分页器实例（滑动跟手的前提）', (tester) async {
    final controller = await buildController();
    await pumpTimetable(tester, controller);

    final before = tester.widget<PageView>(find.byType(PageView));
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    final after = tester.widget<PageView>(find.byType(PageView));

    expect(identical(before, after), isTrue,
        reason: '周次变化只应重建顶部区域，分页器必须复用，'
            '否则每次翻页都要重建整屏课程块');
  });

  testWidgets('左右滑动切周：标题与内容同步', (tester) async {
    final controller = await buildController();
    await pumpTimetable(tester, controller);
    expect(find.textContaining('第 9 周'), findsWidgets);

    // 用 fling 模拟真实翻页手势（drag 距离不足时 PageView 会回弹）。
    await tester.fling(find.byType(PageView), const Offset(-600, 0), 1500);
    await tester.pumpAndSettle();

    expect(find.textContaining('第 10 周'), findsWidgets);
    // 静默同步：控制器里的周次也要跟上，但不应触发全局重建。
    expect(controller.week, 10);
  });

  testWidgets('纵向为主的斜向滑动不翻页（方向门控）', (tester) async {
    final controller = await buildController();
    await pumpTimetable(tester, controller);

    // 横向 40 / 纵向 160：人手上下滑的典型形态，横向分量远小于纵向。
    await tester.drag(find.byType(PageView), const Offset(-40, 160));
    await tester.pumpAndSettle();

    expect(controller.week, 9,
        reason: '纵向为主的滑动被误判成翻页，就是"上下滑卡手"的根因');
    expect(find.textContaining('第 9 周'), findsWidgets);
  });

  testWidgets('横向拖动不足半页时吸附回原页', (tester) async {
    final controller = await buildController();
    await pumpTimetable(tester, controller);

    await tester.drag(find.byType(PageView), const Offset(-60, 0));
    await tester.pumpAndSettle();

    expect(controller.week, 9);
  });

  testWidgets('横向拖动过半页即翻页（跟手位移生效）', (tester) async {
    final controller = await buildController();
    await pumpTimetable(tester, controller);

    // 画布宽 1000，拖 700 已过半页；松手速度接近 0，按就近吸附判定。
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();

    expect(controller.week, 10);
  });

  testWidgets('时间列每格三行：节次 + 起始 + 结束时刻', (tester) async {
    final controller = await buildController();
    await pumpTimetable(tester, controller);

    // 天目湖第七节 16:00-16:50
    expect(find.text('第七节'), findsOneWidget);
    expect(find.text('16:00'), findsWidgets);
    expect(find.text('16:50'), findsWidgets);
    // 午间占位行仍保留
    expect(find.text('午一'), findsOneWidget);
    expect(find.text('午二'), findsOneWidget);
  });

  testWidgets('课程块内展示学分', (tester) async {
    final controller = await buildController();
    await pumpTimetable(tester, controller);

    expect(find.text('3.5 学分'), findsWidgets);
  });

  testWidgets('切到列表视图后每门课显示学分徽标', (tester) async {
    final controller = await buildController();
    await pumpTimetable(tester, controller);

    await tester.tap(find.text('列表'));
    await tester.pumpAndSettle();

    expect(find.text('基础会计学Ⅰ'), findsOneWidget);
    expect(find.text('3.5 学分'), findsOneWidget);
  });

  testWidgets('深色模式下同样可正常渲染', (tester) async {
    final controller = await buildController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: AppScope(controller: controller, child: const TimetableView()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('基础会计学Ⅰ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
