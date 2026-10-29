import 'dart:convert';

/// 极简 Cookie 容器：按 host 保存 name=value。
///
/// 教务系统与 CAS 分属不同主机，跨主机跳转时 `HttpClient.cookies`
/// 行为不可控，因此这里完全手工管理。
class CookieStore {
  final Map<String, Map<String, String>> _byHost = <String, Map<String, String>>{};

  void put(String host, String name, String value) {
    _byHost.putIfAbsent(host, () => <String, String>{})[name] = value;
  }

  void remove(String host, String name) {
    _byHost[host]?.remove(name);
  }

  Map<String, String> cookiesFor(String host) =>
      Map<String, String>.from(_byHost[host] ?? const <String, String>{});

  String? value(String host, String name) => _byHost[host]?[name];

  bool get isEmpty => _byHost.values.every((m) => m.isEmpty);

  void clear() => _byHost.clear();

  /// 解析单条 Set-Cookie 头。
  void absorbSetCookie(String host, String raw) {
    final first = raw.split(';').first.trim();
    final eq = first.indexOf('=');
    if (eq <= 0) return;
    final name = first.substring(0, eq).trim();
    final value = first.substring(eq + 1).trim();
    if (name.isEmpty) return;
    if (value.isEmpty || value.toLowerCase() == 'deleted') {
      remove(host, name);
    } else {
      put(host, name, value);
    }
  }

  String toJson() => jsonEncode(_byHost);

  void loadJson(String? source) {
    _byHost.clear();
    if (source == null || source.isEmpty) return;
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          if (value is Map) {
            _byHost['$key'] = value.map((k, v) => MapEntry('$k', '$v'));
          }
        });
      }
    } catch (_) {
      // 缓存损坏时静默降级为未登录状态。
    }
  }
}
