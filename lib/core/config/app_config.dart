/// 教务系统与认证服务的固定契约。
///
/// 这些常量来自对 1.7.0 版本 APK 的 AOT 快照字符串提取，
/// 与学校线上系统实测一致，改动需同步 `docs/REVERSE_ENGINEERING.md`。
class AppConfig {
  AppConfig._();

  static const String authBase = 'https://authserver.nuaa.edu.cn';
  static const String authLoginPath = '/authserver/login';
  static const String casService =
      'http://aao-eas.nuaa.edu.cn/eams/localLogin.action';

  static const String eamsBase = 'http://aao-eas.nuaa.edu.cn/eams/';
  static const String eamsEntryPath = 'courseTableForStd.action';
  static const String eamsTablePath = 'courseTableForStd!courseTable.action';
  static const String eamsDataQueryPath = 'dataQuery.action';

  /// 教务系统只接受带浏览器特征的请求。
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration readTimeout = Duration(seconds: 30);

  /// 教务单日最大节次行数上限（用于防御异常响应）。
  static const int maxGridRows = 20;

  /// 学期最大周数上限（用于防御异常响应）。
  static const int maxWeekCount = 30;

  /// 逐周降级抓取的最大请求数。
  static const int maxWeekFetch = 25;

  /// 作息轨道设置：
  ///  * `auto`     —— 按课表主校区自动选择（默认）
  ///  * `main`     —— 强制将军路 / 明故宫作息
  ///  * `tianmuhu` —— 强制天目湖作息
  static const String trackAuto = 'auto';
  static const String trackMain = 'main';
  static const String trackTianmuhu = 'tianmuhu';
}
