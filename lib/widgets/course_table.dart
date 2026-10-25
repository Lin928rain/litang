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

  static const double rowHeight = 58;
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
    final height = rowHeight * course.span - 4;
    // 一格课只有 50px 高，名字和教师各占两行会挤出去，所以短块少显示一行。
    final compact = course.span <= 1;
    return Positioned(
      left: course.day * dayWidth + 3,
      top: course.start * rowHeight + 2,
      width: dayWidth - 6,
      height: height,
      child: GestureDetector(
        // 单击不再弹详情面板（信息都摆在格子上了），双击仍可在地图上定位教室。
        onDoubleTap: onCourseDoubleTap == null
            ? null
            : () => onCourseDoubleTap!(course),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          decoration: BoxDecoration(
            color: _colorFor(index),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x33A31C1C)),
          ),
          // 不用 FittedBox：以前内容一长整块字都缩成小字，现在保持字号。
          child: ClipRect(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  course.name,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (course.room.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 1),
                  // 教室必须完整显示（「公共实验楼100室」这种会被截断），
                  // 所以允许换行，不再用省略号。
                  Text(
                    course.room,
                    maxLines: compact ? 2 : 3,
                    softWrap: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9,
                      height: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (course.teacher != null &&
                    course.teacher!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 1),
                  Text(
                    course.teacher!,
                    maxLines: compact ? 1 : 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8.5,
                      height: 1.2,
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
