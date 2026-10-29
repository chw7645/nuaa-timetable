import 'dart:math' as math;

import '../../core/config/app_config.dart';
import '../../core/network/app_exception.dart';
import '../campus_resolver.dart';
import '../models/course_session.dart';

class CourseTableParseResult {
  const CourseTableParseResult({
    required this.sessions,
    required this.unitCount,
    this.creditResolved = 0,
  });

  final List<CourseSession> sessions;
  final int unitCount;

  /// 成功匹配到学分的课程门数（去重后），用于诊断。
  final int creditResolved;

  /// 本学期学分合计（按课程去重，不按上课次数累加）。
  double get totalCredits {
    final seen = <String>{};
    var sum = 0.0;
    for (final s in sessions) {
      final credit = s.credit;
      if (credit == null || credit <= 0) continue;
      // 同一门课的多次上课共享学分，只在首次出现时累加。
      if (!seen.add(s.courseCode.isNotEmpty ? s.courseCode : s.name)) continue;
      sum += credit;
    }
    return sum;
  }
}

/// 「课程列表」表格里的一行：学分与类别。
class _CourseMeta {
  const _CourseMeta({
    required this.name,
    required this.code,
    required this.category,
    required this.credit,
  });

  final String name;
  final String code;
  final String category;
  final double? credit;
}

/// 解析 `courseTableForStd!courseTable.action` 返回的 TaskActivity 脚本。
///
/// 响应结构（已用真实数据核实）：
/// ```
/// var unitCount = 13;
/// activity = new TaskActivity(teacherIds, teacherNames, code, name, "", taskId,
///                             place, weeksBitmap, activityId, null, assistant,
///                             "", "", classNames);
/// index =3*unitCount+8;
/// table0.activities[index][…] = activity;
/// ```
/// 网格行顺序：第一…四节、午一节、午二节、第五…十一节（共 13 行）。
/// `index / unitCount` 为 0 基星期（周一 = 0），`index % unitCount` 为行号。
class CourseTableParser {
  CourseTableParser._();

  static final RegExp _ctor =
      RegExp(r'activity\s*=\s*new\s+TaskActivity\(');

  /// 教师姓名不在构造参数里：前两个实参是 JS 表达式
  /// `actTeacherId.join(',')` / `actTeacherName.join(',')`，
  /// 真正的姓名来自紧邻其前的 `var actTeachers = [{id:…,name:"张三"}];`。
  static final RegExp _actTeachers =
      RegExp(r'var\s+actTeachers\s*=\s*\[(.*?)\];', dotAll: true);
  static final RegExp _teacherName = RegExp(r'name:\s*"([^"]*)"');
  static final RegExp _indexAssign =
      RegExp(r'index\s*=\s*(\d+)\s*\*\s*unitCount\s*\+\s*(\d+)\s*;');
  static final RegExp _unitCount = RegExp(r'var\s+unitCount\s*=\s*(\d+)');

  /// 课表响应末尾附带的「课程列表」表格（含学分）。
  static final RegExp _tableTag =
      RegExp(r'<table\b[^>]*>([\s\S]*?)</table>', caseSensitive: false);
  static final RegExp _theadTag =
      RegExp(r'<thead\b[^>]*>([\s\S]*?)</thead>', caseSensitive: false);
  static final RegExp _trTag =
      RegExp(r'<tr\b[^>]*>([\s\S]*?)</tr>', caseSensitive: false);
  static final RegExp _tdTag =
      RegExp(r'<td\b[^>]*>([\s\S]*?)</td>', caseSensitive: false);

  static CourseTableParseResult parse(
    String html, {
    String? defaultCampus,

    /// 学期总周数。用于区分「定长位图」与「紧凑位图」的起始偏移，
    /// 见 [_parseWeeksBitmap]。
    int? weekCount,
  }) {
    final unitMatch = _unitCount.firstMatch(html);
    if (unitMatch == null) {
      throw const ParseException('课表数据格式无法识别（缺少 unitCount）');
    }
    final unitCount = math.min(
      int.tryParse(unitMatch.group(1)!) ?? 0,
      AppConfig.maxGridRows,
    );
    if (unitCount <= 0) {
      throw const ParseException('课表节次数量异常，无法解析');
    }

    final ctors = _ctor.allMatches(html).toList();
    final teacherArrays = _actTeachers.allMatches(html).toList();
    final metas = _parseCourseList(html);
    final merged = <String, CourseSession>{};

    for (var i = 0; i < ctors.length; i++) {
      final ctor = ctors[i];
      final blockEnd =
          i + 1 < ctors.length ? ctors[i + 1].start : html.length;
      final block = html.substring(ctor.end, blockEnd);
      final argsEnd = _findArgsEnd(block);
      if (argsEnd < 0) continue;
      final args = _splitArgs(block.substring(0, argsEnd));
      if (args.length < 8) continue;

      final name = _unquote(args[3]);
      if (name.isEmpty) continue;

      final code = _unquote(args[2]);
      final teacher = _resolveTeacher(args, ctor.start, teacherArrays);
      final taskId = args.length > 5 ? _unquote(args[5]) : '';
      final place = _unquote(args[6]);
      final weekBitmap = _unquote(args[7]);

      // 该 activity 占用的所有格子（连堂课时有多条 index）
      final cells = <int>[];
      for (final m in _indexAssign.allMatches(block.substring(argsEnd))) {
        final day = int.tryParse(m.group(1)!) ?? -1;
        final row = int.tryParse(m.group(2)!) ?? -1;
        if (day < 0 || day > 6 || row < 0 || row >= unitCount) continue;
        cells.add(day * unitCount + row);
      }
      if (cells.isEmpty) continue;

      // 按行号连续性分组，每组构成一次上课
      cells.sort();
      final runs = <List<int>>[];
      for (final cell in cells) {
        final day = cell ~/ unitCount;
        final row = cell % unitCount;
        if (runs.isNotEmpty) {
          final lastRun = runs.last;
          final lastCell = lastRun.last;
          final sameDay = lastCell ~/ unitCount == day;
          final adjacent = lastCell % unitCount + 1 == row;
          if (sameDay && adjacent) {
            lastRun.add(cell);
            continue;
          }
        }
        runs.add(<int>[cell]);
      }

      for (final run in runs) {
        final day = run.first ~/ unitCount + 1;
        final startRow = run.first % unitCount;
        final endRow = run.last % unitCount;
        final weeks = _parseWeeksBitmap(weekBitmap, weekCount);
        final meta = _resolveMeta(name, teacher, metas);
        final session = CourseSession(
          name: name,
          code: code,
          teacher: teacher,
          place: place,
          campus: CampusResolver.resolve(place, defaultCampus: defaultCampus),
          dayOfWeek: day,
          startRow: startRow,
          endRow: endRow,
          weeks: weeks.value,
          weekText: _weeksText(weeks.value),
          taskId: taskId,
          weeksUnknown: weeks.unknown,
          credit: meta?.credit,
          category: meta?.category ?? '',
          courseCode: meta?.code ?? '',
        );
        final existed = merged[session.key];
        if (existed == null) {
          merged[session.key] = session;
        } else {
          // 同一门课同一格子可能因分批下发而重复，按位或合并周次（week-union）。
          merged[session.key] = existed.copyWith(
            weeks: existed.weeks | session.weeks,
            weekText: _weeksText(existed.weeks | session.weeks),
            weeksUnknown: existed.weeksUnknown || session.weeksUnknown,
          );
        }
      }
    }

    if (merged.isEmpty) {
      throw const ParseException('未解析到任何课程，课表可能为空或教务系统结构已变化');
    }

    final sessions = merged.values.toList()
      ..sort((a, b) {
        final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
        return byDay != 0 ? byDay : a.startRow.compareTo(b.startRow);
      });

    final credited = <String>{};
    for (final s in sessions) {
      if (s.hasCredit) {
        credited.add(s.courseCode.isNotEmpty ? s.courseCode : s.name);
      }
    }

    return CourseTableParseResult(
      sessions: sessions,
      unitCount: unitCount,
      creditResolved: credited.length,
    );
  }

  /// 解析课表响应末尾的「课程列表」表格。
  ///
  /// 表头为：序号 / 课程代码 / 课程名称 / 课程类别 / 学分 / 课程序号 / 教师 / 教学班 / 备注。
  /// `TaskActivity` 里的课程编号与这里的「课程代码」不同源，因此以**课程名称**
  /// 建立索引，同名课程再用教师名消歧。
  static Map<String, List<_CourseMeta>> _parseCourseList(String html) {
    final byName = <String, List<_CourseMeta>>{};
    for (final table in _tableTag.allMatches(html)) {
      final body = table.group(1) ?? '';
      final head = _theadTag.firstMatch(body)?.group(1) ?? '';
      // 只认带「学分」列的表格，避免误吃课表里其它 grid。
      if (!head.contains('学分')) continue;

      for (final row in _trTag.allMatches(body)) {
        final cells = _tdTag
            .allMatches(row.group(1) ?? '')
            .map((m) => _cleanCell(m.group(1) ?? ''))
            .toList();
        if (cells.length < 5) continue;
        final code = cells[1];
        final name = cells[2];
        if (name.isEmpty) continue;
        final credit = double.tryParse(cells[4].replaceAll('，', '.'));
        final meta = _CourseMeta(
          name: name,
          code: code,
          category: cells[3],
          credit: (credit != null && credit > 0) ? credit : null,
        );
        byName.putIfAbsent(name, () => <_CourseMeta>[]).add(meta);
      }
    }
    return byName;
  }

  /// 按课程名（必要时叠加教师名）找到对应学分记录。
  static _CourseMeta? _resolveMeta(
    String name,
    String teacher,
    Map<String, List<_CourseMeta>> byName,
  ) {
    final candidates = byName[name];
    if (candidates == null || candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first;
    // 同名多教学班（分班上课）：学分一致，取第一条带学分的记录。
    for (final meta in candidates) {
      if (meta.credit != null) return meta;
    }
    return candidates.first;
  }

  /// 去掉单元格里的标签与 HTML 实体。
  static String _cleanCell(String raw) {
    final text = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return _decodeEntities(text).replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _decodeEntities(String text) {
    if (!text.contains('&')) return text;
    return text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }

  /// 从构造调用之前最近的 `actTeachers` 数组里取教师姓名。
  static String _resolveTeacher(
    List<String> args,
    int ctorStart,
    List<RegExpMatch> arrays,
  ) {
    RegExpMatch? last;
    for (final match in arrays) {
      if (match.start < ctorStart) {
        last = match;
      } else {
        break;
      }
    }
    if (last != null) {
      final names = _teacherName
          .allMatches(last.group(1) ?? '')
          .map((m) => m.group(1)?.trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (names.isNotEmpty) return names.join(',');
    }
    final raw = args.length > 1 ? _unquote(args[1]) : '';
    return raw.contains('join(') ? '' : raw;
  }

  /// 找到参数列表结束的 `)`（跳过字符串内与嵌套括号）。
  static int _findArgsEnd(String block) {
    var depth = 0;
    String? quote;
    for (var i = 0; i < block.length; i++) {
      final ch = block[i];
      if (quote != null) {
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
      } else if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        if (depth == 0) return i;
        depth--;
      }
    }
    return -1;
  }

  static List<String> _splitArgs(String raw) {
    final args = <String>[];
    final buffer = StringBuffer();
    String? quote;
    var depth = 0;
    for (var i = 0; i < raw.length; i++) {
      final ch = raw[i];
      if (quote != null) {
        buffer.write(ch);
        if (ch == quote) quote = null;
        continue;
      }
      if (ch == '"' || ch == "'") {
        quote = ch;
        buffer.write(ch);
      } else if (ch == '(') {
        depth++;
        buffer.write(ch);
      } else if (ch == ')') {
        depth--;
        buffer.write(ch);
      } else if (ch == ',' && depth == 0) {
        args.add(buffer.toString().trim());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }
    if (buffer.isNotEmpty) args.add(buffer.toString().trim());
    return args;
  }

  static String _unquote(String value) {
    var v = value.trim();
    if (v.length >= 2 &&
        ((v.startsWith('"') && v.endsWith('"')) ||
            (v.startsWith("'") && v.endsWith("'")))) {
      v = v.substring(1, v.length - 1);
    }
    if (v == 'null' || v == 'undefined') return '';
    return v;
  }

  /// 解析 `weeks` 位图字符串。
  ///
  /// **偏移陷阱**：金智 EAMS 下发的位图是**定长 53 位**（覆满一个自然年），
  /// 第 0 位是「第 0 周」这个并不存在的占位，真正的第 1 周落在第 1 位。
  /// 如果按「第 0 位 = 第 1 周」解释，所有课程都会**整体延后一周**。
  ///
  /// 这不是推测：拿教务页面「我的课表」显示的周次逐条比对 24 条课程，
  /// 例如
  /// - 线性代数（周二 1-2）：教务 `7-16 周`，位图 `1` 在索引 7..16；
  /// - 应用统计学（周一 1-2）：教务 `1-10 周`，位图 `1` 在索引 1..10；
  /// - 基础会计学Ⅰ（周四 7-8）：教务 `3-6,8-17 周`，位图 `1` 在索引 3..6、8..17。
  ///
  /// 全部 24 条都以「索引 i = 第 i 周」吻合，按旧逻辑则条条多出一周。
  ///
  /// 判断依据：位图长度明显大于学期周数即为定长格式；若某所学校下发的是
  /// 长度恰好等于周数的紧凑位图，则仍按「第 0 位 = 第 1 周」处理。
  static ({int value, bool unknown}) _parseWeeksBitmap(
    String bitmap,
    int? weekCount,
  ) {
    if (bitmap.isEmpty || !bitmap.contains('1')) {
      return (value: 0, unknown: true);
    }
    final padded = weekCount == null
        ? bitmap.length > 30
        : bitmap.length > weekCount + 2;
    final offset = padded ? 1 : 0;

    // 只取学期内的位，避免把位图尾部的占位 `1` 当成学期末的课。
    final limit = weekCount == null
        ? math.min(bitmap.length, 62)
        : math.min(bitmap.length, weekCount + offset);

    var value = 0;
    for (var i = offset; i < limit; i++) {
      if (bitmap[i] == '1') value |= 1 << (i - offset);
    }
    return (value: value, unknown: false);
  }

  /// 由位图反推可读文本。
  ///
  /// 教务页面的格式就是「连续区间用逗号分隔」（如 `3-6,8-17周`、`1-2,4-14周`）。
  /// 只有当整门课都落在单周、且间隔恒为 2 时，才压缩成 `1-7(隔周)`。
  ///
  /// 旧实现边扫描边判断"间隔 2"，会把 `1-2,4-14` 误并成 `1-4(隔),5-15`
  /// （先看到 1→4 的间隔 2 就断定隔周，忽略了 5 紧跟 4 这一事实）。
  /// 现在改为**先切连续区间，再判断区间组是否构成隔周**。
  static String _weeksText(int bitmap) {
    if (bitmap == 0) return '周次未知';
    final weeks = <int>[];
    for (var w = 1; w <= 62; w++) {
      if ((bitmap >> (w - 1)) & 1 == 1) weeks.add(w);
    }
    if (weeks.isEmpty) return '周次未知';

    // 第一步：按"相邻差 1"切成连续区间。
    final runs = <List<int>>[];
    for (final w in weeks) {
      if (runs.isNotEmpty && w == runs.last.last + 1) {
        runs.last.add(w);
      } else {
        runs.add(<int>[w]);
      }
    }

    // 第二步：若每个区间都只有一个周、且区间间隔恒为 2，才是真正的隔周。
    final allSingle = runs.every((r) => r.length == 1);
    var everyOther = allSingle && runs.length >= 2;
    if (everyOther) {
      for (var i = 0; i + 1 < runs.length; i++) {
        if (runs[i + 1].first - runs[i].first != 2) {
          everyOther = false;
          break;
        }
      }
    }
    if (everyOther) {
      return '${runs.first.first}-${runs.last.first}(隔周)周';
    }

    final parts = runs.map(
      (r) => r.length == 1 ? '${r.first}' : '${r.first}-${r.last}',
    );
    return '${parts.join(',')}周';
  }
}
