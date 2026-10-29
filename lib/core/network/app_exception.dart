/// 统一的业务异常类型：携带可直接展示给用户的中文文案。
sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// 统一身份认证失败（账号密码错误、表单被拒等）。
class AuthException extends AppException {
  const AuthException(super.message);
}

/// 登录页结构变化，缺少必要参数。
class LoginPageFormatException extends AppException {
  const LoginPageFormatException(super.message);
}

/// 会话过期，需要重新登录。
class SessionExpiredException extends AppException {
  const SessionExpiredException([super.message = '登录状态已过期，请重新登录']);
}

/// 网络层异常。
class NetworkException extends AppException {
  const NetworkException(super.message);
}

/// 解析异常（课表结构不符合预期）。
class ParseException extends AppException {
  const ParseException(super.message);
}
