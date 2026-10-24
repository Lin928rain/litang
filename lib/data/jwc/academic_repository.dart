import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/cas_client.dart';
import 'academic_api.dart';

/// 学业情况缓存（加密存储）。
class AcademicRepository {
  static const String _key = 'usst_academic_progress_v2';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<AcademicProgress?> loadCache() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return AcademicProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(AcademicProgress progress) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(progress.toJson()));
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

  static Future<AcademicProgress> refresh(CasClient client) async {
    final progress = await AcademicApi(client).fetch();
    if (progress.required > 0 || progress.categories.isNotEmpty) {
      await save(progress);
    }
    return progress;
  }
}
