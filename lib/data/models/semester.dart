import '../../core/time/week_calendar.dart';

class Semester {
  const Semester({
    required this.id,
    required this.name,
    required this.weekCount,
    required this.week1Monday,
  });

  final int id;
  final String name;
  final int weekCount;

  /// 第 1 周周一。
  final DateTime week1Monday;

  WeekCalendar get calendar =>
      WeekCalendar(week1Monday: week1Monday, weekCount: weekCount);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'weekCount': weekCount,
        'week1Monday':
            '${week1Monday.year.toString().padLeft(4, '0')}-'
                '${week1Monday.month.toString().padLeft(2, '0')}-'
                '${week1Monday.day.toString().padLeft(2, '0')}',
      };

  factory Semester.fromJson(Map<String, dynamic> json) => Semester(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: '${json['name'] ?? ''}',
        weekCount: (json['weekCount'] as num?)?.toInt() ?? 20,
        week1Monday: DateTime.tryParse('${json['week1Monday']}') ??
            DateTime(DateTime.now().year, 9, 1),
      );
}
