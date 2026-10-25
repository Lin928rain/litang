import 'package:flutter/foundation.dart';

import 'cache_store.dart';
import 'jwc/course_repository.dart';

/// 首页通知流的本地偏好：本院（用于「本院优先」排序 / 「只看本院」筛选）。
///
/// 两种来源：
///   - 默认从教务的课表缓存里读（`CourseSnapshot.collegeName`，教务首页用户信息里带着），
///     读到就存下来，每次启动读一遍对比，换账号/转专业会自动跟上；
///   - 用户手动选了之后就以用户为准（可以随时再改，也可以「恢复自动识别」）。
///
/// 存到加密存储里，因为它是从教务账号推出来的个人信息。
class NoticePrefs {
  NoticePrefs._();

  static const String _key = 'notice_prefs_v1';

  static _Stored? _memory;

  /// 测试用：widget 测试里没有平台通道，flutter_secure_storage 的 Future
  /// 在 FakeAsync 下永远不会完成（会把 await 卡死），所以测试里跳过真正的存储，
  /// 只走内存。
  @visibleForTesting
  static bool debugSkipStorage = false;

  /// 解析出「本院」。
  ///
  /// [name] 是对齐到 `notices.json` 里 `dept` 的规范名；
  /// [fromJw] 表示这次的值是从教务自动读到的；
  /// [overridden] 表示用户手动指定过（此时永远以用户为准）。
  static Future<({String? name, bool fromJw, bool overridden})> resolve(
    Iterable<String> known,
  ) async {
    final stored = await _read();
    if (stored.userPicked) {
      return (name: stored.college, fromJw: false, overridden: true);
    }

    final jw = await _fromCourseCache();
    if (jw != null) {
      final matched = matchCollege(jw, known);
      if (matched != null) {
        if (matched != stored.college) {
          await _write(_Stored(college: matched, userPicked: false));
        }
        return (name: matched, fromJw: true, overridden: false);
      }
    }
    return (name: stored.college, fromJw: true, overridden: false);
  }

  /// 只要学院名，不看来源。
  static Future<String?> college(Iterable<String> known) async =>
      (await resolve(known)).name;

  /// 用户手动指定（传 null / 空串表示「不设置」，同样算手动，不会被教务覆盖）。
  static Future<void> setCollege(String? college) async {
    await _write(
      _Stored(
        college: (college == null || college.isEmpty) ? null : college,
        userPicked: true,
      ),
    );
  }

  /// 放弃手动指定，下次重新从教务读。
  static Future<void> resetToAuto() async {
    _memory = null;
    await CacheStore.remove(_key, secure: true);
  }

  // ---------------------------------------------------------------- 内部

  static Future<_Stored> _read() async {
    final cached = _memory;
    if (cached != null) return cached;
    if (debugSkipStorage) return const _Stored(college: null, userPicked: false);
    try {
      final entry = await CacheStore.read(_key, secure: true);
      final data = entry?.data;
      if (data is Map) {
        final college = data['college'];
        return _Stored(
          college: (college is String && college.isNotEmpty) ? college : null,
          userPicked: data['userPicked'] == true,
        );
      }
    } catch (_) {
      // 读不出来就当没设置
    }
    return const _Stored(college: null, userPicked: false);
  }

  static Future<void> _write(_Stored value) async {
    _memory = value;
    if (debugSkipStorage) return;
    await CacheStore.write(
      _key,
      <String, dynamic>{
        'college': value.college ?? '',
        'userPicked': value.userPicked,
      },
      secure: true,
    );
  }

  /// 教务课表缓存里的学院名，比如「健康科学与工程学院」。
  static Future<String?> _fromCourseCache() async {
    if (debugSkipStorage) return null;
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
      } else if (text.length >= 2 &&
          k.length >= 2 &&
          text.startsWith(k.substring(0, 2))) {
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

/// 存在本地的那一条记录。
class _Stored {
  const _Stored({required this.college, required this.userPicked});

  final String? college;

  /// true = 用户手动选过，教务的数据不再覆盖它
  final bool userPicked;
}
