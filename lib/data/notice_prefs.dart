import 'package:flutter/foundation.dart';

import 'cache_store.dart';
import 'jwc/course_repository.dart';

/// 首页通知流的本地偏好：本院（用于「本院优先」排序）。
///
/// 学院名优先从教务的课表缓存里读（`CourseSnapshot.collegeName`，教务首页用户信息里带着），
/// 读到就存下来；下次启动再读一遍对比，一样就不动 —— 换账号/转专业才会变。
/// 读不到（没登录教务、旧缓存没这个字段）时，才回退到用户手选。
///
/// 存到加密存储里，因为它是从教务账号推出来的个人信息。
class NoticePrefs {
  NoticePrefs._();

  static const String _key = 'notice_prefs_v1';

  static String? _collegeMemory;

  /// 测试用：widget 测试里没有平台通道，flutter_secure_storage 的 Future
  /// 在 FakeAsync 下永远不会完成，所以直接给一个结果绕开存储。
  @visibleForTesting
  static ({String? name, bool fromJw})? debugResolved;

  /// 解析出「本院」：[name] 是对齐到 `notices.json` 里 `dept` 的规范名，
  /// [fromJw] 表示是不是从教务自动读到的（UI 用它决定要不要显示设置入口）。
  static Future<({String? name, bool fromJw})> resolve(
    Iterable<String> known,
  ) async {
    final override = debugResolved;
    if (override != null) return override;

    final saved = await _read();
    final jw = await _fromCourseCache();
    if (jw != null) {
      final matched = matchCollege(jw, known);
      if (matched != null) {
        if (matched != saved) await _write(matched);
        return (name: matched, fromJw: true);
      }
    }
    return (name: saved, fromJw: false);
  }

  /// 只要学院名，不看来源。
  static Future<String?> college(Iterable<String> known) async =>
      (await resolve(known)).name;

  static Future<void> setCollege(String? college) async {
    await _write((college == null || college.isEmpty) ? null : college);
  }

  // ---------------------------------------------------------------- 内部

  static Future<String?> _read() async {
    if (_collegeMemory != null) return _collegeMemory;
    final entry = await CacheStore.read(_key, secure: true);
    final data = entry?.data;
    if (data is Map) {
      final v = data['college'];
      if (v is String && v.isNotEmpty) {
        _collegeMemory = v;
        return v;
      }
    }
    return null;
  }

  static Future<void> _write(String? college) async {
    _collegeMemory = college;
    await CacheStore.write(
      _key,
      <String, dynamic>{'college': college ?? ''},
      secure: true,
    );
  }

  /// 教务课表缓存里的学院名，比如「健康科学与工程学院」。
  static Future<String?> _fromCourseCache() async {
    try {
      final snapshot = await CourseRepository.loadCache();
      final name = snapshot?.collegeName.trim() ?? '';
      return name.isEmpty ? null : name;
    } catch (_) {
      return null;
    }
  }

  /// 把教务给的学院名对上 notices.json 里的部门名。
  ///
  /// 大部分是精确相等；少数对不上（比如教务写「出版印刷与艺术设计学院」，
  /// 站点现在叫「出版学院」），就靠「开头两个字一样」这种弱规则兜一下，
  /// 但并列第一的时候宁可返回 null，也不要乱认。
  static String? matchCollege(String raw, Iterable<String> known) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final scores = <String, int>{};
    for (final k in known) {
      if (k.isEmpty) continue;
      int score = 0;
      if (k == text) {
        score = 100;
      } else if (k.contains(text) || text.contains(k)) {
        score = 50;
      } else if (text.length >= 2 && k.length >= 2 && text.startsWith(k.substring(0, 2))) {
        score = 10;
      }
      if (score > 0) scores[k] = score;
    }
    if (scores.isEmpty) return null;

    final best = scores.values.reduce((a, b) => a > b ? a : b);
    final winners = scores.entries.where((e) => e.value == best).toList();
    if (winners.length != 1) return null;
    return winners.single.key;
  }
}
