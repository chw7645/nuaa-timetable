import 'package:flutter/foundation.dart';

import '../../core/time/period_table.dart';
import '../../data/models/course_session.dart';
import '../../data/models/timetable_snapshot.dart';
import 'notification_service.dart';

/// 批量重建上课提醒。
///
/// 规则：
///  * 只为"未来 14 天内、且当天有课"的安排排提醒；
///  * 午一节/午二节官方作息未定义时刻，不排提醒（避免编造时间）；
///  * 每次刷新课表后先 `cancelAll` 再重建，避免残留旧提醒。
class ReminderScheduler {
  ReminderScheduler._();

  static const int maxId = 100000;

  static Future<void> rebuild({
    required TimetableSnapshot snapshot,
    required PeriodTable Function(String campus) tableForCampus,
    required int minutesBefore,
    required bool enabled,
  }) async {
    await NotificationService.instance.cancelAll();
    if (!enabled) return;
    final granted = await NotificationService.instance.ensurePermission();
    if (!granted) {
      debugPrint('未获得通知或精确闹钟权限，跳过提醒排期');
      return;
    }

    final now = DateTime.now();
    final calendar = snapshot.semester.calendar;
    var scheduled = 0;

    for (var offset = 0; offset < 14; offset++) {
      final date = DateTime(now.year, now.month, now.day)
          .add(Duration(days: offset));
      final week = calendar.weekOf(date);
      if (week < 1 || week > snapshot.semester.weekCount) continue;
      final sessions = snapshot.sessionsOfDay(week, date.weekday);
      for (final session in sessions) {
        final table = tableForCampus(session.campus);
        final startMinutes = table.startMinutes(session.startRow);
        if (startMinutes == null) continue; // 午间加课
        final start = DateTime(date.year, date.month, date.day)
            .add(Duration(minutes: startMinutes - minutesBefore));
        if (!start.isAfter(now)) continue;
        await NotificationService.instance.scheduleAt(
          id: maxId + scheduled,
          title: '即将上课：${session.name}',
          body: _body(session, table),
          when: start,
          payload: session.key,
        );
        scheduled++;
      }
    }
    debugPrint('已排入 $scheduled 条上课提醒（提前 $minutesBefore 分钟）');
  }

  static String _body(CourseSession session, PeriodTable table) {
    final span = table.spanText(session.startRow, session.endRow);
    final parts = <String>[
      table.labelSpan(session.startRow, session.endRow),
      if (span.isNotEmpty) span,
      if (session.place.isNotEmpty) session.place,
    ];
    return parts.join(' · ');
  }
}
