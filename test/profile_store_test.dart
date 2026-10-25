import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/profile_store.dart';

void main() {
  group('UserProfile', () {
    test('序列化往返', () {
      const profile = UserProfile(nickname: '小明', avatar: '🐱');
      final restored = UserProfile.fromJson(profile.toJson());
      expect(restored.nickname, '小明');
      expect(restored.avatar, '🐱');
    });

    test('缺字段时回退默认值', () {
      final restored = UserProfile.fromJson(<String, dynamic>{});
      expect(restored.nickname, '');
      expect(restored.avatar, '🎓');
    });

    test('头像候选非空且包含默认头像', () {
      expect(ProfileStore.avatars, isNotEmpty);
      expect(
        ProfileStore.avatars.contains(UserProfile.fallback.avatar),
        isTrue,
      );
    });
  });
}
