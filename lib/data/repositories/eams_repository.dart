import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../core/network/app_exception.dart';
import '../../core/network/http_session.dart';
import '../campus_resolver.dart';
import '../models/course_session.dart';
import '../models/semester.dart';
import '../models/timetable_snapshot.dart';
import '../parsers/cas_login_parser.dart';
import '../parsers/course_table_entry_parser.dart';
import '../parsers/course_table_parser.dart';
import '../semester_calendar.dart';

/// 教务系统抓取。
///
/// 抓取策略：
///  1. 先在 `courseTableForStd.action` 拿到当前学期 id、课表对象 id(ids)、总周数；
///  2. 一次性抓取整学期（`startWeek` 留空）；
///  3. 若整学期响应无法解析，降级为逐周抓取并按位或合并（week-union）。
class EamsRepository {
  EamsRepository(this.session);

  final HttpSession session;

  Uri get _entryUri =>
      Uri.parse('${AppConfig.eamsBase}${AppConfig.eamsEntryPath}');

  Uri get _tableUri =>
      Uri.parse('${AppConfig.eamsBase}${AppConfig.eamsTablePath}');

  Future<TimetableSnapshot> fetchTimetable() async {
    final entryPage = await session.get(_entryUri);
    _ensureAuthorized(entryPage);
    final entry = CourseTableEntryParser.parse(entryPage.body);
    final semesterName = await _resolveSemesterName(entry.semesterId);

    List<CourseSession> sessions;
    var usedFallback = false;
    try {
      sessions = await _fetchWholeSemester(entry);
    } on ParseException {
      usedFallback = true;
      sessions = await _fetchWeekByWeek(entry);
    }

    if (usedFallback && kDebugMode) {
      debugPrint('整学期抓取不可用，已改为逐周抓取（${sessions.length} 条）');
    }

    final defaultCampus = _dominantCampus(sessions);
    final relocated = sessions
        .map((s) => s.campus == CampusResolver.unknown && defaultCampus != null
            ? CourseSession(
                name: s.name,
                code: s.code,
                teacher: s.teacher,
                place: s.place,
                campus: defaultCampus,
                dayOfWeek: s.dayOfWeek,
                startRow: s.startRow,
                endRow: s.endRow,
                weeks: s.weeks,
                weekText: s.weekText,
                taskId: s.taskId,
                weeksUnknown: s.weeksUnknown,
              )
            : s)
        .toList();

    return TimetableSnapshot(
      semester: Semester(
        id: entry.semesterId,
        name: semesterName,
        weekCount: entry.weekCount,
        week1Monday: SemesterCalendar.week1MondayFor(entry.semesterId),
      ),
      sessions: relocated,
      fetchedAt: DateTime.now(),
    );
  }

  Future<List<CourseSession>> _fetchWholeSemester(CourseTableEntry entry) async {
    final uri = _tableUri.replace(queryParameters: <String, String>{
      'ignoreHead': '1',
      'setting.kind': 'std',
      'startWeek': '',
      'semester.id': '${entry.semesterId}',
      'ids': entry.ids,
    });
    final result = await session.get(uri);
    _ensureAuthorized(result);
    // 传入学期周数：用于判定 weeks 位图是否为 53 位定长格式。
    final parsed = CourseTableParser.parse(
      result.body,
      weekCount: entry.weekCount,
    );
    return parsed.sessions;
  }

  /// 逐周抓取：每周边界单独请求，按位或合并同一门课的周次。
  Future<List<CourseSession>> _fetchWeekByWeek(CourseTableEntry entry) async {
    final total = entry.weekCount.clamp(1, AppConfig.maxWeekFetch);
    final union = <String, CourseSession>{};
    var failureStreak = 0;

    for (var week = 1; week <= total; week++) {
      final uri = _tableUri.replace(queryParameters: <String, String>{
        'ignoreHead': '1',
        'setting.kind': 'std',
        'startWeek': '$week',
        'semester.id': '${entry.semesterId}',
        'ids': entry.ids,
      });
      try {
        final result = await session.get(uri);
        _ensureAuthorized(result);
        final parsed = CourseTableParser.parse(result.body);
        for (final s in parsed.sessions) {
          final mask = 1 << (week - 1);
          final existed = union[s.key];
          union[s.key] = existed == null
              ? s.copyWith(weeks: mask)
              : existed.copyWith(weeks: existed.weeks | mask);
        }
        failureStreak = 0;
      } on ParseException {
        // 该周无课或结构异常，跳过但不清空已有结果。
        failureStreak++;
      }
      if (failureStreak >= 5) break;
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    if (union.isEmpty) {
      throw const ParseException('未能获取课表数据，请确认本学期课表已在教务系统生成');
    }
    return union.values.toList();
  }

  Future<String> _resolveSemesterName(int semesterId) async {
    try {
      final uri = Uri.parse('${AppConfig.eamsBase}${AppConfig.eamsDataQueryPath}')
          .replace(queryParameters: <String, String>{
        'dataType': 'semesterCalendar'
      });
      final result = await session.get(uri);
      final pattern =
          RegExp(r'\{id:(\d+),schoolYear:"([^"]*)",name:"([^"]*)"\}');
      for (final m in pattern.allMatches(result.body)) {
        if (int.tryParse(m.group(1)!) == semesterId) {
          final year = m.group(2)!;
          final term = m.group(3)!;
          return '$year 学年第$term学期';
        }
      }
    } catch (_) {
      // 学期名称仅是展示信息，失败不影响主流程。
    }
    return '';
  }

  String? _dominantCampus(List<CourseSession> sessions) {
    final counter = <String, int>{};
    for (final s in sessions) {
      if (s.campus == CampusResolver.unknown) continue;
      counter[s.campus] = (counter[s.campus] ?? 0) + 1;
    }
    if (counter.isEmpty) return null;
    final entries = counter.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  void _ensureAuthorized(HttpResult result) {
    if (result.statusCode == 401 || result.statusCode == 403) {
      throw const SessionExpiredException();
    }
    if (CasLoginParser.looksLikeLoginPage(result.body) &&
        !result.body.contains('semesterCalendar')) {
      throw const SessionExpiredException();
    }
  }
}
