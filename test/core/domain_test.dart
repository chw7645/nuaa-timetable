import 'package:flutter_test/flutter_test.dart';
import 'package:nuaa_timetable/core/time/period_table.dart';
import 'package:nuaa_timetable/core/time/week_calendar.dart';
import 'package:nuaa_timetable/data/campus_resolver.dart';
import 'package:nuaa_timetable/data/semester_calendar.dart';

void main() {
  group('PeriodTable', () {
    test('13 行网格：4 节 + 午间 2 行 + 7 节', () {
      expect(PeriodTable.mainCampus.rowCount, 13);
      expect(PeriodTable.mainCampus.slotOf(4).label, '午一节');
      expect(PeriodTable.mainCampus.slotOf(5).label, '午二节');
      expect(PeriodTable.mainCampus.slotOf(6).label, '第五节');
    });

    test('第七、八节 = 16:15-18:00（与桌面小组件设计稿一致）', () {
      expect(PeriodTable.mainCampus.labelSpan(8, 9), '7-8');
      expect(PeriodTable.mainCampus.spanText(8, 9), '16:15-18:00');
      expect(PeriodTable.mainCampus.startMinutes(8), 16 * 60 + 15);
      expect(PeriodTable.mainCampus.endMinutes(9), 18 * 60);
    });

    test('午间加课没有官方时刻', () {
      expect(PeriodTable.mainCampus.spanText(4, 5), '午间');
      expect(PeriodTable.mainCampus.startMinutes(4), isNull);
    });

    test('节次单调递增且不重叠', () {
      final slots = PeriodTable.mainCampus.slots
          .where((s) => !s.isNoon)
          .toList();
      for (var i = 1; i < slots.length; i++) {
        expect(slots[i].startMinutes!,
            greaterThanOrEqualTo(slots[i - 1].endMinutes!));
      }
    });

    test('天目湖校区：上午 08:30 起，7-8 节 16:00-17:45', () {
      expect(PeriodTable.tianmuhuCampus.startMinutes(0), 8 * 60 + 30);
      expect(PeriodTable.tianmuhuCampus.labelSpan(8, 9), '7-8');
      expect(PeriodTable.tianmuhuCampus.spanText(8, 9), '16:00-17:45');
      expect(PeriodTable.tianmuhuCampus.startMinutes(8), 16 * 60);
      expect(PeriodTable.tianmuhuCampus.endMinutes(9), 17 * 60 + 45);
    });

    test('将军路/明故宫：上午 08:00 起，7-8 节 16:15-18:00', () {
      expect(PeriodTable.mainCampus.startMinutes(0), 8 * 60);
      expect(PeriodTable.mainCampus.spanText(8, 9), '16:15-18:00');
    });

    test('forCampus 按校区选表', () {
      expect(PeriodTable.forCampus('天目湖').track, CampusTrack.tianmuhu);
      expect(PeriodTable.forCampus('将军路').track, CampusTrack.main);
      expect(PeriodTable.forCampus('明故宫').track, CampusTrack.main);
    });

    test('跨午间行的课程被切成两段，不会染色午休', () {
      final segments = PeriodTable.mainCampus.segmentsOf(3, 6);
      expect(segments, <List<int>>[
        <int>[3],
        <int>[6],
      ]);
    });
  });

  group('WeekCalendar', () {
    final calendar = WeekCalendar(
      week1Monday: DateTime(2026, 8, 31),
      weekCount: 20,
    );

    test('2026-10-29 为第 9 周', () {
      expect(calendar.weekOf(DateTime(2026, 10, 29)), 9);
    });

    test('第 1 周周一与日期换算', () {
      expect(calendar.mondayOfWeek(1), DateTime(2026, 8, 31));
      expect(calendar.dateOf(9, 4), DateTime(2026, 10, 29));
    });

    test('学期开始前返回 0', () {
      expect(calendar.weekOf(DateTime(2026, 8, 20)), 0);
    });
  });

  group('SemesterCalendar', () {
    test('学期 402 第 1 周为 2026-08-31（与真实课表交叉验证）', () {
      expect(SemesterCalendar.week1MondayFor(402), DateTime(2026, 8, 31));
    });
  });

  group('CampusResolver', () {
    test('优先取括号内校区', () {
      expect(CampusResolver.resolve('T1403(天目湖)'), '天目湖');
      expect(CampusResolver.resolve('实地讲习（天目湖）(天目湖)'), '天目湖');
    });

    test('按楼栋前缀推断', () {
      expect(CampusResolver.resolve('T2411'), '天目湖');
      expect(CampusResolver.resolve('J1101'), '将军路');
      expect(CampusResolver.resolve('M201'), '明故宫');
    });

    test('无法判定时回落默认校区', () {
      expect(CampusResolver.resolve('未知地点', defaultCampus: '将军路'), '将军路');
      expect(CampusResolver.resolve('未知地点'), CampusResolver.unknown);
    });
  });
}
