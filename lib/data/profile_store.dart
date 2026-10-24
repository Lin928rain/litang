import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 论坛/个人页使用的本地资料（昵称、头像），与教务账号无关。
class UserProfile {
  const UserProfile({required this.nickname, required this.avatar});

  final String nickname;

  /// 用 emoji 当头像，省掉图片上传。
  final String avatar;

  static const UserProfile fallback = UserProfile(nickname: '', avatar: '🎓');

  Map<String, String> toJson() => <String, String>{
        'nickname': nickname,
        'avatar': avatar,
      };

  static UserProfile fromJson(Map<String, dynamic> json) => UserProfile(
        nickname: json['nickname'] as String? ?? '',
        avatar: json['avatar'] as String? ?? '🎓',
      );
}

/// 个人资料存储（加密）。
class ProfileStore {
  static const String _key = 'usst_user_profile_v1';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const List<String> avatars = <String>[
    '🎓', '🐱', '🐶', '🦊', '🐼', '🐰', '🍊', '🌙', '⭐', '🍀', '🎧', '🧋',
  ];

  static Future<UserProfile?> load() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(UserProfile profile) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(profile.toJson()));
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
}
