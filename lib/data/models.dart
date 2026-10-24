// 统一数据模型。UI 只依赖这些模型，不关心数据来自官网抓取、教务接口还是演示数据。

/// 通知 / 公告
class Notice {
  final String dept; // 来源（学院 / 部门）
  final String title;
  final String time;
  final String? url;

  const Notice({
    required this.dept,
    required this.title,
    required this.time,
    this.url,
  });
}

/// 课程（用于课表网格）
class Course {
  final String name;
  final int day; // 0 = 周一 ... 6 = 周日
  final int start; // 起始节次（0-based）
  final int span; // 占用节数
  final String room;
  final String? teacher;

  /// 上课周次（1 起）。解析失败为 null，表示每周都上。
  final List<int>? weeks;

  /// 原始周次文本，如 "3-18周"、"1-16周(单)"。
  final String weeksText;

  const Course({
    required this.name,
    required this.day,
    required this.start,
    required this.span,
    required this.room,
    this.teacher,
    this.weeks,
    this.weeksText = '',
  });

  bool activeInWeek(int week) => weeks == null || weeks!.contains(week);
}