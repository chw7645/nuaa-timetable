import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nuaa_timetable/data/parsers/cas_login_parser.dart';
import 'package:nuaa_timetable/data/parsers/course_table_entry_parser.dart';

void main() {
  group('CasLoginParser', () {
    test('从真实登录页提取 salt 与表单 token', () {
      final html = File('test/fixtures/cas_login.html').readAsStringSync();
      final page = CasLoginParser.parse(html);
      expect(page.salt.length, 16, reason: '16 字节盐对应 AES-128');
      expect(page.execution, isNotEmpty);
      expect(page.eventId, 'submit');
      expect(page.action, contains('/authserver/login'));
    });

    test('缺少 salt 时给出明确错误文案', () {
      expect(
        () => CasLoginParser.parse('<html><body>unexpected</body></html>'),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('CourseTableEntryParser', () {
    test('解析学期 id、课表 ids 与总周数', () {
      final html = File('test/fixtures/course_table_entry.html').readAsStringSync();
      final entry = CourseTableEntryParser.parse(html);
      expect(entry.semesterId, 402);
      expect(entry.ids, '100000');
      expect(entry.weekCount, 20);
    });
  });
}
