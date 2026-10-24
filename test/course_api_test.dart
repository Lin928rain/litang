import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/jwc/course_api.dart';

const String _sample = '{'
    '"xsxx": {"XNM": "2026", "XQM": "3", "XNMC": "2026-2027", "XQMMC": "1"},'
    '"kbList": ['
    '{"kcmc": "高等数学", "xqj": "1", "jcs": "1-2", "cdmc": "一教146", "xm": "张三"},'
    '{"kcmc": "大学物理", "xqj": "3", "jcs": "5", "cdmc": "三教101", "xm": "李四"},'
    '{"kcmc": "高等数学", "xqj": "1", "jcs": "1-2", "cdmc": "一教146", "xm": "张三"}'
    ']'
    '}';

void main() {
  group('CourseApi.parseKb', () {
    test('解析学期与课程', () {
      final snapshot = CourseApi.parseKb(_sample);
      expect(snapshot.termLabel, '2026-2027 第1学期');
      expect(snapshot.xnm, '2026');
      expect(snapshot.xqm, '3');
      expect(snapshot.courses.length, 2);
    });

    test('课程字段与节次换算正确', () {
      final snapshot = CourseApi.parseKb(_sample);
      final math = snapshot.courses.first;
      expect(math.name, '高等数学');
      expect(math.day, 0);
      expect(math.start, 0);
      expect(math.span, 2);
      expect(math.room, '一教146');
      expect(math.teacher, '张三');
    });

    test('解析学院与班级', () {
      final info = CourseApi.parseUserInfo('<p>健康科学与工程学院 康复25291002班</p>');
      expect(info, isNotNull);
      expect(info!.college, '健康科学与工程学院');
      expect(info.className, '康复25291002班');
    });

    test('没有学院信息时返回 null', () {
      expect(CourseApi.parseUserInfo('<p>你好</p>'), isNull);
      expect(CourseApi.parseUserInfo(''), isNull);
    });

    test('同一天同一段的重复课去重', () {
      final snapshot = CourseApi.parseKb(_sample);
      expect(
        snapshot.courses.where((c) => c.name == '高等数学').length,
        1,
      );
    });
  });
}
