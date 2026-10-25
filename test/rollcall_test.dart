import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/lms/rollcall_api.dart';

void main() {
  group('RollcallApi.parseOngoing', () {
    test('解析进行中的签到', () {
      const raw =
          '{"rollcalls": ['
          '{"id": 123, "course_name": "电路原理", "type": "qr_rollcall", '
          '"created_at": "2026-10-23T10:30:00", "course": {"name": "电路原理"}}'
          ']}';
      final list = RollcallApi.parseOngoing(raw);
      expect(list.length, 1);
      final rollcall = list.first;
      expect(rollcall.id, '123');
      expect(rollcall.courseName, '电路原理');
      expect(rollcall.typeLabel, '二维码签到');
      expect(rollcall.timeText, '10:30');
    });

    test('数字口令 / 雷达点名 / 默认类型标签', () {
      final raw =
          '{"rollcalls": ['
          '{"id": 1, "type": "number_rollcall"},'
          '{"id": 2, "type": "radar_rollcall"},'
          '{"id": 3, "type": "manual_rollcall"},'
          '{"id": 4, "type": "unknown"}'
          ']}';
      final list = RollcallApi.parseOngoing(raw);
      expect(list.map((r) => r.typeLabel).toList(), <String>[
        '数字口令',
        '雷达点名',
        '手动点名',
        '签到',
      ]);
    });

    test('类型判断：数字口令 / 二维码 / 雷达', () {
      const number = Rollcall(
        id: '1',
        courseName: '电路',
        type: 'number_rollcall',
        timeText: '',
      );
      expect(number.isNumberRollcall, isTrue);
      expect(number.isQrRollcall, isFalse);

      const qr = Rollcall(
        id: '2',
        courseName: '电路',
        type: 'qr_rollcall',
        timeText: '',
      );
      expect(qr.isQrRollcall, isTrue);
      expect(qr.isNumberRollcall, isFalse);

      const radar = Rollcall(
        id: '3',
        courseName: '电路',
        type: 'radar_rollcall',
        timeText: '',
      );
      expect(radar.isRadarRollcall, isTrue);
      expect(radar.isQrRollcall, isFalse);
    });

    test('二维码内容解析：JSON / URL / 纯口令', () {
      final json = QrPayload.parse(
        '{"code":"A1B2","create_time":"2026-10-23 10:30"}',
      );
      expect(json['code'], 'A1B2');

      final url = QrPayload.parse(
        'https://1906.usst.edu.cn/scan?code=X9&hash=abc',
      );
      expect(url['code'], 'X9');
      expect(url['hash'], 'abc');

      final plain = QrPayload.parse(' 123456 ');
      expect(plain['code'], '123456');
    });

    test('空列表', () {
      expect(RollcallApi.parseOngoing('{"rollcalls":[]}'), isEmpty);
    });

    test('非 JSON 返回空列表', () {
      expect(RollcallApi.parseOngoing('<html></html>'), isEmpty);
      expect(RollcallApi.parseOngoing(''), isEmpty);
    });

    test('缺 id 的项被跳过', () {
      final raw = '{"rollcalls": [{"course_name": "没有 id"}, {"id": 9}]}';
      final list = RollcallApi.parseOngoing(raw);
      expect(list.length, 1);
      expect(list.first.id, '9');
      expect(list.first.courseName, '未知课程');
    });
  });
}
