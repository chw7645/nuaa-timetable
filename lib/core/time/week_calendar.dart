/// 周次与日期换算。
class WeekCalendar {
  WeekCalendar({required this.week1Monday, required this.weekCount});

  /// 第 1 周周一（本地零点）。
  final DateTime week1Monday;
  final int weekCount;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime mondayOf(DateTime d) {
    final day = dateOnly(d);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  /// 返回 1 基周次；早于第 1 周返回 0，超出学期返回 weekCount + 1。
  int weekOf(DateTime date) {
    final diff = dateOnly(date).difference(dateOnly(week1Monday)).inDays;
    final week = (diff / 7).floor() + 1;
    if (diff < 0) return 0;
    if (week > weekCount) return weekCount + 1;
    return week;
  }

  DateTime mondayOfWeek(int week) =>
      week1Monday.add(Duration(days: (week - 1) * 7));

  DateTime dateOf(int week, int weekday) =>
      mondayOfWeek(week).add(Duration(days: weekday - 1));

  /// 该周的 7 天（周一至周日）。
  List<DateTime> daysOfWeek(int week) =>
      List<DateTime>.generate(7, (i) => dateOf(week, i + 1));
}
