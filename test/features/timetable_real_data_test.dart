import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuaa_timetable/data/local/prefs_store.dart';
import 'package:nuaa_timetable/data/models/semester.dart';
import 'package:nuaa_timetable/data/models/timetable_snapshot.dart';
import 'package:nuaa_timetable/data/parsers/course_table_parser.dart';
import 'package:nuaa_timetable/features/home/grid_metrics.dart';
import 'package:nuaa_timetable/features/home/timetable_view.dart';
import 'package:nuaa_timetable/state/app_controller.dart';
import 'package:nuaa_timetable/state/app_scope.dart';
import 'package:nuaa_timetable/theme/app_theme.dart';
import 'package:nuaa_timetable/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用真实教务响应（已脱敏）验证第 9 周周四的渲染几何。
///
/// 用户反馈："第九周周四的应用统计学，上面两节空的课和午休时间的占位都被染色"。
void main() {

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

  Future<void> pump(
    WidgetTester tester,
    AppController controller, {
    Size size = const Size(1080, 2400),
    double dpr = 3.0,
  }) async {
    // 默认贴近真机：1080x2400 @3x = 360x800 逻辑像素
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
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

  List<Positioned> blocksOf(WidgetTester tester) => tester
      .widgetList<Positioned>(find.byWidgetPredicate(
        (w) =>
            w is Positioned &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('block-'),
      ))
      .toList();

  testWidgets('真实数据：第 9 周所有课程块都不覆盖午间占位行', (tester) async {
    final controller = await buildController();
    await pump(tester, controller);

    final blocks = blocksOf(tester);
    expect(blocks, isNotEmpty);

    final table = controller.periodTable;
    for (final block in blocks) {
      final firstRow = GridMetrics.rowOfTop(block.top!);
      final lastRow = GridMetrics.rowOfBottom(block.top!, block.height!);
      for (var row = firstRow; row <= lastRow; row++) {
        expect(table.isNoonRow(row), isFalse,
            reason: '块 ${block.key} 覆盖了午间行 $row');
      }
    }
  });

  testWidgets('窄屏 320dp 下仍能完整布局（无 RenderFlex 溢出）', (tester) async {
    // 若课程块内容超出块高，flutter_test 会以 RenderFlex overflowed 失败，
    // 因此这条用例同时充当"内容自适应行数"的回归保护。
    final controller = await buildController();
    await pump(tester, controller, size: const Size(640, 1440), dpr: 2.0);

    expect(blocksOf(tester), isNotEmpty, reason: '窄屏下课程块应正常渲染');
    expect(find.text('第七节'), findsOneWidget);
    expect(find.text('午一'), findsOneWidget);
  });

  testWidgets('时间列渲染全部 13 行（含第三、四节与午间）', (tester) async {
    final controller = await buildController();
    await pump(tester, controller);

    for (final label in <String>[
      '第一节',
      '第二节',
      '第三节',
      '第四节',
      '午一',
      '午二',
      '第五节',
      '第六节',
      '第七节',
      '第八节',
      '第九节',
      '第十节',
      '第十一节',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '缺少时间列标签 $label');
    }
  });

  testWidgets('真实数据：周四应用统计学只占第三、四节（第 2-3 行）', (tester) async {
    final controller = await buildController();
    await pump(tester, controller);

    final blocks = blocksOf(tester)
        .where((b) => (b.key! as ValueKey<String>).value.contains('应用统计学'))
        .toList();
    expect(blocks, isNotEmpty, reason: '第 9 周应能渲染出应用统计学');

    // 只保留周四（key 中 |4| 表示 dayOfWeek=4）的块
    final thursday = blocks
        .where((b) => (b.key! as ValueKey<String>).value.contains('|4|'))
        .toList();
    expect(thursday, hasLength(1));

    final block = thursday.single;
    expect(GridMetrics.rowOfTop(block.top!), 2,
        reason: '应从第三行开始，不能盖住第一节、第二节');
    expect((block.height! / GridMetrics.rowHeight).round(), 2,
        reason: '高度只能覆盖两节');
  });

  testWidgets('真实数据：空课行（第一、二节）没有被任何课程染色', (tester) async {
    final controller = await buildController();
    await pump(tester, controller);

    final thursdayBlocks = blocksOf(tester).where((b) {
      return (b.key! as ValueKey<String>).value.contains('|4|');
    }).toList();

    for (final block in thursdayBlocks) {
      final topRow = GridMetrics.rowOfTop(block.top!);
      expect(topRow, greaterThanOrEqualTo(0));
      // 周四第一、二节（第 0、1 行）不应有课
      expect(topRow, isNot(0));
      expect(topRow, isNot(1));
    }
  });
}
