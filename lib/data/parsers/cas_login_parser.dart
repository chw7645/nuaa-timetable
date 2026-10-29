import '../../core/network/app_exception.dart';

/// CAS 登录页中提交表单所必需的信息。
class CasLoginPage {
  const CasLoginPage({
    required this.salt,
    required this.execution,
    required this.lt,
    required this.eventId,
    required this.action,
  });

  /// `pwdEncryptSalt`，16 位时为 AES-128 密钥。
  final String salt;
  final String execution;
  final String lt;
  final String eventId;
  final String action;
}

class CasLoginParser {
  CasLoginParser._();

  /// 主正则与降级正则：部分主题把 salt 写成 `id=`，部分是 `name=`。
  static final RegExp _saltById =
      RegExp(r'id="pwdEncryptSalt"\s+value="([^"]*)"');
  static final RegExp _saltByName =
      RegExp(r'name="pwdEncryptSalt"[^>]*value="([^"]*)"');
  static final RegExp _execution =
      RegExp(r'name="execution"\s+value="([^"]*)"');
  static final RegExp _lt = RegExp(r'name="lt"[^>]*value="([^"]*)"');
  static final RegExp _eventId =
      RegExp(r'name="_eventId"[^>]*value="([^"]*)"');
  static final RegExp _action =
      RegExp(r'<form[^>]*id="loginFromId"[^>]*action="([^"]*)"', caseSensitive: false);

  static CasLoginPage parse(String html) {
    final salt = _first(_saltById, html) ?? _first(_saltByName, html);
    if (salt == null || salt.isEmpty) {
      throw const LoginPageFormatException(
        '无法解析登录页参数（pwdEncryptSalt），教务系统可能已改版，请稍后重试',
      );
    }
    return CasLoginPage(
      salt: salt,
      execution: _first(_execution, html) ?? '',
      lt: _first(_lt, html) ?? '',
      eventId: _first(_eventId, html) ?? 'submit',
      action: _first(_action, html) ?? '/authserver/login',
    );
  }

  static String? _first(RegExp pattern, String input) {
    final m = pattern.firstMatch(input);
    if (m == null) return null;
    return m.group(1)?.trim();
  }

  /// 登录失败判定：命中任一特征即视为凭据错误。
  static bool looksLikeCredentialError(String html) {
    const markers = <String>[
      '密码错误',
      '用户名或密码',
      '账号或密码',
      '您提供的用户名或者密码有误',
      '无效的凭证',
    ];
    return markers.any(html.contains);
  }

  /// 命中即视为需要验证码（当前实现不自动绕过，直接提示用户）。
  static bool requiresCaptcha(String html) =>
      html.contains('captchaError') ||
      html.contains('请填写验证码') ||
      html.contains('验证码错误');

  /// 命中原生登录页特征即代表会话失效。
  static bool looksLikeLoginPage(String html) =>
      html.contains('pwdEncryptSalt') || html.contains('id="loginFromId"');
}
