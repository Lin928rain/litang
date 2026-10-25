import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/jwc/academic_api.dart';
import 'package:project_usst/data/jwc/grade_api.dart';

const String _breakdownRaw =
    '{'
    '"items": ['
    '{"jxb_id": "A", "kcmc": "金工实习B", "bfzcj": "79", "qmcj": "53", "qmxmbl": 30, "xnm": "2026", "xqm": "3"},'
    '{"jxb_id": "B", "kcmc": "形势与政策（Ⅱ）", "bfzcj": "92", "qmcj": "85", "qmxmbl": 50, "xnm": "2025", "xqm": "12"}'
    ']'
    '}';

const String _academicHtml =
    '<p class=\'title1\' id=\'pAAA1\' yxxf=\'50.5\' yqzdxf=\'158\' sftg=\'0\'>" + "2025康复工程&nbsp;"'
    '<p class=\'title1\' id=\'pAAA1\' yxxf=\'50.5\' yqzdxf=\'158\' sftg=\'0\'>" + "2025康复工程&nbsp;"'
    '<p class=\'title1\' id=\'pBBB2\' yxxf=\'8.0\' yqzdxf=\'17\' sftg=\'0\'>" + "通识-思政类01&nbsp;"'
    '<p class=\'title1\' id=\'pCCC3\' yxxf=\'3.0\' yqzdxf=\'3\' sftg=\'1\'>" + "通识-计算机类&nbsp;"';

void _expectDetail(
  List<GradeDetailItem> details,
  String name,
  String score, {
  String? ratio,
}) {
  final item = details.firstWhere((d) => d.name == name);
  expect(item.score, score, reason: '分项 $name 的成绩');
  if (ratio != null) {
    expect(item.ratio, ratio, reason: '分项 $name 的占比');
  }
}

void main() {
  group('GradeApi.parseBreakdowns', () {
    test('解析期末成绩与占比，并推算平时分', () {
      final map = GradeApi.parseBreakdowns(_breakdownRaw);
      expect(map.length, 2);

      final a = map['A']!;
      // 总评 79 = 平时*(0.7) + 期末 53*(0.3) => 平时 = 90.1
      _expectDetail(a, '平时*', '90.1', ratio: '70%');
      _expectDetail(a, '期末', '53', ratio: '30%');
      _expectDetail(a, '总评', '79');

      final b = map['B']!;
      // 总评 92 = 平时*(0.5) + 期末 85*(0.5) => 平时 = 99
      _expectDetail(b, '平时*', '99', ratio: '50%');
      _expectDetail(b, '期末', '85', ratio: '50%');
    });

    test('官方字段优先：平时分直接取 pscj/psbl', () {
      final map = GradeApi.parseBreakdowns(
        '{"items": [{"jxb_id": "D", "pscj": "90", "psbl": "70", '
        '"qmcj": "53", "qmbl": "30", "bfzcj": "79"}]}',
      );
      final details = map['D']!;
      _expectDetail(details, '平时', '90', ratio: '70%');
      _expectDetail(details, '期末', '53', ratio: '30%');
      _expectDetail(details, '总评', '79');
    });

    test('非 JSON 返回空表', () {
      expect(GradeApi.parseBreakdowns('<html></html>'), isEmpty);
    });

    test('缺期末字段时至少保留总评', () {
      final map = GradeApi.parseBreakdowns(
        '{"items": [{"jxb_id": "C", "bfzcj": "88"}]}',
      );
      final details = map['C']!;
      expect(details.length, 1);
      expect(details.first.name, '总评');
      expect(details.first.score, '88');
    });
  });

  group('AcademicApi.parse', () {
    test('解析专业总学分与分类，重复节点去重', () {
      final progress = AcademicApi.parse(_academicHtml);
      expect(progress.majorName, '2025康复工程');
      expect(progress.earned, closeTo(50.5, 0.001));
      expect(progress.required, closeTo(158, 0.001));
      expect(progress.categories.length, 2);
      // 按要求学分倒序
      expect(progress.categories.first.name, '通识-思政类01');
      expect(progress.categories.first.required, closeTo(17, 0.001));
      expect(progress.categories.first.missing, closeTo(9, 0.001));
      expect(progress.categories.last.name, '通识-计算机类');
      expect(progress.categories.last.passed, isTrue);
      expect(progress.categories.last.progress, closeTo(1, 0.001));
    });

    test('空页面返回空数据而不是抛异常', () {
      final progress = AcademicApi.parse('');
      expect(progress.majorName, isEmpty);
      expect(progress.categories, isEmpty);
      expect(progress.required, 0);
    });

    test('快照可序列化往返', () {
      final progress = AcademicApi.parse(_academicHtml);
      final restored = AcademicProgress.fromJson(
        jsonDecode(jsonEncode(progress.toJson())) as Map<String, dynamic>,
      );
      expect(restored.majorName, '2025康复工程');
      expect(restored.categories.length, 2);
      expect(restored.categories.first.name, '通识-思政类01');
      expect(restored.earned, closeTo(50.5, 0.001));
    });
  });
}
