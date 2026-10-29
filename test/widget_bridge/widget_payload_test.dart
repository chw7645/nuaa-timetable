import 'package:flutter_test/flutter_test.dart';
import 'package:nuaa_timetable/core/time/period_table.dart';
import 'package:nuaa_timetable/data/models/course_session.dart';
import 'package:nuaa_timetable/data/models/semester.dart';
import 'package:nuaa_timetable/data/models/timetable_snapshot.dart';
import 'package:nuaa_timetable/widget_bridge/widget_payload.dart';

CourseSession _session({
  required String name,
  required int day,
  required int startRow,
  required int endRow,
  String place = 'T1403(天目湖)',
}) {
  return CourseSession(
    name: name,
    code: '0001',
    teacher: '袁泉',
    place: place,
    campus: '天目湖',
    dayOfWeek: day,
    startRow: startRow,
    endRow: endRow,
    weeks: 0xFFFFF,
    weekText: '1-20周',
  );
}

void main() {
  final semester = Semester(
    id: 402,
    name: '2026-2027 学年第1学期',
    weekCount: 20,
    week1Monday: DateTime(2026, 8, 31),
  );

  final snapshot = TimetableSnapshot(
    semester: semester,
    sessions: <CourseSession>[
      _session(name: '基础会计学Ⅰ', day: 4, startRow: 8, endRow: 9),
      _session(name: '货币金融学', day: 4, startRow: 10, endRow: 11),
    ],
    fetchedAt: DateTime(2026, 10, 29, 8),
  );

  group('WidgetPayload', () {
    test('正在上课时聚焦当前课程', () {
      final payload = WidgetPayload.build(
        snapshot: snapshot,
        tableForCampus: PeriodTable.forCampus,
        now: DateTime(2026, 10, 29, 16, 30), // 第七节中段
      );
      final today = (payload.json['days'] as List).first as Map<String, dynamic>;
      expect(today['dateText'], '10月29日');
      expect(today['weekdayText'], '星期四');
      final focus = today['focus'] as Map<String, dynamic>;
      expect(focus['name'], '基础会计学Ⅰ');
      expect(focus['periodText'], '7-8');
      expect(focus['timeText'], '16:00-17:45');
      expect(focus['state'], '正在上课');
      expect(today['remaining'], 2);
      expect(today['remainingText'], '今天剩余2门课');
    });

    test('早于第一节课时聚焦下一节', () {
      final payload = WidgetPayload.build(
        snapshot: snapshot,
        tableForCampus: PeriodTable.forCampus,
        now: DateTime(2026, 10, 29, 9, 0),
      );
      final today = (payload.json['days'] as List).first as Map<String, dynamic>;
      final focus = today['focus'] as Map<String, dynamic>;
      expect(focus['name'], '基础会计学Ⅰ');
      expect(focus['state'], '下一节');
    });

    test('课程全部结束后提示已结束', () {
      final payload = WidgetPayload.build(
        snapshot: snapshot,
        tableForCampus: PeriodTable.forCampus,
        now: DateTime(2026, 10, 29, 21, 40),
      );
      final today = (payload.json['days'] as List).first as Map<String, dynamic>;
      expect(today['remaining'], 0);
      expect(today['remainingText'], '今天的课已结束');
      expect((today['focus'] as Map<String, dynamic>)['state'], '今日课程');
    });

    test('无课日给出空态文案', () {
      final payload = WidgetPayload.build(
        snapshot: snapshot,
        tableForCampus: PeriodTable.forCampus,
        now: DateTime(2026, 10, 30, 9, 0), // 星期五
      );
      final today = (payload.json['days'] as List).first as Map<String, dynamic>;
      expect(today['empty'], isTrue);
      expect(today['focus'], isNull);
      expect(today['remainingText'], '今天没有课程安排');
    });

    test('payload 覆盖今天起 8 天', () {
      final payload = WidgetPayload.build(
        snapshot: snapshot,
        tableForCampus: PeriodTable.forCampus,
        now: DateTime(2026, 10, 29, 12),
      );
      expect((payload.json['days'] as List).length, 8);
      expect(payload.json['schemaVersion'], WidgetPayload.schemaVersion);
    });

    test('午间加课的时间文案为「午间」', () {
      final noonSnapshot = TimetableSnapshot(
        semester: semester,
        sessions: <CourseSession>[
          _session(name: '午间加课', day: 4, startRow: 4, endRow: 5),
        ],
        fetchedAt: DateTime(2026, 10, 29, 8),
      );
      final payload = WidgetPayload.build(
        snapshot: noonSnapshot,
        tableForCampus: PeriodTable.forCampus,
        now: DateTime(2026, 10, 29, 12),
      );
      final today = (payload.json['days'] as List).first as Map<String, dynamic>;
      final focus = today['focus'] as Map<String, dynamic>;
      expect(focus['timeText'], '午间');
      expect(focus['noon'], isTrue);
    });
  });
}
