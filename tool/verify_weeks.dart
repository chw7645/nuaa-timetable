import 'dart:io';
import 'package:nuaa_timetable/data/parsers/course_table_parser.dart';

void main() {
  final html = File('test/fixtures/course_table_all.html').readAsStringSync();
  final r = CourseTableParser.parse(html, weekCount: 20);
  // 教务「我的课表」页面显示值（截图 ground truth）
  const expected = <String, String>{
    '线性代数|2|2': '7-16',
    '线性代数|3|0': '7-16',
    '应用统计学|1|0': '1-10',
    '应用统计学|1|2': '11-19',
    '宏观经济学Ⅱ|1|2': '1-10',
    '宏观经济学Ⅱ|5|0': '1-9,11', // 拆成 11 与 1-9 两条
    '中国近现代史纲要|2|0': '1-10',
    '中国近现代史纲要|1|8': '1-11',
    '货币金融学|3|2': '1-12',
    '货币金融学|2|6': '1-12',
    '科技英语翻译|3|8': '1-16',
    '基础会计学Ⅰ|1|6': '3-15',
    '基础会计学Ⅰ|4|8': '3-6,8-17',
    '社会研究方法|3|6': '1-2,4-14',
    '社会研究方法|4|6': '1-2,4-14',
    '形势与政策（2）|3|10': '10-11',
    '与设计大师对话：从传奇人生到经典杰作|2|10': '4-11',
    '改革开放史|1|10': '7-12',
    '企业经理讲座与实训|2|8': '1-5,7-8',
  };
  var ok = 0, bad = 0;
  for (final s in r.sessions) {
    final key = '${s.name}|${s.dayOfWeek}|${s.startRow}';
    final exp = expected[key];
    if (exp == null) continue;
    final got = s.weekText.replaceAll('周', '');
    final pass = got == exp;
    if (pass) {
      ok++;
    } else {
      bad++;
      stdout.writeln('MISMATCH $key  期望=$exp  实际=$got');
    }
  }
  stdout.writeln('匹配 $ok 条，不符 $bad 条');
}
