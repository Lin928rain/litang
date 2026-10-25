import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/jwc/academic_api.dart';

void main() {
  group('AcademicCourse', () {
    test('学业状态映射', () {
      expect(AcademicCourse.statusOf('1'), 'inProgress');
      expect(AcademicCourse.statusOf('2'), 'failed');
      expect(AcademicCourse.statusOf('3'), 'notStarted');
      expect(AcademicCourse.statusOf('4'), 'passed');
      expect(AcademicCourse.statusOf('21'), 'passed');
      expect(AcademicCourse.statusOf(''), 'other');
    });

    test('解析课程明细 JSON', () {
      const raw =
          '['
          '{"KCMC":"高等数学(1)","KCH":"MATH1001","XF":"5.0","XDZT":"4",'
          '"CJ":"92","XNMC":"2025-2026","XQMMC":"1"},'
          '{"KCMC":"大学物理","KCH":"PHYS1001","XF":"3","XDZT":"1",'
          '"XNMC":"2026-2027","XQMMC":"1"}'
          ']';
      final list = AcademicApi.parseCourses(raw);
      expect(list.length, 2);
      expect(list[0].name, '高等数学(1)');
      expect(list[0].credits, 5);
      expect(list[0].statusLabel, '已修');
      expect(list[0].score, '92');
      expect(list[1].statusLabel, '在修');
    });

    test('空/异常数据返回空列表', () {
      expect(AcademicApi.parseCourses(''), isEmpty);
      expect(AcademicApi.parseCourses('<html></html>'), isEmpty);
      expect(AcademicApi.parseCourses('[]'), isEmpty);
    });
  });

  group('CreditCategory', () {
    test('id 参与序列化', () {
      const category = CreditCategory(
        id: 'ABC123',
        name: '学科基础课程',
        earned: 27.5,
        required: 60,
        passed: false,
      );
      final restored = CreditCategory.fromJson(category.toJson());
      expect(restored.id, 'ABC123');
      expect(restored.name, '学科基础课程');
      expect(restored.missing, closeTo(32.5, 0.001));
    });
  });
}
