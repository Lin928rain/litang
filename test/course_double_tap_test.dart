import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/models.dart';
import 'package:project_usst/widgets/course_table.dart';

void main() {
  testWidgets('双击课表课程触发定位回调', (tester) async {
    Course? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
          child: CourseWeekTable(
            courses: const <Course>[
              Course(
                name: '高等数学',
                day: 0,
                start: 0,
                span: 2,
                room: '三教106',
                teacher: '王老师',
              ),
            ],
            week: 1,
            onCourseDoubleTap: (course) => tapped = course,
          ),
        ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('王老师'), findsOneWidget);

    await tester.tap(find.text('高等数学'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('高等数学'));
    await tester.pumpAndSettle();

    expect(tapped?.name, '高等数学');
  });
}
