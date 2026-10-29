/// 由上课地点推断校区。
///
/// 教务地点形如 `T1403(天目湖)`、`C210(天目湖)`、`实地讲习（天目湖）(天目湖)`，
/// 通常括号内即校区名，因此优先精确匹配括号内容，其次按楼栋前缀推断。
class CampusResolver {
  CampusResolver._();

  static const String unknown = '未知校区';

  static const List<String> known = <String>['天目湖', '将军路', '明故宫'];

  static final RegExp _bracket =
      RegExp(r'[（(]([^（()）]{2,8})[)）]');

  static String resolve(String place, {String? defaultCampus}) {
    final trimmed = place.trim();
    if (trimmed.isEmpty) return defaultCampus ?? unknown;

    for (final match in _bracket.allMatches(trimmed)) {
      final inner = match.group(1)!.trim();
      for (final campus in known) {
        if (inner.contains(campus)) return campus;
      }
    }

    for (final campus in known) {
      if (trimmed.contains(campus)) return campus;
    }

    // 楼栋前缀规则：T = 天目湖，J/D = 将军路，M/A/B = 明故宫。
    final prefix = trimmed.substring(0, 1).toUpperCase();
    switch (prefix) {
      case 'T':
        return '天目湖';
      case 'J':
      case 'D':
        return '将军路';
      case 'M':
      case 'A':
      case 'B':
        return '明故宫';
      default:
        return defaultCampus ?? unknown;
    }
  }
}
