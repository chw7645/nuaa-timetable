import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuaa_timetable/core/time/period_table.dart';
import 'package:nuaa_timetable/data/parsers/course_table_parser.dart';

void main() {
  late String html;

  setUpAll(() {
    html = File('test/fixtures/course_table_all.html').readAsStringSync();
  });

  group('CourseTableParser（真实教务响应）', () {
    test('unitCount 为 13 行网格', () {
      final result = CourseTableParser.parse(html, weekCount: 20);
      expect(result.unitCount, 13);
      expect(result.sessions, isNotEmpty);
    });

    test('基础会计学Ⅰ 落在星期四第 8-9 行、T1403（与参考截图一致）', () {
      final result = CourseTableParser.parse(html, weekCount: 20);
      final matches = result.sessions
          .where((s) => s.name.contains('基础会计学') && s.place.contains('T1403'))
          .toList();
      expect(matches, hasLength(1));
      final session = matches.single;
      expect(session.dayOfWeek, 4, reason: '索引 3 对应周四');
      expect(session.startRow, 8);
      expect(session.endRow, 9);
      expect(session.campus, '天目湖');
    });

    test('行号经 PeriodTable 映射为「7-8 / 16:15-18:00」', () {
      final result = CourseTableParser.parse(html, weekCount: 20);
      final session = result.sessions
          .firstWhere((s) => s.name.contains('基础会计学') && s.place.contains('T1403'));
      expect(PeriodTable.mainCampus.labelSpan(session.startRow, session.endRow), '7-8');
      expect(PeriodTable.mainCampus.spanText(session.startRow, session.endRow),
          '16:15-18:00');
    });

    test('周次位图按「索引 i = 第 i 周」解释（不再整体延后一周）', () {
      final result = CourseTableParser.parse(html, weekCount: 20);
      final session = result.sessions.firstWhere(
          (s) => s.name.contains('基础会计学') && s.place.contains('T1403'));
      // 教务页面显示：基础会计学Ⅰ（周四 7-8）3-6,8-17 周
      expect(session.weekText, '3-6,8-17周');
      expect(session.hasWeek(3), isTrue);
      expect(session.hasWeek(6), isTrue);
      expect(session.hasWeek(7), isFalse, reason: '第 7 周教务不排课');
      expect(session.hasWeek(8), isTrue);
      expect(session.hasWeek(17), isTrue);
      expect(session.hasWeek(18), isFalse);
    });

    group('与教务页面「我的课表」逐门对照（ground truth 来自页面截图）', () {
      late CourseTableParseResult result;
      setUp(() {
        result = CourseTableParser.parse(html, weekCount: 20);
      });

      /// 同一格可能有多条教学任务，取全部周次文本。
      List<String> weeksOf(String name, int day, int row) => result.sessions
          .where((s) =>
              s.name == name && s.dayOfWeek == day && s.startRow == row)
          .map((s) => s.weekText)
          .toList();

      String single(String name, int day, int row) {
        final list = weeksOf(name, day, row);
        expect(list, hasLength(1), reason: '$name 周$day 行$row 应只有一条');
        return list.single;
      }

      test('应用统计学：周一 1-2 是 1-10 周，周一 3-4 是 11-19 周', () {
        expect(single('应用统计学', 1, 0), '1-10周');
        expect(single('应用统计学', 1, 2), '11-19周');
      });

      test('线性代数：周二两个时段都是 7-16 周', () {
        expect(single('线性代数', 2, 2), '7-16周');
        expect(single('线性代数', 3, 0), '7-16周');
      });

      test('中国近现代史纲要：周二 1-10 周、周一 1-11 周', () {
        expect(single('中国近现代史纲要', 2, 0), '1-10周');
        expect(single('中国近现代史纲要', 1, 8), '1-11周');
      });

      test('货币金融学 1-12 周、科技英语翻译 1-16 周', () {
        expect(single('货币金融学', 3, 2), '1-12周');
        expect(single('货币金融学', 2, 6), '1-12周');
        expect(single('科技英语翻译', 3, 8), '1-16周');
      });

      test('基础会计学Ⅰ：周一 3-15 周、周四 3-6,8-17 周', () {
        expect(single('基础会计学Ⅰ', 1, 6), '3-15周');
        expect(single('基础会计学Ⅰ', 4, 8), '3-6,8-17周');
      });

      test('形势与政策（2）10-11 周、改革开放史 7-12 周', () {
        expect(single('形势与政策（2）', 3, 10), '10-11周');
        expect(single('改革开放史', 1, 10), '7-12周');
      });

      test('社会研究方法：周四 5-6 有 1-2,4-14 周与单独的第 15 周', () {
        expect(weeksOf('社会研究方法', 4, 6),
            containsAll(<String>['1-2,4-14周', '15周']));
      });

      test('所有课程都不出现整体 +1 的痕迹（第 20 周内不该有的课）', () {
        for (final s in result.sessions) {
          expect(s.hasWeek(0), isFalse);
          // 若仍按旧逻辑，第 1 周有课的课程会被算到第 2 周。
          if (s.weekText.startsWith('1-')) {
            expect(s.hasWeek(1), isTrue, reason: '${s.name} 首周应为第 1 周');
          }
        }
      });
    });

    test('紧凑位图（长度=学期周数）仍按第 0 位=第 1 周处理', () {
      const bitmap = '11100000000000000000'; // 20 位，前 3 周
      final mini = '''
var unitCount = 13;
activity = new TaskActivity(ids, names, "0001", "紧凑位图课", "", "1", "T101", "$bitmap", "1", null, "", "", "", "X");
index =0*unitCount+0;
''';
      final parsed = CourseTableParser.parse(mini, weekCount: 20);
      final s = parsed.sessions.single;
      expect(s.weekText, '1-3周');
      expect(s.hasWeek(4), isFalse);
    });

    test('隔周格式只在「全部单周且间隔恒为 2」时启用', () {
      const bitmap = '10100000000000000000'; // 紧凑格式索引 0/2 → 第 1、3 周
      final mini = '''
var unitCount = 13;
activity = new TaskActivity(ids, names, "0002", "隔周课", "", "2", "T102", "$bitmap", "2", null, "", "", "", "X");
index =0*unitCount+0;
''';
      final parsed = CourseTableParser.parse(mini, weekCount: 20);
      final s = parsed.sessions.single;
      expect(s.hasWeek(1), isTrue);
      expect(s.hasWeek(2), isFalse);
      expect(s.hasWeek(3), isTrue);
      expect(s.weekText, '1-3(隔周)周');
    });

    test('同一 cell 的重复下发按位或合并（week-union）', () {
      final result = CourseTableParser.parse(html, weekCount: 20);
      final keys = result.sessions.map((s) => s.key).toList();
      expect(keys.toSet().length, keys.length, reason: '不应存在重复键');
    });

    test('教师姓名取自 actTeachers 数组，而非 JS 表达式', () {
      final result = CourseTableParser.parse(html, weekCount: 20);
      expect(
        result.sessions.where((s) => s.teacher.contains('join(')),
        isEmpty,
        reason: '不能把 actTeacherName.join(\',\') 当成教师名',
      );
      final sample = result.sessions.firstWhere(
        (s) => s.name.contains('应用统计'),
      );
      expect(sample.teacher, isNotEmpty);
    });

    test('校区由地点自动判定', () {
      final result = CourseTableParser.parse(html, weekCount: 20);
      final campuses = result.sessions.map((s) => s.campus).toSet();
      expect(campuses, contains('天目湖'));
    });

    test('学分从「课程列表」表格解析，逐门课对应正确', () {
      final result = CourseTableParser.parse(html, weekCount: 20);
      double creditOf(String name) => result.sessions
          .firstWhere((s) => s.name.contains(name))
          .credit!;

      // 以下数值取自真实教务响应的「学分」列。
      expect(creditOf('应用统计学'), 5.0);
      expect(creditOf('基础会计学'), 3.5);
      expect(creditOf('线性代数'), 2.5);
      expect(creditOf('社会研究方法'), 3.5);
      expect(creditOf('形势与政策'), 0.5);

      // 每门课都要有学分，不能只解析到部分。
      final names = result.sessions.map((s) => s.name).toSet();
      expect(result.creditResolved, names.length,
          reason: '${names.length} 门课中只有 ${result.creditResolved} 门解析到学分');
      for (final s in result.sessions) {
        expect(s.hasCredit, isTrue, reason: '${s.name} 缺少学分');
      }
    });

    test('学分合计按课程去重，不按上课次数累加', () {
      final result = CourseTableParser.parse(html, weekCount: 20);
      final unique = result.sessions.map((s) => s.name).toSet();
      expect(unique, hasLength(12));
      expect(result.totalCredits, 29.0);
      // 24 条上课安排里包含重复课程，合计必须等于 12 门课之和。
      expect(result.sessions.length, greaterThan(unique.length));
    });

    test('课程类别与 8 位课程代码一并带出', () {
      final result = CourseTableParser.parse(html, weekCount: 20);
      final accounting =
          result.sessions.firstWhere((s) => s.name.contains('基础会计学'));
      expect(accounting.category, '学科基础必修课');
      expect(accounting.courseCode, '09402130');
    });
  });

  group('异常输入', () {
    test('缺少 unitCount 抛出 ParseException', () {
      expect(
        () => CourseTableParser.parse('<html>no table</html>'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
