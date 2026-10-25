import '../auth/cas_client.dart';
import '../cache_store.dart';
import 'grade_api.dart';

/// 成绩本地缓存（加密存储），打开成绩页先用缓存再后台更新。
class GradeRepository {
  static const String _key = 'usst_grade_snapshot_v1';

  static Future<GradeSnapshot?> loadCache() async {
    final entry = await CacheStore.read(_key, secure: true);
    final raw = entry?.data;
    if (raw is! Map) {
      return null;
    }
    try {
      return GradeSnapshot.fromJson(raw.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(GradeSnapshot snapshot) {
    return CacheStore.write(_key, snapshot.toJson(), secure: true);
  }

  static Future<void> clear() => CacheStore.remove(_key, secure: true);

  static Future<GradeSnapshot> refresh(CasClient client) async {
    final snapshot = await GradeApi(client).fetchAll();
    if (snapshot.grades.isNotEmpty) {
      await save(snapshot);
    }
    return snapshot;
  }
}
