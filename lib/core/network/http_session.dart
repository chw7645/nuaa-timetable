import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import 'app_exception.dart';
import 'cookie_store.dart';

class HttpResult {
  const HttpResult({
    required this.statusCode,
    required this.body,
    required this.uri,
  });

  final int statusCode;
  final String body;
  final Uri uri;

  bool get isOk => statusCode >= 200 && statusCode < 400;
}

/// 手工跟随跳转的 HTTP 会话。
///
/// 必须手工处理 3xx：CAS 登录需要收集每一跳的 Set-Cookie（ticket 兑换
/// 依赖 JSESSIONID 与 CASTGC 的先后关系），`HttpClient` 的自动跟随会
/// 丢失中间响应头。
class HttpSession {
  HttpSession({CookieStore? cookieStore, String? userAgent, this.onTrace})
      : cookieStore = cookieStore ?? CookieStore(),
        _userAgent = userAgent ?? AppConfig.userAgent;

  final CookieStore cookieStore;
  final String _userAgent;

  /// 诊断用：非空时逐步回调请求/跳转信息（Release 下为 null，不产生开销）。
  final void Function(String message)? onTrace;
  final HttpClient _client = HttpClient()
    ..connectionTimeout = AppConfig.connectTimeout
    ..idleTimeout = const Duration(seconds: 20)
    ..autoUncompress = true
    ..userAgent = null;

  int get _maxHops => 10;

  Map<String, String> _baseHeaders([Map<String, String>? extra]) {
    final headers = <String, String>{
      'User-Agent': _userAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9',
      'Connection': 'keep-alive',
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  String? _cookieHeader(String host) {
    final cookies = cookieStore.cookiesFor(host);
    if (cookies.isEmpty) return null;
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  Future<HttpResult> get(Uri uri, {Map<String, String>? headers}) =>
      _request('GET', uri, headers: headers);

  Future<HttpResult> postForm(
    Uri uri,
    Map<String, String> form, {
    Map<String, String>? headers,
  }) =>
      _request(
        'POST',
        uri,
        body: form.entries
            .map((e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
            .join('&'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Origin': '${uri.scheme}://${uri.host}',
          ...?headers,
        },
      );

  Future<HttpResult> _request(
    String method,
    Uri uri, {
    String? body,
    Map<String, String>? headers,
  }) async {
    var currentUri = uri;
    var currentMethod = method;
    var currentBody = body;

    for (var hop = 0; hop < _maxHops; hop++) {
      final HttpClientRequest request;
      try {
        request = await _client.openUrl(currentMethod, currentUri);
        // 必须关闭自动跟随：CAS(authserver, https) 会跳转到 EAMS(aao-eas, http)，
        // Dart 的 HttpClient 出于安全策略不跟随 https→http 的降级跳转，
        // 会直接把 302 返回，导致登录被判为"未放行"。
        request.followRedirects = false;
      } on SocketException catch (e) {
        throw NetworkException('无法连接服务器：${e.message}');
      } on TimeoutException {
        throw const NetworkException('网络连接超时，请检查网络后重试');
      }

      _baseHeaders(headers).forEach(request.headers.set);
      final cookies = _cookieHeader(currentUri.host);
      if (cookies != null) request.headers.set(HttpHeaders.cookieHeader, cookies);
      if (currentBody != null) {
        request.headers.contentType =
            ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
        final bytes = utf8.encode(currentBody);
        // 显式指定长度：部分 CAS 前置 WAF 会拒绝 chunked 编码的表单 POST。
        request.contentLength = bytes.length;
        request.add(bytes);
      }

      final HttpClientResponse response;
      try {
        response = await request.close().timeout(AppConfig.readTimeout);
      } on TimeoutException {
        throw const NetworkException('服务器响应超时，请稍后重试');
      } on SocketException catch (e) {
        throw NetworkException('网络异常：${e.message}');
      }

      final setCookies = response.headers[HttpHeaders.setCookieHeader];
      if (setCookies != null) {
        for (final raw in setCookies) {
          cookieStore.absorbSetCookie(currentUri.host, raw);
        }
      }

      // 注意：关闭 followRedirects 后 HttpClientResponse.isRedirect 恒为 false，
      // 因此这里必须按状态码自行判断，否则会把 302 当成最终响应。
      final isRedirect = response.statusCode >= 300 && response.statusCode < 400;
      if (isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        onTrace?.call(
            'HOP $currentMethod ${currentUri.host}${currentUri.path} -> ${response.statusCode} location=${location ?? "(none)"}');
        if (location == null || location.isEmpty) {
          return HttpResult(
              statusCode: response.statusCode, body: '', uri: currentUri);
        }
        currentUri = currentUri.resolve(location);
        // 与浏览器一致：301/302/303 之后一律降级为 GET 并丢弃表单体，
        // 避免把登录表单（含密文口令）转发给后续跳转目标；
        // 仅 307/308 保持原方法与请求体。
        if (response.statusCode != 307 && response.statusCode != 308) {
          currentMethod = 'GET';
          currentBody = null;
        }
        continue;
      }

      onTrace?.call(
          'HOP $currentMethod ${currentUri.host}${currentUri.path} -> ${response.statusCode}');

      final bytes = await response
          .fold<List<int>>(<int>[], (acc, chunk) => acc..addAll(chunk));
      return HttpResult(
        statusCode: response.statusCode,
        body: _decode(bytes, response.headers.contentType?.charset),
        uri: currentUri,
      );
    }
    throw const NetworkException('跳转次数过多，无法完成请求');
  }

  String _decode(List<int> bytes, String? charset) {
    if (charset != null && charset.toLowerCase() != 'utf-8') {
      try {
        return const Utf8Decoder(allowMalformed: true).convert(bytes);
      } catch (_) {
        // 退化为 UTF-8 容错解码。
      }
    }
    return const Utf8Decoder(allowMalformed: true).convert(bytes);
  }

  void close() => _client.close(force: true);
}
