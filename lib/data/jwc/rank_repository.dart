import '../auth/cas_client.dart';
import '../cache_store.dart';
import 'rank_api.dart';

/// 专业排名缓存（加密存储）。
class RankRepository {
  static const String _key = 'usst_rank_info_v1';

  static Future<RankInfo?> loadCache() async {
    final entry = await CacheStore.read(_key, secure: true);
    final raw = entry?.data;
    if (raw is! Map) {
      return null;
    }
    try {
      return RankInfo.fromJson(raw.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(RankInfo info) {
    return CacheStore.write(_key, info.toJson(), secure: true);
  }

  static Future<void> clear() => CacheStore.remove(_key, secure: true);

  static Future<RankInfo> refresh(CasClient client) async {
    final info = await RankApi(client).fetch();
    await save(info);
    return info;
  }
}
