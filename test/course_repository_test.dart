import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/cache_store.dart';
import 'package:project_usst/data/jwc/course_api.dart';
import 'package:project_usst/data/jwc/course_repository.dart';
import 'package:project_usst/data/models.dart';

CourseSnapshot _snapshot(List<int> weeks) => CourseSnapshot(
  termLabel: '示例学期',
  xnm: '2026',
  xqm: '3',
  collegeName: '示例学院',
  updatedAt: DateTime(2026, 10, 26),
  courses: [
    Course(
      name: '军事理论',
      day: 1,
      start: 7,
      span: 2,
      room: '示例教室201',
      weeks: weeks,
      weeksText: weeks.join(','),
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    CacheStore.clearMemory();
  });
  tearDown(CacheStore.clearMemory);

  test('旧缓存即使未过期且有学院信息，也不能继续显示丢失周次的课表', () async {
    await CacheStore.write(
      'usst_course_snapshot_v2',
      _snapshot([3, 4]).toJson(),
      secure: true,
    );
    CacheStore.clearMemory();
    expect(await CourseRepository.loadCache(), isNull);
    expect(await CourseRepository.isFresh(), isFalse);
    // ProfilePage 在缓存缺失且登录态有效时会重新同步。
  });

  test('新课表可在重启清空内存后恢复完整周次', () async {
    final expected = [3, 4, 5, 6, 7, 8, 10];
    await CourseRepository.save(_snapshot(expected));
    CacheStore.clearMemory();
    final restored = await CourseRepository.loadCache();
    expect(restored!.courses.single.weeks, expected);
    expect(restored.courses.single.activeInWeek(9), isFalse);
    expect(await CourseRepository.isFresh(), isTrue);
  });

  test('退出登录清除新旧两种课表缓存', () async {
    await CacheStore.write(
      'usst_course_snapshot_v2',
      _snapshot([3, 4]).toJson(),
      secure: true,
    );
    await CourseRepository.save(_snapshot([3, 4, 5, 6, 7, 8, 10]));
    await CourseRepository.clear();
    CacheStore.clearMemory();
    expect(await CourseRepository.loadCache(), isNull);
    expect(
      await CacheStore.read('usst_course_snapshot_v2', secure: true),
      isNull,
    );
  });
}
