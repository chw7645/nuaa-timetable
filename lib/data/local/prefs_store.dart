import 'package:shared_preferences/shared_preferences.dart';

/// 本地持久化键名集中管理，避免散落的字符串常量。
class PrefsKeys {
  PrefsKeys._();

  static const String username = 'creds_username_v1';
  static const String password = 'creds_password_v1';
  static const String cookies = 'auth_cookies_v1';
  static const String timetableCache = 'timetable_cache_v1';
  static const String themeMode = 'theme_mode_v1';
  static const String themeSeed = 'theme_seed_v1';
  static const String reminderMinutes = 'reminder_minutes_v1';
  static const String periodTrack = 'period_track_v1';
  static const String remindersEnabled = 'reminders_enabled_v1';
}

class PrefsStore {
  PrefsStore(this._prefs);

  final SharedPreferences _prefs;

  static Future<PrefsStore> open() async =>
      PrefsStore(await SharedPreferences.getInstance());

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  int? getInt(String key) => _prefs.getInt(key);

  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;

  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  Future<void> remove(String key) => _prefs.remove(key);
}
