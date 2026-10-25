import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/lms/todo_api.dart';

void main() {
  group('LmsApi.parseTodos', () {
    test('解析作业待办', () {
      const raw =
          '{"todo_list":[{'
          '"id": 2046131, "course_id": 151598, "title": "第二章计算作业2", "type": "homework",'
          '"course_name": "工程力学C", "end_time": "2026-10-25T13:59:00Z"}]}';
      final list = LmsApi.parseTodos(raw);
      expect(list.length, 1);
      expect(list.first.title, '第二章计算作业2');
      expect(list.first.courseName, '工程力学C');
      expect(list.first.isHomework, isTrue);
      expect(list.first.typeLabel, '作业');
      expect(list.first.deadline, isNotNull);
    });

    test('空/异常数据返回空列表', () {
      expect(LmsApi.parseTodos(''), isEmpty);
      expect(LmsApi.parseTodos('<html>'), isEmpty);
      expect(LmsApi.parseTodos('{"todo_list":[]}'), isEmpty);
    });
  });

  group('LmsApi.parseExams', () {
    test('解析考试安排', () {
      const raw =
          '{"items":[{'
          '"kcmc":"思想道德与法治","ksmc":"2025-2026-2学期期末考试",'
          '"xnmc":"2025-2026","xqmmc":"2","kssj":"未放开不可查",'
          '"jxdd":"申图205;申图205","jsxx":"09053/王素雷"}]}';
      final list = LmsApi.parseExams(raw);
      expect(list.length, 1);
      expect(list.first.courseName, '思想道德与法治');
      expect(list.first.termLabel, '2025-2026 第2学期');
      expect(list.first.location, '申图205');
      expect(list.first.timePending, isTrue);
    });

    test('时间已公布时 timePending 为 false', () {
      const raw = '{"items":[{"kcmc":"高数","kssj":"2026-01-10 09:00~11:00"}]}';
      final list = LmsApi.parseExams(raw);
      expect(list.first.timePending, isFalse);
    });

    test('空/异常数据返回空列表', () {
      expect(LmsApi.parseExams(''), isEmpty);
      expect(LmsApi.parseExams('{"items":[]}'), isEmpty);
    });
  });
}
