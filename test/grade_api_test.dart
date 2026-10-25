import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/jwc/grade_api.dart';

const String _page =
    '{'
    '"totalCount": 3,'
    '"items": ['
    '{"kcmc": "高等数学", "kch": "1001", "xf": "4.0", "jd": "3.50", "bfzcj": "88", "cj": "88", '
    '"xnmmc": "2025-2026", "xqmmc": "2", "kcxzmc": "学科基础课程", "jsxm": "张三", "xm": "测试同学", "bj": "测试2501班"},'
    '{"kcmc": "大学物理", "kch": "1002", "xf": "3.0", "jd": "2.50", "bfzcj": "75", "cj": "75", '
    '"xnmmc": "2025-2026", "xqmmc": "2", "kcxzmc": "学科基础课程", "jsxm": "李四", "xm": "测试同学", "bj": "测试2501班"},'
    '{"kcmc": "体育", "kch": "1003", "xf": "1.0", "jd": "4.00", "bfzcj": "92", "cj": "优秀", '
    '"xnmmc": "2025-2026", "xqmmc": "1", "kcxzmc": "通识课程", "jsxm": "王五", "xm": "测试同学", "bj": "测试2501班"}'
    ']'
    '}';

void main() {
  group('GradeApi.parsePage', () {
    test('解析课程、学期与学籍信息', () {
      final parsed = GradeApi.parsePage(_page);
      expect(parsed.grades.length, 3);
      expect(parsed.totalCount, 3);
      expect(parsed.studentName, '测试同学');
      expect(parsed.className, '测试2501班');
      final pe = parsed.grades.firstWhere((g) => g.name == '体育');
      expect(pe.termLabel, '2025-2026 第1学期');
      expect(pe.scoreText, '优秀');
      expect(parsed.grades.first.termLabel, '2025-2026 第2学期');
    });

    test('加权绩点按学分计算', () {
      final parsed = GradeApi.parsePage(_page);
      final snapshot = GradeSnapshot(
        grades: parsed.grades,
        updatedAt: DateTime(2026, 10, 22),
        studentName: parsed.studentName,
        className: parsed.className,
      );
      final s = snapshot.summary;
      // (3.5*4 + 2.5*3 + 4.0*1) / 8 = 3.1875
      expect(s.weightedGpa, closeTo(3.1875, 0.0001));
      // (88*4 + 75*3 + 92*1) / 8 = 83.625
      expect(s.weightedAverage, closeTo(83.625, 0.0001));
      expect(s.totalCredits, closeTo(8.0, 0.0001));
      expect(s.courseCount, 3);
    });

    test('成绩快照可序列化往返', () {
      final parsed = GradeApi.parsePage(_page);
      final snapshot = GradeSnapshot(
        grades: parsed.grades,
        updatedAt: DateTime(2026, 10, 22, 9, 30),
        studentName: '测试同学',
        className: '测试2501班',
      );
      final restored = GradeSnapshot.fromJson(snapshot.toJson());
      expect(restored.grades.length, 3);
      expect(restored.summary.weightedGpa, closeTo(3.1875, 0.0001));
      expect(restored.studentName, '测试同学');
      expect(restored.updatedAt, DateTime(2026, 10, 22, 9, 30));
    });
  });
}
