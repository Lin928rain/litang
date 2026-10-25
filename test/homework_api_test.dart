import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/lms/homework_api.dart';

void main() {
  test('解析作业详情', () {
    final detail = HomeworkDetail.fromJson((const {}).cast<String, dynamic>());
    expect(detail, isNull); // 空对象不合法

    final parsed = HomeworkDetail.fromJson(
      Map<String, dynamic>.from({
        'title': '第二章计算作业2',
        'end_time': '2026-10-25T13:59:00Z',
        'user_submit_count': 0,
        'is_closed': false,
        'data': {
          'description': '<p>完成第二章习题</p>',
          'homework_type': 'file_upload',
        },
        'uploads': [
          {'name': '第3次作业.pdf', 'size': 196900},
        ],
      }),
    );
    expect(parsed, isNotNull);
    expect(parsed!.title, '第二章计算作业2');
    expect(parsed.description, '完成第二章习题');
    expect(parsed.typeLabel, '文件作业');
    expect(parsed.submitted, isFalse);
    expect(parsed.attachments.single.name, '第3次作业.pdf');
    expect(parsed.attachments.single.sizeLabel, '192 KB');
  });

  test('已提交状态', () {
    final parsed = HomeworkDetail.fromJson({
      'title': 'x',
      'user_submit_count': 2,
      'data': const <String, dynamic>{},
    });
    expect(parsed!.submitted, isTrue);
  });
}
