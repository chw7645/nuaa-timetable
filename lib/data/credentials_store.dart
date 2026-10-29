import '../core/network/cookie_store.dart';
import 'local/prefs_store.dart';

class Credentials {
  const Credentials({required this.username, required this.password});

  final String username;
  final String password;

  bool get isEmpty => username.isEmpty || password.isEmpty;
}

class CredentialsStore {
  CredentialsStore(this._prefs);

  final PrefsStore _prefs;

  Credentials? load() {
    final username = _prefs.getString(PrefsKeys.username) ?? '';
    final password = _prefs.getString(PrefsKeys.password) ?? '';
    if (username.isEmpty || password.isEmpty) return null;
    return Credentials(username: username, password: password);
  }

  Future<void> save(Credentials credentials) async {
    await _prefs.setString(PrefsKeys.username, credentials.username);
    await _prefs.setString(PrefsKeys.password, credentials.password);
  }

  Future<void> saveCookies(CookieStore store) async {
    await _prefs.setString(PrefsKeys.cookies, store.toJson());
  }

  CookieStore loadCookies() {
    final store = CookieStore();
    store.loadJson(_prefs.getString(PrefsKeys.cookies));
    return store;
  }

  /// 清除凭据与课表缓存（对应文案"将清除本机保存的凭据与课表缓存"）。
  Future<void> clearAll() async {
    await _prefs.remove(PrefsKeys.username);
    await _prefs.remove(PrefsKeys.password);
    await _prefs.remove(PrefsKeys.cookies);
    await _prefs.remove(PrefsKeys.timetableCache);
  }
}
