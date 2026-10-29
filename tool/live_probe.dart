// 临时联调脚本：用 App 内完全相同的 HttpSession / PwdEncryptor 走一遍真实登录，
// 打印每一步的状态码、落地 URL、Cookie 与正文特征，用于定位"认证服务未放行"。
// 运行：NUAA_USER=xxx NUAA_PW=xxx dart run tool/live_probe.dart
import 'dart:io';

import 'package:nuaa_timetable/core/config/app_config.dart';
import 'package:nuaa_timetable/core/crypto/pwd_encryptor.dart';
import 'package:nuaa_timetable/core/network/http_session.dart';
import 'package:nuaa_timetable/data/parsers/cas_login_parser.dart';
import 'package:nuaa_timetable/data/parsers/course_table_entry_parser.dart';
import 'package:nuaa_timetable/data/parsers/course_table_parser.dart';
import 'package:nuaa_timetable/data/semester_calendar.dart';

Future<void> main() async {
  final user = Platform.environment['NUAA_USER'] ?? '';
  final pw = Platform.environment['NUAA_PW'] ?? '';
  if (user.isEmpty || pw.isEmpty) {
    stdout.writeln('缺少 NUAA_USER / NUAA_PW');
    exit(1);
  }

  final session = HttpSession(onTrace: (m) => stdout.writeln('[TRACE] $m'));
  final loginUri = Uri.parse('${AppConfig.authBase}${AppConfig.authLoginPath}')
      .replace(queryParameters: <String, String>{'service': AppConfig.casService});

  final page = await session.get(loginUri);
  stdout.writeln('[GET ] status=${page.statusCode} uri=${page.uri} len=${page.body.length}');
  final parsed = CasLoginParser.parse(page.body);
  stdout.writeln('[GET ] salt=${parsed.salt.length}B execution=${parsed.execution} '
      'lt=${parsed.lt.isEmpty ? "(空)" : parsed.lt} eventId=${parsed.eventId} action=${parsed.action}');
  stdout.writeln('[COOKIE] authserver -> ${session.cookieStore.cookiesFor("authserver.nuaa.edu.cn")}');

  final encrypted = PwdEncryptor.encrypt(pw, parsed.salt);
  stdout.writeln('[ENC ] 密文长度=${encrypted.length} 前缀=${encrypted.substring(0, 12)}…');

  final submitUri = Uri.parse('${AppConfig.authBase}${parsed.action}')
      .replace(queryParameters: <String, String>{'service': AppConfig.casService});
  stdout.writeln('[POST] $submitUri');

  final result = await session.postForm(submitUri, <String, String>{
    'username': user,
    'password': encrypted,
    'lt': parsed.lt,
    'execution': parsed.execution,
    '_eventId': parsed.eventId,
    'dllt': 'generalLogin',
    'cllt': 'userNameLogin',
    'rmShown': '1',
  });

  stdout.writeln('[POST] status=${result.statusCode} uri=${result.uri} len=${result.body.length}');
  stdout.writeln('[COOKIE] after -> ${session.cookieStore.cookiesFor(result.uri.host)}');

  final body = result.body;
  for (final marker in <String>[
    '密码错误',
    '用户名或密码',
    'captchaError',
    '验证码',
    'pwdEncryptSalt',
    'id="loginFromId"',
    'authn_risk',
    'errorMessage',
    'id="msg"',
  ]) {
    if (body.contains(marker)) stdout.writeln('[MARK] 命中 "$marker"');
  }

  // 打印页面中的可见提示文本，帮助定位服务端拒绝原因
  final text = body
      .replaceAll(RegExp(r'<script[\s\S]*?</script>'), ' ')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>'), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  stdout.writeln('[TEXT] ${text.length > 700 ? text.substring(0, 700) : text}');

  // 继续验证课表抓取（与 App 内 EamsRepository 相同的两步请求）
  if (result.uri.host.contains('aao-eas')) {
    final entry = await session.get(
      Uri.parse('${AppConfig.eamsBase}${AppConfig.eamsEntryPath}'),
    );
    stdout.writeln('[ENTRY] ${entry.statusCode} len=${entry.body.length}');
    final info = CourseTableEntryParser.parse(entry.body);
    stdout.writeln('[ENTRY] semester=${info.semesterId} ids=${info.ids} weeks=${info.weekCount}');

    final table = await session.get(
      Uri.parse('${AppConfig.eamsBase}${AppConfig.eamsTablePath}')
          .replace(queryParameters: <String, String>{
        'ignoreHead': '1',
        'setting.kind': 'std',
        'startWeek': '',
        'semester.id': '${info.semesterId}',
        'ids': info.ids,
      }),
    );
    stdout.writeln('[TABLE] ${table.statusCode} len=${table.body.length}');
    final parsedTable = CourseTableParser.parse(table.body);
    stdout.writeln('[TABLE] unitCount=${parsedTable.unitCount} '
        'sessions=${parsedTable.sessions.length}');
    final monday = SemesterCalendar.week1MondayFor(info.semesterId);
    stdout.writeln('[CAL ] 第1周周一=$monday');
    for (final s in parsedTable.sessions.where((e) => e.name.contains('应用统计') || e.dayOfWeek == 4)) {
      stdout.writeln('   ${s.name} 周${s.dayOfWeek} 行${s.startRow}-${s.endRow} '
          '${s.place} ${s.weekText} 含9周=${s.hasWeek(9)}');
    }
  }

  session.close();
}
