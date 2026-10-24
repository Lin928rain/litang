import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/jwc/jwgl_schedule.dart';
import '../data/models.dart';

/// 周课表：只显示指定教学周要上的课，一门课合成一个块（跨节次连续）。
class CourseWeekTable extends StatelessWidget {
  const CourseWeekTable({
    super.key,
    required this.courses,
    required this.week,
    this.periods = JwglSchedule.periodCount,
    this.onCourseDoubleTap,
  });

  final List<Course> courses;
  final int week;
  final int periods;

  /// 双击课程时的回调（用于跳转地图定位教室楼栋）。
  final ValueChanged<Course>? onCourseDoubleTap;

  static const double rowHeight = 54;
  static const double dayWidth = 66;
  static const double periodWidth = 58;
  static const double headerHeight = 30;

  static const List<String> _days = <String>['一', '二', '三', '四', '五', '六', '日'];

  List<Course> get visibleCourses =>
      courses.where((c) => c.activeInWeek(week)).toList();

  @override
  Widget build(BuildContext context) {
    final shown = visibleCourses;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _periodColumn(),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: dayWidth * 7,
              child: Column(
                children: <Widget>[
                  _header(),
                  SizedBox(
                    height: rowHeight * periods,
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _GridPainter(periods: periods),
                          ),
                        ),
                        for (final course in shown)
                          _courseBlock(context, course, shown.indexOf(course)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: <Widget>[
        for (final day in _days)
          Container(
            width: dayWidth,
            height: headerHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFEDEDED))),
            ),
            child: Text(
              '周$day',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  /// 左栏：每节一行，小字是这节的起止时间。
  Widget _periodColumn() {
    final cells = <Widget>[
      const SizedBox(
        height: headerHeight,
        child: Center(
          child: Text(
            '节次',
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ),
      ),
    ];
    for (var period = 1; period <= periods; period++) {
      cells.add(
        Container(
          width: periodWidth,
          height: rowHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            border: Border(
              top: BorderSide(
                color: const Color(0xFFEDEDED),
                width: period == 1 ? 0.6 : 0.6,
              ),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '第$period节',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  JwglSchedule.timeOfPeriod(period) ?? '',
                  style: const TextStyle(
                    fontSize: 8,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: periodWidth,
      child: Column(children: cells),
    );
  }

  Widget _courseBlock(BuildContext context, Course course, int index) {
    final timeRange = JwglSchedule.rangeOf(course.start, course.span);
    final height = rowHeight * course.span - 4;
    return Positioned(
      left: course.day * dayWidth + 3,
      top: course.start * rowHeight + 2,
      width: dayWidth - 6,
      height: height,
      child: GestureDetector(
        onTap: () => _showDetail(context, course),
        onDoubleTap: onCourseDoubleTap == null
            ? null
            : () => onCourseDoubleTap!(course),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
            color: _colorFor(index),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x33A31C1C)),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  course.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.usstRed,
                  ),
                ),
                if (course.room.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    course.room,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (course.teacher != null &&
                    course.teacher!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    course.teacher!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (timeRange != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    '${course.start + 1}-${course.start + course.span}节 $timeRange',
                    style: const TextStyle(
                      fontSize: 8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _colorFor(int index) {
    const palette = <Color>[
      Color(0x1FA31C1C),
      Color(0x1F2E6FA3),
      Color(0x1F2E8B57),
      Color(0x1F8B5A2E),
      Color(0x1F6A4C93),
    ];
    return palette[index % palette.length];
  }

  void _showDetail(BuildContext context, Course course) {
    final days = <String>['一', '二', '三', '四', '五', '六', '日'];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              course.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              '周${days[course.day]} 第${course.start + 1}-${course.start + course.span}节'
              '${course.room.isEmpty ? '' : ' · ${course.room}'}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (course.teacher != null &&
                course.teacher!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                '教师：${course.teacher}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (course.weeksText.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                '周次：${course.weeksText}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.map_outlined, size: 16, color: AppColors.usstRed),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '双击课表里的课程，可以直接在地图上定位这栋楼',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 网格线：13 行 × 7 天。
class _GridPainter extends CustomPainter {
  _GridPainter({required this.periods});

  final int periods;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xFFEDEDED)
      ..strokeWidth = 0.6;
    for (var i = 0; i <= periods; i++) {
      final y = i * CourseWeekTable.rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    for (var d = 0; d <= 7; d++) {
      final x = d * CourseWeekTable.dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.periods != periods;
}
