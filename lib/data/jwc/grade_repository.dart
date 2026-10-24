import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/cas_client.dart';
import 'grade_api.dart';

/// 成绩本地缓存（加密存储），打开成绩页先用缓存再后台更新。
class GradeRepository {
  static const String _key = 'usst_grade_snapshot_v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<GradeSnapshot?> loadCache() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return GradeSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(GradeSnapshot snapshot) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(snapshot.toJson()));
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

  static Future<GradeSnapshot> refresh(CasClient client) async {
    final snapshot = await GradeApi(client).fetchAll();
    if (snapshot.grades.isNotEmpty) {
      await save(snapshot);
    }
    return snapshot;
  }
}
