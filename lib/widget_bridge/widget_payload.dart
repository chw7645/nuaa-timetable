import 'dart:ui' show Color;

import '../core/time/period_table.dart';
import '../data/models/course_session.dart';
import '../data/models/timetable_snapshot.dart';

/// 桌面小组件数据协议（Dart → 原生）。
///
/// 所有展示文案都在 Dart 侧预计算完毕，原生只负责"选哪一条 + 赋值"，
/// 从而避免 Kotlin 侧重复实现周次、节次、作息等业务逻辑。
class WidgetPayload {
  const WidgetPayload(this.json);

  final Map<String, dynamic> json;

  static const int schemaVersion = 2;

  /// 生成"今天 + 未来 7 天"的数据。
  ///
  /// [tableForCampus] 用于按课程所在校区取作息（天目湖与主校区不同）。
  static WidgetPayload build({
    required TimetableSnapshot snapshot,
    required PeriodTable Function(String campus) tableForCampus,
    Color? accent,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final calendar = snapshot.semester.calendar;
    final today = DateTime(current.year, current.month, current.day);
    final nowMinutes = current.hour * 60 + current.minute;

    final days = <Map<String, dynamic>>[];
    for (var offset = 0; offset < 8; offset++) {
      final date = today.add(Duration(days: offset));
      final week = calendar.weekOf(date);
      final inSemester = week >= 1 && week <= snapshot.semester.weekCount;
      final sessions = inSemester
          ? snapshot.sessionsOfDay(week, date.weekday)
          : const <CourseSession>[];

      final items = sessions
          .map((s) => _itemJson(s, tableForCampus(s.campus)))
          .toList(growable: false);

      final isToday = offset == 0;
      final remaining = isToday
          ? items
              .where((e) => (e['endMinutes'] as int? ?? 0) > nowMinutes)
              .length
          : items.length;

      days.add(<String, dynamic>{
        'date': _dateText(date),
        'dateText': '${date.month}月${date.day}日',
        'weekdayText': _weekdayText(date.weekday),
        'week': week,
        'empty': items.isEmpty,
        'remaining': remaining,
        'remainingText': _remainingText(
          isToday: isToday,
          empty: items.isEmpty,
          remaining: remaining,
        ),
        'focus': _pickFocus(items, isToday ? nowMinutes : -1),
        'sessions': items,
      });
    }

    return WidgetPayload(<String, dynamic>{
      'schemaVersion': schemaVersion,
      'generatedAt': current.toIso8601String(),
      'semester': snapshot.semester.name,
      'accent': _hex(accent),
      'days': days,
    });
  }

  static String? _hex(Color? color) {
    if (color == null) return null;
    final argb = color.toARGB32();
    return '#${argb.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  static Map<String, dynamic> _itemJson(
    CourseSession session,
    PeriodTable table,
  ) {
    final span = table.spanText(session.startRow, session.endRow);
    final start = table.startMinutes(session.startRow);
    final end = table.endMinutes(session.endRow);
    return <String, dynamic>{
      'periodText': table.labelSpan(session.startRow, session.endRow),
      'name': session.name,
      'place': session.place,
      'timeText': span,
      'campus': session.campus,
      'noon': start == null || end == null,
      'startMinutes': start ?? 0,
      'endMinutes': end ?? 0,
    };
  }

  /// 正在上课 > 下一节 > 今天最后一节 > 空。
  static Map<String, dynamic>? _pickFocus(
    List<Map<String, dynamic>> items,
    int nowMinutes,
  ) {
    if (items.isEmpty) return null;
    if (nowMinutes >= 0) {
      for (final item in items) {
        final start = item['startMinutes'] as int? ?? 0;
        final end = item['endMinutes'] as int? ?? 0;
        if (start <= nowMinutes && nowMinutes < end) {
          return <String, dynamic>{...item, 'state': '正在上课'};
        }
      }
      for (final item in items) {
        if ((item['startMinutes'] as int? ?? 0) > nowMinutes) {
          return <String, dynamic>{...item, 'state': '下一节'};
        }
      }
    }
    final last = items.last;
    return <String, dynamic>{...last, 'state': '今日课程'};
  }

  static String _remainingText({
    required bool isToday,
    required bool empty,
    required int remaining,
  }) {
    if (empty) return isToday ? '今天没有课程安排' : '当天没有课程安排';
    if (remaining == 0) return isToday ? '今天的课已结束' : '当天没有剩余课程';
    return '${isToday ? '今天' : '当天'}剩余$remaining门课';
  }

  static String _dateText(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static String _weekdayText(int weekday) => switch (weekday) {
        1 => '星期一',
        2 => '星期二',
        3 => '星期三',
        4 => '星期四',
        5 => '星期五',
        6 => '星期六',
        _ => '星期日',
      };
}
