import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/calendar/academic_calendar.dart';

void main() {
  test('解析校历配置', () async {
    final raw = await File('assets/calendar.config').readAsString();
    final calendar = AcademicCalendar.fromYaml(raw);
    expect(calendar, isNotNull);
    expect(calendar!.terms.length, 2);

    final first = calendar.terms.first;
    expect(first.id, '2026-2027-1');
    expect(first.week1Monday, DateTime(2026, 9, 7));
    expect(first.totalWeeks, 24);
    expect(first.weekFor(DateTime(2026, 9, 7)), 1);
    expect(first.weekFor(DateTime(2026, 10, 24)), 7);
    expect(first.typeForWeek(7)?.type, 'teaching');
    expect(first.isVacationDate(DateTime(2026, 10, 24)), isFalse);
    expect(first.isVacationDate(DateTime(2027, 1, 25)), isTrue);
    expect(first.isVacationDate(DateTime(2027, 2, 21)), isTrue);

    final second = calendar.terms[1];
    expect(second.id, '2026-2027-2');
    expect(second.week1Monday, DateTime(2027, 2, 22));
    expect(second.totalWeeks, 27);
    expect(second.typeForWeek(17)?.type, 'exam');
    expect(second.typeForWeek(21)?.type, 'vacation');
  });

  test('无效配置返回 null', () {
    expect(AcademicCalendar.fromYaml(''), isNull);
    expect(AcademicCalendar.fromYaml('terms: []'), isNull);
  });
}
