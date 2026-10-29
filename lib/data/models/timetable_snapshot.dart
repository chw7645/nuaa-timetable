import 'course_session.dart';
import 'semester.dart';

/// 课表快照：本地缓存的唯一数据结构。
class TimetableSnapshot {
  const TimetableSnapshot({
    required this.semester,
    required this.sessions,
    required this.fetchedAt,
    this.studentName = '',
    this.schemaVersion = currentSchema,
  });

  /// 缓存结构版本。
  ///
  /// 2：修正 weeks 位图起始偏移（此前所有课程整体延后一周），
  /// 旧缓存必须作废并重新抓取，否则界面会继续显示错一周的数据。
  static const int currentSchema = 2;

  final Semester semester;
  final List<CourseSession> sessions;
  final DateTime fetchedAt;
  final String studentName;
  final int schemaVersion;

  /// 当周课程。
  List<CourseSession> sessionsOf(int week) =>
      sessions.where((s) => s.hasWeek(week)).toList(growable: false);

  /// 某天（周一 = 1）的课程，按行号升序。
  List<CourseSession> sessionsOfDay(int week, int dayOfWeek) {
    final list = sessions
        .where((s) => s.dayOfWeek == dayOfWeek && s.hasWeek(week))
        .toList();
    list.sort((a, b) => a.startRow.compareTo(b.startRow));
    return list;
  }

  /// 课表主校区（出现次数最多的校区），用于自动选择作息表。
  String? get dominantCampus {
    final counter = <String, int>{};
    for (final s in sessions) {
      if (s.campus.isEmpty || s.campus == '未知校区') continue;
      counter[s.campus] = (counter[s.campus] ?? 0) + 1;
    }
    if (counter.isEmpty) return null;
    final sorted = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  /// 同一门课的聚合（用于详情页"上课安排"列表）。
  Map<String, List<CourseSession>> get groupedByCourse {
    final map = <String, List<CourseSession>>{};
    for (final s in sessions) {
      final key = '${s.code}|${s.name}';
      map.putIfAbsent(key, () => <CourseSession>[]).add(s);
    }
    return map;
  }

  /// 整学期是否有周末课程。
  ///
  /// 没有周末课就只渲染周一至周五：7 列挤在 360dp 屏上每列仅 43dp，
  /// 课程名会被压成"应用统…"；5 列时每列约 60dp，文字才能读。
  /// 用整学期而非当周判断，避免翻周时列数跳变。
  bool get hasWeekendCourses => sessions.any((s) => s.dayOfWeek >= 6);

  /// 课表网格显示的列数（5 或 7）。
  int get visibleDayCount => hasWeekendCourses ? 7 : 5;

  /// 课程名 → 调色板索引。
  ///
  /// 按课程在快照中首次出现的顺序分配（0,1,2…），而不是用 `hashCode`：
  /// 字符串哈希取模会分布不均——实测 24 条课只命中 8 个颜色里的 6 个，
  /// 有两色从未出现，撞色概率反而变高。顺序分配能保证前 8 门课各占一色，
  /// 且同一门课在任何周、任何视图下颜色都一致。
  Map<String, int> get courseColorIndexes {
    final map = <String, int>{};
    for (final s in sessions) {
      map.putIfAbsent(s.name, () => map.length);
    }
    return map;
  }

  /// 去重后的课程门数（同一门课多次上课只算一门）。
  int get courseCount => _uniqueCourses().length;

  /// 本学期学分合计：按课程去重累加，未解析到学分的课程不计入。
  double get totalCredits {
    var sum = 0.0;
    for (final s in _uniqueCourses().values) {
      final credit = s.credit;
      if (credit != null && credit > 0) sum += credit;
    }
    return sum;
  }

  /// 学分合计的展示文案，如 `29 学分`；无数据时为空串。
  String get totalCreditsText {
    final value = totalCredits;
    if (value <= 0) return '';
    return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)} 学分';
  }

  /// 课程代码（缺失时退回课程名）→ 第一节课的聚合。
  Map<String, CourseSession> _uniqueCourses() {
    final map = <String, CourseSession>{};
    for (final s in sessions) {
      map.putIfAbsent(
          s.courseCode.isNotEmpty ? s.courseCode : s.name, () => s);
    }
    return map;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'fetchedAt': fetchedAt.toIso8601String(),
        'studentName': studentName,
        'semester': semester.toJson(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  factory TimetableSnapshot.fromJson(Map<String, dynamic> json) {
    final rawSessions = (json['sessions'] as List?) ?? const <dynamic>[];
    return TimetableSnapshot(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      fetchedAt: DateTime.tryParse('${json['fetchedAt']}') ?? DateTime.now(),
      studentName: '${json['studentName'] ?? ''}',
      semester: Semester.fromJson(
          (json['semester'] as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{}),
      sessions: rawSessions
          .whereType<Map>()
          .map((e) => CourseSession.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
