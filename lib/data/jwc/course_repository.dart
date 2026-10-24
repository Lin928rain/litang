import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/cas_client.dart';
import 'course_api.dart';

/// 课表本地缓存：加密存（Android Keystore / iOS Keychain），不用每次联网。
class CourseRepository {
  // v2：旧缓存没有周次字段，会导致课表全量显示，升级 key 让其失效
  static const String _key = 'usst_course_snapshot_v2';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<CourseSnapshot?> loadCache() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      final snapshot =
          CourseSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
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

  static Future<void> save(CourseSnapshot snapshot) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(snapshot.toJson()));
    } catch (_) {
      // 缓存失败不影响展示
    }
  }

  /// 退出登录时清掉缓存的课表，避免换账号后串数据。
  static Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      // ignore
    }
  }

  static Future<CourseSnapshot> refresh(CasClient client) async {
    final snapshot = await CourseApi(client).fetchCurrent();
    if (snapshot.courses.isNotEmpty) {
      await save(snapshot);
    }
    return snapshot;
  }
}
