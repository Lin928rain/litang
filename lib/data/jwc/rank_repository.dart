import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/cas_client.dart';
import 'rank_api.dart';

/// 专业排名缓存（加密存储）。
class RankRepository {
  static const String _key = 'usst_rank_info_v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<RankInfo?> loadCache() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return RankInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(RankInfo info) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(info.toJson()));
    } catch (_) {
      // ignore
    }
  }

  static Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // ignore
    }
  }

  static Future<RankInfo> refresh(CasClient client) async {
    final info = await RankApi(client).fetch();
    await save(info);
    return info;
  }
}
