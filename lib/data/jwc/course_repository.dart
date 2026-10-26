import '../auth/cas_client.dart';
import '../cache_store.dart';
import 'course_api.dart';

/// 课表本地缓存：走 [CacheStore] 的加密后端（Android Keystore / iOS Keychain），
/// 不用每次联网。
class CourseRepository {
  // v3：v2 可能已在错误去重时丢失分段周次，不能靠缓存重建，需要重新同步。
  static const String _key = 'usst_course_snapshot_v3';
  static const String _legacyKey = 'usst_course_snapshot_v2';

  /// 课表一天多次刷新没必要；留出 TTL 方便以后做后台刷新。
  static const Duration ttl = Duration(hours: 12);

  static Future<CourseSnapshot?> loadCache() async {
    final entry = await CacheStore.read(_key, secure: true);
    final raw = entry?.data;
    if (raw is! Map) {
      return null;
    }
    try {
      final snapshot = CourseSnapshot.fromJson(raw.cast<String, dynamic>());
      // 数据里一条周次都没有，说明是旧版本缓存，直接丢弃等刷新
      if (snapshot.courses.isNotEmpty &&
          snapshot.courses.every((c) => c.weeksText.isEmpty)) {
        return null;
      }
      return snapshot;
    } catch (_) {
      return null;
    }
  }

  /// 缓存是否还在有效期内（页面可以用它决定要不要后台刷新）。
  static Future<bool> isFresh() async {
    final entry = await CacheStore.read(_key, secure: true);
    return entry != null && entry.isFresh(ttl);
  }

  static Future<void> save(CourseSnapshot snapshot) {
    return CacheStore.write(_key, snapshot.toJson(), secure: true);
  }

  /// 退出登录时清掉缓存的课表，避免换账号后串数据。
  static Future<void> clear() async {
    await CacheStore.remove(_key, secure: true);
    await CacheStore.remove(_legacyKey, secure: true);
  }

  static Future<CourseSnapshot> refresh(CasClient client) async {
    final snapshot = await CourseApi(client).fetchCurrent();
    if (snapshot.courses.isNotEmpty) {
      await save(snapshot);
    }
    return snapshot;
  }
}
