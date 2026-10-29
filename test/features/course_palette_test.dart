import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuaa_timetable/data/models/semester.dart';
import 'package:nuaa_timetable/data/models/timetable_snapshot.dart';
import 'package:nuaa_timetable/data/parsers/course_table_parser.dart';

/// 课程配色的分配规则：同一门课任何周、任何视图都必须同色；
/// 不同课程尽量落在不同调色板槽位，避免同屏撞色。
void main() {
  late TimetableSnapshot snapshot;

  setUpAll(() {
    final parsed = CourseTableParser.parse(
      File('test/fixtures/course_table_all.html').readAsStringSync(),
    );
    snapshot = TimetableSnapshot(
      semester: Semester(
        id: 402,
        name: '2026-2027 学年第1学期',
        weekCount: 20,
        week1Monday: DateTime(2026, 8, 31),
      ),
      sessions: parsed.sessions,
      fetchedAt: DateTime(2026, 10, 29, 9),
    );
  });

  test('同一门课的多次上课共用同一索引', () {
    final indexes = snapshot.courseColorIndexes;
    // 应用统计学在第 9 周有多个时段，索引必须唯一。
    expect(indexes['应用统计学'], isNotNull);
    final sessions =
        snapshot.sessions.where((s) => s.name == '应用统计学').toList();
    expect(sessions.length, greaterThan(1));
    for (final s in sessions) {
      expect(indexes[s.name], indexes['应用统计学']);
    }
  });

  test('按出现顺序从 0 连续分配，没有空洞', () {
    final values = snapshot.courseColorIndexes.values.toList()..sort();
    final expected = List<int>.generate(snapshot.courseColorIndexes.length, (i) => i);
    expect(values, expected);
  });

  test('前 8 门课在 8 色板里各占一色，不撞色', () {
    final indexes = snapshot.courseColorIndexes;
    final firstEight = <String>[];
    for (final entry in indexes.entries) {
      if (entry.value < 8) firstEight.add(entry.key);
    }
    expect(firstEight.length, 8);
    // 8 色板取模后互不相同。
    final slots = <int>{};
    for (final name in firstEight) {
      slots.add(indexes[name]! % 8);
    }
    expect(slots.length, 8, reason: '前 8 门课应覆盖全部 8 个颜色槽位');
  });

  test('顺序分配比 hashCode 覆盖更均匀（回归）', () {
    final indexes = snapshot.courseColorIndexes;
    final byOrder = indexes.values.map((v) => v % 8).toSet();
    // 旧实现用 name.hashCode % 8，实测只覆盖 6 个槽位。
    final byHash = snapshot.sessions
        .map((s) => s.name.hashCode % 8)
        .toSet();
    expect(byOrder.length, greaterThanOrEqualTo(byHash.length),
        reason: '顺序分配不应比哈希更差');
    expect(byOrder.length, 8);
  });
}
