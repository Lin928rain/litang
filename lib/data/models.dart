// 统一数据模型。UI 只依赖这些模型，不关心数据来自官网抓取、教务接口还是演示数据。

/// 通知 / 公告
class Notice {
  /// 来源（学院 / 部门）
  final String dept;

  /// 分类：竞赛 / 教学 / 通知 / 讲座 / 学工 / 就业 / 科研 / 招生 / 新闻 / 党群
  final String kind;

  /// `school` 全校级 / `college` 学院级
  final String scope;

  final String title;
  final String? url;

  /// 发布日期。抓不到时为 null（这类排在最后）。
  final DateTime? publishedAt;

  const Notice({
    required this.dept,
    required this.title,
    this.kind = '通知',
    this.scope = 'school',
    this.publishedAt,
    this.url,
  });

  /// 2026-09-14
  String get dateText => publishedAt == null
      ? ''
      : '${publishedAt!.year}-${_two(publishedAt!.month)}-${_two(publishedAt!.day)}';

  /// 今天 / 昨天 / 3 天前 / 09-14
  String get timeLabel {
    final at = publishedAt;
    if (at == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(at.year, at.month, at.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return '今天';
    if (diff == 1) return '昨天';
    if (diff < 7) return '$diff 天前';
    if (day.year == today.year) return '${_two(day.month)}-${_two(day.day)}';
    return '${day.year}-${_two(day.month)}-${_two(day.day)}';
  }

  static String _two(int n) => n < 10 ? '0$n' : '$n';

  static DateTime? parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
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
