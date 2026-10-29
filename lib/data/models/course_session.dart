/// 一次具体的上课安排（同一门课不同时间段是多条）。
class CourseSession {
  const CourseSession({
    required this.name,
    required this.code,
    required this.teacher,
    required this.place,
    required this.campus,
    required this.dayOfWeek,
    required this.startRow,
    required this.endRow,
    required this.weeks,
    required this.weekText,
    this.taskId = '',
    this.weeksUnknown = false,
    this.credit,
    this.category = '',
    this.courseCode = '',
  });

  final String name;
  final String code;
  final String teacher;
  final String place;

  /// 由地点前缀判定的校区（见 `CampusResolver`）。
  final String campus;

  /// 1 = 周一 … 7 = 周日。
  final int dayOfWeek;

  /// 教务网格行号（0 基，13 行制）。
  final int startRow;
  final int endRow;

  /// 周次位图：第 w 周对应 `1 << (w - 1)`，0 基位。
  final int weeks;

  /// 原始周次文本，仅用于排错与详情展示。
  final String weekText;

  final String taskId;

  /// 解析失败时的兜底标记：按"每周都上"处理，避免漏课。
  final bool weeksUnknown;

  /// 学分。来自课表响应末尾「课程列表」表格的 `学分` 列；
  /// 少数课程（如跨院系选课）该列为空，此时为 null。
  final double? credit;

  /// 课程类别，如 `通识必修课` / `专业选修课`。可能为空。
  final String category;

  /// 教务的课程代码（8 位，如 `08101240`）。
  ///
  /// 与 [code] 不同：[code] 是 `TaskActivity` 中下发的最末级任务编号，
  /// 仅用于区分课程序号，不能与「课程列表」的代码互查。
  final String courseCode;

  bool hasWeek(int week) {
    if (weeksUnknown) return true;
    if (week <= 0) return false;
    return (weeks >> (week - 1)) & 1 == 1;
  }

  bool get hasCredit => credit != null && credit! > 0;

  /// 学分展示文案，如 `2.5 学分`；无数据时返回空串。
  String get creditText {
    final value = credit;
    if (value == null || value <= 0) return '';
    final text = value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1);
    return '$text 学分';
  }

  String get key =>
      '$code|$name|$teacher|$dayOfWeek|$startRow|$endRow|$place';

  CourseSession copyWith({
    int? weeks,
    String? weekText,
    bool? weeksUnknown,
    double? credit,
    String? category,
    String? courseCode,
  }) {
    return CourseSession(
      name: name,
      code: code,
      teacher: teacher,
      place: place,
      campus: campus,
      dayOfWeek: dayOfWeek,
      startRow: startRow,
      endRow: endRow,
      weeks: weeks ?? this.weeks,
      weekText: weekText ?? this.weekText,
      taskId: taskId,
      weeksUnknown: weeksUnknown ?? this.weeksUnknown,
      credit: credit ?? this.credit,
      category: category ?? this.category,
      courseCode: courseCode ?? this.courseCode,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'n': name,
        'c': code,
        't': teacher,
        'p': place,
        'cp': campus,
        'd': dayOfWeek,
        's': startRow,
        'e': endRow,
        'w': weeks,
        'wt': weekText,
        'id': taskId,
        if (weeksUnknown) 'wu': true,
        if (credit != null) 'cr': credit,
        if (category.isNotEmpty) 'cat': category,
        if (courseCode.isNotEmpty) 'cc': courseCode,
      };

  factory CourseSession.fromJson(Map<String, dynamic> json) => CourseSession(
        name: '${json['n'] ?? ''}',
        code: '${json['c'] ?? ''}',
        teacher: '${json['t'] ?? ''}',
        place: '${json['p'] ?? ''}',
        campus: '${json['cp'] ?? ''}',
        dayOfWeek: (json['d'] as num?)?.toInt() ?? 1,
        startRow: (json['s'] as num?)?.toInt() ?? 0,
        endRow: (json['e'] as num?)?.toInt() ?? 0,
        weeks: (json['w'] as num?)?.toInt() ?? 0,
        weekText: '${json['wt'] ?? ''}',
        taskId: '${json['id'] ?? ''}',
        weeksUnknown: json['wu'] == true,
        credit: (json['cr'] as num?)?.toDouble(),
        category: '${json['cat'] ?? ''}',
        courseCode: '${json['cc'] ?? ''}',
      );
}
