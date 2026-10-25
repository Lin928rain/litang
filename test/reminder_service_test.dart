import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/services/reminder_service.dart';

void main() {
  group('学习通剩余时间解析', () {
    test('小时 + 分钟', () {
      expect(
        ReminderService.parseRemaining('剩余91小时40分钟'),
        const Duration(hours: 91, minutes: 40),
      );
      expect(
        ReminderService.parseRemaining('剩余7小时53分钟'),
        const Duration(hours: 7, minutes: 53),
      );
    });

    test('只有分钟', () {
      expect(
        ReminderService.parseRemaining('剩余50分钟'),
        const Duration(minutes: 50),
      );
    });

    test('带天数', () {
      expect(
        ReminderService.parseRemaining('剩余2天3小时10分钟'),
        const Duration(days: 2, hours: 3, minutes: 10),
      );
    });

    test('认不出来返回 null', () {
      expect(ReminderService.parseRemaining(''), isNull);
      expect(ReminderService.parseRemaining('已截止'), isNull);
      expect(ReminderService.parseRemaining('未开放'), isNull);
    });

    test('带空格的写法也能认', () {
      expect(
        ReminderService.parseRemaining('剩余 3 天 2 小时'),
        const Duration(days: 3, hours: 2),
      );
    });
  });
}
