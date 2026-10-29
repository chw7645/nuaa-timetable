import '../core/time/week_calendar.dart';

/// 学期第 1 周起始日。
///
/// 教务接口只下发学期 id 与总周数，不下发开学日期，因此第 1 周周一采用
/// "内置校历表 + 规则兜底"：
///  * 内置表按学期 id 记录已核实的开学日；
///  * 未收录时按"开学周所在周的周一"推断（秋季 9 月 1 日 / 春季 2 月 20 日）。
///
/// 学期 402（2026-2027 学年秋季）已用真实课表交叉验证：
/// 该学期课表中"基础会计学Ⅰ"周次位图排除第 8 周、包含第 9 周，
/// 而 2026-10-29（星期四）当天确有该课，因此当天为第 9 周，
/// 反推第 1 周周一 = 2026-08-31。
class SemesterCalendar {
  SemesterCalendar._();

  static const Map<int, String> _known = <int, String>{
    402: '2026-08-31',
  };

  static DateTime week1MondayFor(int semesterId, {DateTime? now}) {
    final known = _known[semesterId];
    if (known != null) {
      final parsed = DateTime.tryParse(known);
      if (parsed != null) return WeekCalendar.mondayOf(parsed);
    }
    final today = now ?? DateTime.now();
    final anchor = today.month >= 8
        ? DateTime(today.year, 9, 1)
        : DateTime(today.year, 2, 20);
    return WeekCalendar.mondayOf(anchor);
  }

  /// 供设置页展示的已知校历条目。
  static Map<int, DateTime> get knownEntries => _known.map(
        (k, v) => MapEntry(k, DateTime.parse(v)),
      );
}
