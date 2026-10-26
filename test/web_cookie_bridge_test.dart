import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project_usst/data/chaoxing/web_cookie_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('iOS 桥接保留同名 cookie 的域和路径，不扩大 host-only 范围', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    const channel = MethodChannel('litang/web_cookies');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(channel, null);
    });
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'readCookies');
      expect(call.arguments['urls'], WebCookieBridge.chaoxingUrls);
      return [
        {
          'name': 'sid',
          'value': 'shared',
          'domain': '.chaoxing.com',
          'path': '/',
        },
        {
          'name': 'sid',
          'value': 'host',
          'domain': 'i.chaoxing.com',
          'path': '/',
        },
        {
          'name': 'sid',
          'value': 'course',
          'domain': 'i.chaoxing.com',
          'path': '/course',
        },
        {
          'name': 'sid',
          'value': 'shared',
          'domain': '.chaoxing.com',
          'path': '/',
        },
      ];
    });
    final cookies = await WebCookieBridge.read();
    expect(cookies, hasLength(3));
    expect(cookies[1].matchesHost('mooc1.chaoxing.com'), isFalse);
    expect(cookies[2].matchesPath('/course/1'), isTrue);
    expect(cookies[2].matchesPath('/courses'), isFalse);
  });

  group('解析 Cookie 头', () {
    test('普通的 name=value 列表', () {
      final cookies = WebCookieBridge.parseCookieHeader(
        '_uid=123456; _d=abcdef; fid=207; uf=abc%2Bdef',
        domain: '.chaoxing.com',
      );
      expect(cookies.length, 4);
      expect(cookies.first.name, '_uid');
      expect(cookies.first.value, '123456');
      expect(cookies.first.domain, '.chaoxing.com');
      expect(cookies.first.path, '/');
      // 值里的 = 和 % 要原样保留
      expect(cookies.last.value, 'abc%2Bdef');
    });

    test('多余空格 / 空段 / 残缺项都跳过', () {
      final cookies = WebCookieBridge.parseCookieHeader(
        '  a=1 ;; b = 2 ; =oops; noequals ',
        domain: 'i.chaoxing.com',
      );
      expect(cookies.map((c) => c.name).toList(), ['a', 'b']);
      expect(cookies.last.value, '2');
    });

    test('空串返回空列表', () {
      expect(
        WebCookieBridge.parseCookieHeader('', domain: '.chaoxing.com'),
        isEmpty,
      );
    });
  });

  group('cookie 归属域', () {
    test('chaoxing 的子域统一记到 .chaoxing.com', () {
      expect(
        WebCookieBridge.cookieDomain('https://i.chaoxing.com/'),
        '.chaoxing.com',
      );
      expect(
        WebCookieBridge.cookieDomain('https://passport2.chaoxing.com/'),
        '.chaoxing.com',
      );
      expect(
        WebCookieBridge.cookieDomain('https://chaoxing.com/'),
        '.chaoxing.com',
      );
    });

    test('别的域名按 host-only，不能把 edu.cn 当成可共享域', () {
      expect(
        WebCookieBridge.cookieDomain('https://www.sbc.usst.edu.cn/'),
        'www.sbc.usst.edu.cn',
      );
      expect(
        WebCookieBridge.cookieDomain('https://jwgl.usst.edu.cn/'),
        'jwgl.usst.edu.cn',
      );
    });

    test('非法 URL 返回空串', () {
      expect(WebCookieBridge.cookieDomain('not a url'), '');
    });
  });

  group('匹配', () {
    test('解析出来的 cookie 能匹配 chaoxing 各子域', () {
      final cookie = WebCookieBridge.parseCookieHeader(
        '_uid=1',
        domain: '.chaoxing.com',
      ).single;
      expect(cookie.matchesHost('i.chaoxing.com'), isTrue);
      expect(cookie.matchesHost('mooc1.chaoxing.com'), isTrue);
      expect(cookie.matchesHost('example.com'), isFalse);
    });
  });
}
