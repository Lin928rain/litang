import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:project_usst/data/auth/cas_client.dart';
import 'package:project_usst/data/auth/session_store.dart';

StoredSession _session({String? password}) => StoredSession(
  cookies: <CasCookie>[
    const CasCookie(
      name: 'JSESSIONID',
      value: 'ABC',
      domain: 'jwgl.usst.edu.cn',
      path: '/jwglxt',
    ),
    const CasCookie(
      name: 'CASTGC',
      value: 'TGT-1',
      domain: 'ids6.usst.edu.cn',
      path: '/authserver/',
    ),
  ],
  username: '20250001',
  password: password,
  savedAt: DateTime(2026, 10, 23, 8, 30),
);

StoredSession _roundTrip(StoredSession session) => SessionStore.decode(
  jsonDecode(SessionStore.encode(session)) as Map<String, dynamic>,
);

void main() {
  group('SessionStore 编解码', () {
    test('学号 / 密码 / cookie 往返一致', () {
      final decoded = _roundTrip(_session(password: 'secret'));
      expect(decoded.username, '20250001');
      expect(decoded.password, 'secret');
      expect(decoded.canAutoLogin, isTrue);
      expect(decoded.cookies.length, 2);
      expect(decoded.cookies.first.name, 'JSESSIONID');
      expect(decoded.cookies.first.value, 'ABC');
      expect(decoded.cookies.first.path, '/jwglxt');
      expect(decoded.cookies.last.name, 'CASTGC');
      expect(decoded.savedAt, DateTime(2026, 10, 23, 8, 30));
    });

    test('未记住密码时不会保存密码', () {
      final decoded = _roundTrip(_session(password: null));
      expect(decoded.password, isNull);
      expect(decoded.canAutoLogin, isFalse);
    });

    test('缺字段时容忍（返回空值而不是抛异常）', () {
      final decoded = SessionStore.decode(<String, dynamic>{});
      expect(decoded.cookies, isEmpty);
      expect(decoded.username, '');
      expect(decoded.password, isNull);
      expect(decoded.canAutoLogin, isFalse);
    });

    test('只有用户名没有密码时不能自动登录', () {
      final decoded = _roundTrip(_session(password: ''));
      expect(decoded.canAutoLogin, isFalse);
    });
  });
}
