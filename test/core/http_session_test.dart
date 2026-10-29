import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuaa_timetable/core/network/http_session.dart';

/// 回归测试：CAS 登录依赖"POST → 302 → 跨主机 GET → 302 → 200"这条链路。
///
/// 曾经踩过的坑：
///  1. `HttpClient` 默认自动跟随跳转，但**不跟随 https→http 的降级跳转**，
///     会把 302 当最终响应返回 → 登录被判"未放行"；
///  2. 关闭 `followRedirects` 后 `response.isRedirect` 恒为 false，
///     必须按状态码判断跳转；
///  3. 302 之后必须降级为 GET 并丢弃表单体，否则会把登录密文转发给下游主机。
void main() {
  late HttpServer server;
  late Uri base;

  String? secondMethod;
  String? secondBody;
  String? secondCookie;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
    secondMethod = null;
    secondBody = null;
    secondCookie = null;

    server.listen((request) async {
      final path = request.uri.path;
      if (path == '/login') {
        // 模拟 CAS：校验表单后下发 302 + 会话 Cookie
        final body = await utf8.decoder.bind(request).join();
        expect(body, contains('username='));
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.setCookieHeader, 'CASTGC=TGT-1-abc; Path=/')
          ..headers.set(
              HttpHeaders.locationHeader, '$base/eams/localLogin.action')
          ..headers.contentLength = 0;
        await request.response.close();
        return;
      }
      if (path == '/eams/localLogin.action') {
        secondMethod = request.method;
        secondBody = await utf8.decoder.bind(request).join();
        secondCookie = request.headers.value(HttpHeaders.cookieHeader);
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, '/eams/homeExt.action');
        await request.response.close();
        return;
      }
      request.response
        ..statusCode = HttpStatus.ok
        ..write('HOME');
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('跨跳转请求被完整跟随到最终 200', () async {
    final session = HttpSession();
    final result = await session.postForm(
      base.resolve('/login'),
      <String, String>{'username': '202600000', 'password': 'cipher'},
    );
    expect(result.statusCode, 200);
    expect(result.body, 'HOME');
    expect(result.uri.path, '/eams/homeExt.action');
    session.close();
  });

  test('302 之后改用 GET 且不携带表单体', () async {
    final session = HttpSession();
    await session.postForm(
      base.resolve('/login'),
      <String, String>{'username': '202600000', 'password': 'cipher'},
    );
    expect(secondMethod, 'GET');
    expect(secondBody, isEmpty, reason: '登录表单不应被转发到跳转目标');
    session.close();
  });

  test('跳转过程中收集到的 Cookie 会带入后续请求', () async {
    final session = HttpSession();
    await session.postForm(
      base.resolve('/login'),
      <String, String>{'username': '202600000', 'password': 'cipher'},
    );
    expect(secondCookie, contains('CASTGC=TGT-1-abc'));
    expect(session.cookieStore.value('127.0.0.1', 'CASTGC'), 'TGT-1-abc');
    session.close();
  });

  test('无 Location 的 3xx 不会死循环，直接返回', () async {
    final bare = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    bare.listen((request) async {
      request.response.statusCode = HttpStatus.found;
      await request.response.close();
    });
    final session = HttpSession();
    final result = await session.get(Uri.parse('http://127.0.0.1:${bare.port}/x'));
    expect(result.statusCode, 302);
    session.close();
    await bare.close(force: true);
  });
}
