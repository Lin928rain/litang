import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:project_usst/services/reminder_plan.dart';

void main() {
  final now = DateTime.utc(2026, 10, 26);
  PlannedReminder entry(int id, int minutes, {String source = 'tron'}) =>
      PlannedReminder(
        id: id,
        key: '$source:$id',
        fireAt: now.add(Duration(minutes: minutes)),
        title: '作业提醒',
        body: '课程 $id',
        payload: jsonEncode({'key': '$source:$id', 'id': id}),
      );

  test('超过系统容量时按跨来源时间排序，不按同步先后挤掉近期提醒', () {
    final chosen = nearestReminders([
      for (var i = 0; i < 70; i++) entry(i, 100 + i),
      for (var i = 0; i < 10; i++) entry(100 + i, i + 1, source: 'cx'),
      entry(999, -1),
      entry(1000, 0),
    ], now: now);
    expect(chosen, hasLength(60));
    expect(chosen.take(10).every((e) => e.key.startsWith('cx:')), isTrue);
    expect(chosen.last.id, 49);
    expect(chosen.any((e) => e.id == 999 || e.id == 1000), isFalse);
  });

  test('取消近期任务后，从持久化的后续任务补位', () {
    final all = [for (var i = 1; i <= 70; i++) entry(i, i)];
    final encoded = jsonEncode(all.map((e) => e.toJson()).toList());
    final restored = (jsonDecode(encoded) as List)
        .map(
          (raw) =>
              PlannedReminder.fromJson(Map<String, dynamic>.from(raw as Map)),
        )
        .where((e) => e.key != 'tron:1');
    final chosen = nearestReminders(restored, now: now);
    expect(chosen.first.id, 2);
    expect(chosen.last.id, 61);
    expect(chosen.first.payload, all[1].payload);
    expect(chosen.first.fireAt, all[1].fireAt);
  });

  test('给其它通知预留容量，容量耗尽时返回空计划', () {
    expect(
      nearestReminders(
        [entry(1, 1), entry(2, 2)],
        now: now,
        limit: 1,
      ).single.id,
      1,
    );
    expect(nearestReminders([entry(1, 1)], now: now, limit: -2), isEmpty);
  });
}
