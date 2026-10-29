import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/time/period_table.dart';
import '../data/models/timetable_snapshot.dart';
import 'widget_payload.dart';

/// 与原生 AppWidget 的唯一通道（单向 Dart → 原生）。
class WidgetSyncService {
  WidgetSyncService._();

  static WidgetSyncService instance = WidgetSyncService._();

  static const MethodChannel _defaultChannel =
      MethodChannel('nuaa/timetable_widget');

  MethodChannel _channel = _defaultChannel;

  /// 覆盖点：单元测试可替换为内存实现。
  @visibleForTesting
  static set channel(MethodChannel value) => instance._channel = value;

  int _lastSyncHash = 0;

  Future<void> sync({
    required TimetableSnapshot snapshot,
    required PeriodTable Function(String campus) tableForCampus,
    Color? accent,
    bool force = false,
  }) async {
    final payload = WidgetPayload.build(
      snapshot: snapshot,
      tableForCampus: tableForCampus,
      accent: accent,
    );
    final encoded = jsonEncode(payload.json);
    final hash = encoded.hashCode;
    if (!force && hash == _lastSyncHash) return;
    _lastSyncHash = hash;
    await _invoke('sync', encoded);
  }

  Future<void> clear() async {
    _lastSyncHash = 0;
    await _invoke('clear', null);
  }

  /// 仅触发原生重绘（例如跨日、主题切换后）。
  Future<void> refresh() => _invoke('refresh', null);

  Future<void> _invoke(String method, Object? arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // 桌面调试或单元测试环境没有原生实现，静默忽略。
    } catch (e) {
      debugPrint('小组件同步失败（$method）：$e');
    }
  }
}
