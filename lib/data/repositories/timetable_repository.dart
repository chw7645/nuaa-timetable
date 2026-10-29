import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/network/app_exception.dart';
import '../local/prefs_store.dart';
import '../models/timetable_snapshot.dart';
import 'eams_repository.dart';

/// 课表缓存 + 远端刷新。
class TimetableRepository {
  TimetableRepository({required this.prefs, required this.eams});

  final PrefsStore prefs;
  final EamsRepository eams;

  TimetableSnapshot? loadCache() {
    final raw = prefs.getString(PrefsKeys.timetableCache);
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final snapshot =
          TimetableSnapshot.fromJson(json.cast<String, dynamic>());
      // schema 不兼容时丢弃缓存，避免半解析数据污染界面。
      if (snapshot.schemaVersion != TimetableSnapshot.currentSchema) {
        debugPrint('课表缓存版本不兼容，已丢弃（${snapshot.schemaVersion}）');
        return null;
      }
      return snapshot;
    } catch (e) {
      debugPrint('课表缓存解析失败：$e');
      return null;
    }
  }

  Future<void> saveCache(TimetableSnapshot snapshot) async {
    await prefs.setString(
      PrefsKeys.timetableCache,
      jsonEncode(snapshot.toJson()),
    );
  }

  Future<TimetableSnapshot> refresh() async {
    final snapshot = await eams.fetchTimetable();
    await saveCache(snapshot);
    return snapshot;
  }

  Future<void> clearCache() async {
    await prefs.remove(PrefsKeys.timetableCache);
  }

  /// 供界面统一处理异常文案。
  static String describe(Object error) {
    if (error is AppException) return error.message;
    return '发生未知错误：$error';
  }
}
