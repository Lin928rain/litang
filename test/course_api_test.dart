import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/jwc/course_api.dart';
import 'package:project_usst/widgets/course_table.dart';

Map<String, String> _militaryRow(String weeks, String teacher) => {
  'kcmc': '军事理论',
  'xqj': '2',
  'jcs': '8-9',
  'cdmc': '示例教室201',
  'xm': teacher,
  'zcd': weeks,
};

CourseSnapshot _militarySnapshot(List<Map<String, String>> rows) =>
    CourseApi.parseKb(jsonEncode({'kbList': rows}));

const String _sample =
    '{'
    '"xsxx": {"XNM": "2026", "XQM": "3", "XNMC": "2026-2027", "XQMMC": "1"},'
    '"kbList": ['
    '{"kcmc": "高等数学", "xqj": "1", "jcs": "1-2", "cdmc": "一教146", "xm": "张三"},'
    '{"kcmc": "大学物理", "xqj": "3", "jcs": "5", "cdmc": "三教101", "xm": "李四"},'
    '{"kcmc": "高等数学", "xqj": "1", "jcs": "1-2", "cdmc": "一教146", "xm": "张三"}'
    ']'
    '}';

void main() {
  group('CourseApi.parseKb', () {
    testWidgets('军事理论分段排课在3至8及10周显示，并展示该周的教师', (tester) async {
      final parsed = _militarySnapshot([
        _militaryRow('3-4周', '教师甲'),
        _militaryRow('5-6周', '教师乙'),
        _militaryRow('7-8周,10周', '教师丙'),
      ]);
      // 同时经过缓存编解码，确认后续启动不会再次丢失周次。
      final cached = CourseSnapshot.fromJson(
        jsonDecode(jsonEncode(parsed.toJson())) as Map<String, dynamic>,
      );
      for (final week in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CourseWeekTable(courses: cached.courses, week: week),
              ),
            ),
          ),
        );
        final expectedTeacher = switch (week) {
          3 || 4 => '教师甲',
          5 || 6 => '教师乙',
          7 || 8 || 10 => '教师丙',
          _ => null,
        };
        expect(
          find.text('军事理论'),
          expectedTeacher == null ? findsNothing : findsOneWidget,
          reason: '第$week周的课程显示不正确',
        );
        for (final teacher in ['教师甲', '教师乙', '教师丙']) {
          expect(
            find.text(teacher),
            teacher == expectedTeacher ? findsOneWidget : findsNothing,
            reason: '第$week周应显示对应排课的教师',
          );
        }
      }
    });

    test('相同教师的同时间地点排课也必须保留不同周次', () {
      final snapshot = _militarySnapshot([
        _militaryRow('3-4周', '教师甲'),
        _militaryRow('5-6周', '教师甲'),
        _militaryRow('7-8周,10周', '教师甲'),
      ]);
      expect(snapshot.courses, hasLength(3));
      expect(
        [
          for (var week = 1; week <= 12; week++)
            if (snapshot.courses.any((course) => course.activeInWeek(week)))
              week,
        ],
        [3, 4, 5, 6, 7, 8, 10],
      );
    });

    test('周次相同但教师不同不能去重，教师周次均相同才去重', () {
      final snapshot = _militarySnapshot([
        _militaryRow('3-4周', '教师甲'),
        _militaryRow('3-4周', '教师乙'),
        _militaryRow('3-4周', '教师甲'),
      ]);
      expect(
        snapshot.courses.map((course) => course.teacher),
        unorderedEquals(['教师甲', '教师乙']),
      );
    });

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

    test('「学部 / 教学部」这种不带「学院」的也要认', () {
      final jcxb = CourseApi.parseUserInfo('<p>基础学部 工科试验26200001班</p>');
      expect(jcxb?.college, '基础学部');
      expect(jcxb?.className, '工科试验26200001班');

      final tyb = CourseApi.parseUserInfo('<p>体育教学部 社体25291001班</p>');
      expect(tyb?.college, '体育教学部');
    });

    test('没有学院信息时返回 null', () {
      expect(CourseApi.parseUserInfo('<p>你好</p>'), isNull);
      expect(CourseApi.parseUserInfo(''), isNull);
    });

    test('同一天同一段的重复课去重', () {
      final snapshot = CourseApi.parseKb(_sample);
      expect(snapshot.courses.where((c) => c.name == '高等数学').length, 1);
    });
  });
}
