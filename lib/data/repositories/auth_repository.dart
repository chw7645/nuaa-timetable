import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';
import '../../core/crypto/pwd_encryptor.dart';
import '../../core/network/app_exception.dart';
import '../../core/network/http_session.dart';
import '../parsers/cas_login_parser.dart';

/// 统一身份认证（CAS）登录。
class AuthRepository {
  AuthRepository(this.session);

  final HttpSession session;

  Uri get _loginUri => Uri.parse('${AppConfig.authBase}${AppConfig.authLoginPath}')
      .replace(queryParameters: <String, String>{'service': AppConfig.casService});

  /// 成功时返回，失败抛出 [AuthException] / [LoginPageFormatException]。
  Future<void> login({
    required String username,
    required String password,
  }) async {
    final page = await session.get(_loginUri);
    if (page.statusCode >= 400) {
      throw AuthException('无法访问统一身份认证服务（HTTP ${page.statusCode}）');
    }

    final parsed = CasLoginParser.parse(page.body);
    final encrypted = PwdEncryptor.encrypt(password, parsed.salt);

    final action = parsed.action.isEmpty ? '/authserver/login' : parsed.action;
    final submitUri = Uri.parse('${AppConfig.authBase}$action')
        .replace(queryParameters: <String, String>{'service': AppConfig.casService});

    final result = await session.postForm(submitUri, <String, String>{
      'username': username,
      'password': encrypted,
      'lt': parsed.lt,
      'execution': parsed.execution,
      '_eventId': parsed.eventId,
      'dllt': 'generalLogin',
      'cllt': 'userNameLogin',
      'rmShown': '1',
    });

    if (result.uri.host.contains('authserver')) {
      if (CasLoginParser.requiresCaptcha(result.body)) {
        throw const AuthException('登录需要验证码，请先在浏览器完成一次登录后再试');
      }
      if (CasLoginParser.looksLikeCredentialError(result.body)) {
        throw const AuthException('统一身份认证失败：请检查学号与密码');
      }
      if (CasLoginParser.looksLikeLoginPage(result.body)) {
        // 兜底：CAS 已下发 TGT（说明密码正确），但 POST 的 302 链路把会话带回了登录页。
        // 此时直接以当前会话访问 service 目标，CAS 会用 TGT 直接签发 ticket，
        // 无需再次提交口令，可绕过部分网络/代理对跳转链的干扰。
        if (await _redeemViaService()) {
          if (kDebugMode) debugPrint('CAS 兜底换票成功：${AppConfig.casService}');
          return;
        }
        throw AuthException(
          '统一身份认证未接受本次登录（HTTP ${result.statusCode}），'
          '请确认账号状态后重试',
        );
      }
      throw AuthException(
        '统一身份认证返回了意外响应（HTTP ${result.statusCode}），请稍后重试',
      );
    }

    if (kDebugMode) {
      debugPrint('CAS 登录完成，落地页：${result.uri}');
    }
  }

  /// 已持有 TGT 时，直接访问 service 目标换取 ticket 并完成落地。
  Future<bool> _redeemViaService() async {
    try {
      final result = await session.get(Uri.parse(AppConfig.casService));
      if (result.uri.host.contains('authserver')) return false;
      if (CasLoginParser.looksLikeLoginPage(result.body)) return false;
      return result.statusCode < 400;
    } catch (e) {
      if (kDebugMode) debugPrint('兜底换票失败：$e');
      return false;
    }
  }

  /// 判定当前会话是否仍有效。
  Future<bool> probeSession() async {
    try {
      final page = await session.get(
        Uri.parse('${AppConfig.eamsBase}${AppConfig.eamsEntryPath}'),
      );
      if (page.statusCode >= 400) return false;
      return !CasLoginParser.looksLikeLoginPage(page.body);
    } catch (_) {
      return false;
    }
  }
}
