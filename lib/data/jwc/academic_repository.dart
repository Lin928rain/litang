import '../auth/cas_client.dart';
import '../cache_store.dart';
import 'academic_api.dart';

/// 学业情况缓存（加密存储）。
class AcademicRepository {
  static const String _key = 'usst_academic_progress_v2';

  static Future<AcademicProgress?> loadCache() async {
    final entry = await CacheStore.read(_key, secure: true);
    final raw = entry?.data;
    if (raw is! Map) {
      return null;
    }
    try {
      return AcademicProgress.fromJson(raw.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(AcademicProgress progress) {
    return CacheStore.write(_key, progress.toJson(), secure: true);
  }

  static Future<void> clear() => CacheStore.remove(_key, secure: true);

  static Future<AcademicProgress> refresh(CasClient client) async {
    final progress = await AcademicApi(client).fetch();
    if (progress.required > 0 || progress.categories.isNotEmpty) {
      await save(progress);
    }
    return progress;
  }
}
