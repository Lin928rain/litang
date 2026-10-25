import 'cache_store.dart';

/// 首页通知流的本地偏好：本院（用于"本院优先"排序）。
///
/// 存到加密存储里，因为它是从教务账号推出来的个人信息。
class NoticePrefs {
  NoticePrefs._();

  static const String _key = 'notice_prefs_v1';

  static String? _collegeMemory;

  /// 用户选的学院名（和 notices.json 里的 `dept` 对齐）；没设过返回 null。
  static Future<String?> college() async {
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

  static Future<void> setCollege(String? college) async {
    _collegeMemory = (college == null || college.isEmpty) ? null : college;
    await CacheStore.write(
      _key,
      <String, dynamic>{'college': _collegeMemory ?? ''},
      secure: true,
    );
  }
}
