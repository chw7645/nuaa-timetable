import 'dart:async';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/network/app_exception.dart';
import '../core/network/http_session.dart';
import '../core/time/period_table.dart';
import '../data/credentials_store.dart';
import '../data/local/prefs_store.dart';
import '../data/models/course_session.dart';
import '../data/models/timetable_snapshot.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/eams_repository.dart';
import '../data/repositories/timetable_repository.dart';
import '../features/notifications/notification_service.dart';
import '../features/notifications/reminder_scheduler.dart';
import '../theme/theme_controller.dart';
import '../widget_bridge/widget_sync_service.dart';

/// 全局状态：登录态、课表数据、周次、设置项。
class AppController extends ChangeNotifier {
  AppController({required this.prefs, required this.theme}) {
    credentials = CredentialsStore(prefs);
    reminderMinutes = prefs.getInt(PrefsKeys.reminderMinutes) ?? 10;
    remindersEnabled = prefs.getBool(PrefsKeys.remindersEnabled);
    periodTrack = prefs.getString(PrefsKeys.periodTrack) ?? AppConfig.trackAuto;
    _session = _buildSession();
  }

  final PrefsStore prefs;
  final ThemeController theme;
  late final CredentialsStore credentials;
  late HttpSession _session;

  TimetableSnapshot? snapshot;
  int week = 1;
  bool busy = false;
  bool bootstrapped = false;
  String? error;
  String? status;

  int reminderMinutes = 10;
  bool remindersEnabled = false;
  String periodTrack = AppConfig.trackAuto;

  /// 周视图时间列使用的作息：默认按课表主校区自动匹配。
  PeriodTable get periodTable => PeriodTable.of(
        periodTrack,
        dominantCampus: snapshot?.dominantCampus,
      );

  /// 单节课的作息：按该课所在校区精确取，避免跨校区混排时时间错位。
  PeriodTable tableFor(CourseSession session) {
    if (periodTrack == AppConfig.trackMain) return PeriodTable.mainCampus;
    if (periodTrack == AppConfig.trackTianmuhu) return PeriodTable.tianmuhuCampus;
    return PeriodTable.forCampus(session.campus);
  }

  bool get hasData => snapshot != null;

  bool get canAutoLogin => credentials.load() != null;

  int get currentWeek {
    final s = snapshot;
    if (s == null) return 1;
    final w = s.semester.calendar.weekOf(DateTime.now());
    if (w < 1) return 1;
    if (w > s.semester.weekCount) return s.semester.weekCount;
    return w;
  }

  HttpSession _buildSession() {
    final store = credentials.loadCookies();
    return HttpSession(cookieStore: store);
  }

  Future<void> bootstrap() async {
    snapshot = TimetableRepository(prefs: prefs, eams: EamsRepository(_session))
        .loadCache();
    if (snapshot != null) {
      week = currentWeek;
      unawaited(_afterSnapshotUpdated(syncReminders: false));
    }
    bootstrapped = true;
    notifyListeners();
  }

  /// 登录并拉取课表。返回 null 表示成功，否则返回错误文案。
  Future<String?> login(String username, String password) async {
    if (busy) return null;
    busy = true;
    error = null;
    status = '正在登录教务系统';
    notifyListeners();
    try {
      final session = HttpSession();
      await AuthRepository(session).login(username: username, password: password);
      _session = session;
      await credentials.save(
        Credentials(username: username, password: password),
      );
      await credentials.saveCookies(session.cookieStore);
      status = '正在获取课表';
      notifyListeners();
      await _fetchAndStore();
      return null;
    } on AppException catch (e) {
      error = e.message;
      return e.message;
    } catch (e) {
      error = '登录失败：$e';
      return error;
    } finally {
      busy = false;
      status = null;
      notifyListeners();
    }
  }

  /// 刷新课表；会话过期时用已保存凭据自动重登一次。
  Future<String?> refresh({bool silent = false}) async {
    if (busy) return null;
    busy = true;
    error = null;
    status = silent ? null : '更新课表';
    notifyListeners();
    try {
      try {
        await _fetchAndStore();
      } on SessionExpiredException {
        final saved = credentials.load();
        if (saved == null) rethrow;
        final session = HttpSession();
        await AuthRepository(session)
            .login(username: saved.username, password: saved.password);
        _session = session;
        await credentials.saveCookies(session.cookieStore);
        await _fetchAndStore();
      }
      return null;
    } on AppException catch (e) {
      error = e.message;
      return e.message;
    } catch (e) {
      error = '更新失败：$e';
      return error;
    } finally {
      busy = false;
      status = null;
      notifyListeners();
    }
  }

  Future<void> _fetchAndStore() async {
    final repo = TimetableRepository(prefs: prefs, eams: EamsRepository(_session));
    snapshot = await repo.refresh();
    week = currentWeek;
    notifyListeners();
    await _afterSnapshotUpdated(syncReminders: true);
  }

  Future<void> _afterSnapshotUpdated({required bool syncReminders}) async {
    final s = snapshot;
    if (s == null) return;
    await WidgetSyncService.instance.sync(
      snapshot: s,
      tableForCampus: PeriodTable.forCampus,
      accent: theme.seed,
      force: true,
    );
    if (syncReminders && remindersEnabled) {
      await ReminderScheduler.rebuild(
        snapshot: s,
        tableForCampus: PeriodTable.forCampus,
        minutesBefore: reminderMinutes,
        enabled: remindersEnabled,
      );
    }
  }

  void goToWeek(int value) {
    final s = snapshot;
    if (s == null) return;
    final clamped = value.clamp(1, s.semester.weekCount);
    if (clamped == week) return;
    week = clamped;
    notifyListeners();
  }

  /// 由课表页左右滑动驱动的周次同步。
  ///
  /// 只更新字段、**不**通知监听者：翻页手势期间若触发全局重建，
  /// 会让整屏课程块跟着重建，表现为滑动结束瞬间掉帧。
  void syncWeekSilently(int value) {
    final s = snapshot;
    if (s == null) return;
    week = value.clamp(1, s.semester.weekCount);
  }

  /// 主题色/外观变化后刷新小组件（强调色跟随）。
  Future<void> refreshWidgetAppearance() async {
    final s = snapshot;
    if (s == null) return;
    await WidgetSyncService.instance.sync(
      snapshot: s,
      tableForCampus: PeriodTable.forCampus,
      accent: theme.seed,
      force: true,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await theme.setMode(mode);
    final s = snapshot;
    if (s != null) {
      // 小组件强调色跟随主题色，切换后立即重绘。
      await WidgetSyncService.instance.sync(
        snapshot: s,
        tableForCampus: PeriodTable.forCampus,
        accent: theme.seed,
        force: true,
      );
    }
  }

  Future<void> setReminderMinutes(int minutes) async {
    reminderMinutes = minutes;
    await prefs.setInt(PrefsKeys.reminderMinutes, minutes);
    notifyListeners();
    final s = snapshot;
    if (s != null && remindersEnabled) {
      await ReminderScheduler.rebuild(
        snapshot: s,
        tableForCampus: PeriodTable.forCampus,
        minutesBefore: minutes,
        enabled: true,
      );
    }
  }

  Future<bool> setRemindersEnabled(bool enabled) async {
    if (enabled) {
      final s = snapshot;
      if (s == null) return false;
      final granted = await NotificationService.instance.ensurePermission();
      if (!granted) return false;
      await ReminderScheduler.rebuild(
        snapshot: s,
        tableForCampus: PeriodTable.forCampus,
        minutesBefore: reminderMinutes,
        enabled: true,
      );
    } else {
      await NotificationService.instance.cancelAll();
    }
    remindersEnabled = enabled;
    await prefs.setBool(PrefsKeys.remindersEnabled, enabled);
    notifyListeners();
    return true;
  }

  Future<void> setPeriodTrack(String track) async {
    periodTrack = track;
    await prefs.setString(PrefsKeys.periodTrack, track);
    notifyListeners();
    final s = snapshot;
    if (s != null) {
      await WidgetSyncService.instance.sync(
        snapshot: s,
        tableForCampus: PeriodTable.forCampus,
        accent: theme.seed,
        force: true,
      );
    }
  }

  /// 清除凭据与课表缓存。
  Future<void> logout() async {
    await credentials.clearAll();
    await NotificationService.instance.cancelAll();
    await WidgetSyncService.instance.clear();
    _session.close();
    _session = _buildSession();
    snapshot = null;
    week = 1;
    error = null;
    notifyListeners();
  }
}
