import '../../core/config/app_config.dart';
import '../../core/network/app_exception.dart';

/// `courseTableForStd.action` 页面里的入口参数。
class CourseTableEntry {
  const CourseTableEntry({
    required this.semesterId,
    required this.ids,
    required this.weekCount,
    this.unitCount,
  });

  final int semesterId;

  /// 学生课表对象 id，页面由 JS 动态注入（`addInput(form,"ids","…")`）。
  final String ids;

  final int weekCount;
  final int? unitCount;
}

class CourseTableEntryParser {
  CourseTableEntryParser._();

  static final RegExp _semester =
      RegExp(r'\.semesterCalendar\(\{[^}]*value:"(\d+)"');
  static final RegExp _ids = RegExp(r'addInput\(form,"ids","(\d+)"\)');
  static final RegExp _unitCount = RegExp(r'var\s+unitCount\s*=\s*(\d+)');
  static final RegExp _weekOption =
      RegExp(r'<option value="(\d+)">第\d+周</option>');

  static CourseTableEntry parse(String html) {
    final semesterMatch = _semester.firstMatch(html);
    if (semesterMatch == null) {
      throw const ParseException('无法识别当前学期，教务系统页面结构可能已变化');
    }
    final idsMatch = _ids.firstMatch(html);
    if (idsMatch == null) {
      throw const ParseException('无法获取课表对象标识（ids），请稍后重试');
    }

    var weekCount = 0;
    for (final m in _weekOption.allMatches(html)) {
      final v = int.tryParse(m.group(1) ?? '') ?? 0;
      if (v > weekCount) weekCount = v;
    }
    if (weekCount == 0) weekCount = 20;
    if (weekCount > AppConfig.maxWeekCount) weekCount = AppConfig.maxWeekCount;

    final unitMatch = _unitCount.firstMatch(html);
    return CourseTableEntry(
      semesterId: int.parse(semesterMatch.group(1)!),
      ids: idsMatch.group(1)!,
      weekCount: weekCount,
      unitCount: unitMatch == null ? null : int.tryParse(unitMatch.group(1)!),
    );
  }
}
