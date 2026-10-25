import '../cache_store.dart';
import 'todo_api.dart';

/// 一网畅学 / 学习通课程列表缓存（统一走 [CacheStore]）。
///
/// 学期内课程基本不变，所以缓存优先：有缓存先渲染，超过 [ttl] 再后台静默刷新。
class CourseInfoCache {
  CourseInfoCache._();

  static const Duration ttl = Duration(hours: 24);

  static String _key(String term, String source) =>
      'course_info_${source}_${term.replaceAll(RegExp(r'[^0-9A-Za-z_-]'), '_')}';

  static Future<List<LmsCourseInfo>?> load(String term, String source) async {
    final entry = await CacheStore.read(_key(term, source));
    final raw = entry?.data;
    if (raw is! List) return null;
    final out = <LmsCourseInfo>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      final id = (map['id'] ?? '').toString();
      final name = (map['name'] ?? '').toString();
      if (id.isEmpty || name.isEmpty) continue;
      out.add(
        LmsCourseInfo(
          id: id,
          name: name,
          teacher: (map['teacher'] ?? '').toString(),
          termCode: (map['termCode'] ?? '').toString(),
        ),
      );
    }
    return out;
  }

  /// 缓存是否还在有效期内。
  static Future<bool> isFresh(String term, String source) async {
    final entry = await CacheStore.read(_key(term, source));
    return entry != null && entry.isFresh(ttl);
  }

  static Future<void> save(
    String term,
    String source,
    List<LmsCourseInfo> courses,
  ) {
    return CacheStore.write(
      _key(term, source),
      courses
          .map(
            (e) => <String, String>{
              'id': e.id,
              'name': e.name,
              'teacher': e.teacher,
              'termCode': e.termCode,
            },
          )
          .toList(),
    );
  }
}
