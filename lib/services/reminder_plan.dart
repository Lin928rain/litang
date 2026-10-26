/// 可持久化的待通知记录。iOS 从全部来源中挑选最近的计划，避免系统容量溢出。
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.key,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String key;
  final DateTime fireAt;
  final String title;
  final String body;
  final String payload;

  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'fireAt': fireAt.toUtc().toIso8601String(),
    'title': title,
    'body': body,
    'payload': payload,
  };

  factory PlannedReminder.fromJson(Map<String, dynamic> json) =>
      PlannedReminder(
        id: json['id'] as int,
        key: json['key'] as String,
        fireAt: DateTime.parse(json['fireAt'] as String),
        title: json['title'] as String,
        body: json['body'] as String,
        payload: json['payload'] as String,
      );
}

List<PlannedReminder> nearestReminders(
  Iterable<PlannedReminder> entries, {
  required DateTime now,
  int limit = 60,
}) {
  final future = entries.where((entry) => entry.fireAt.isAfter(now)).toList()
    ..sort((a, b) {
      final time = a.fireAt.compareTo(b.fireAt);
      return time != 0 ? time : a.id.compareTo(b.id);
    });
  return future.take(limit < 0 ? 0 : limit).toList();
}
