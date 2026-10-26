import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../auth/cas_client.dart';

/// 内嵌 WebView 登录后，把 cookie 读回来交给客户端。
///
/// 之所以要原生那一层：`webview_flutter` 4.x 没有读取 cookie 的 API，
/// 而学习通的会话 cookie 是 httpOnly 的，`document.cookie` 也读不到。
/// Android 侧在 `MainActivity` 里用 `CookieManager.getCookie(url)` 实现，
/// iOS 从同一 WKWebsiteDataStore 读取并保留 cookie 的域和路径。
/// 通道名 `litang/web_cookies`；桌面/其它平台没有通道，直接返回空。
class WebCookieBridge {
  WebCookieBridge._();

  static const MethodChannel _channel = MethodChannel('litang/web_cookies');

  /// 学习通的会话 cookie 挂在 `.chaoxing.com` 上，这几个域走一遍基本能全拿到。
  static const List<String> chaoxingUrls = <String>[
    'https://i.chaoxing.com/',
    'https://passport2.chaoxing.com/',
    'https://mooc1.chaoxing.com/',
    'https://mooc2-ans.chaoxing.com/',
  ];

  /// 读 cookie；读不到就是空列表（不抛异常，让调用方自己决定怎么提示）。
  static Future<List<CasCookie>> read({List<String>? urls}) async {
    final targets = urls ?? chaoxingUrls;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final records = await _channel.invokeListMethod<dynamic>(
          'readCookies',
          {'urls': targets},
        );
        final seen = <String>{};
        return <CasCookie>[
          for (final raw in records ?? const <dynamic>[])
            if (raw is Map) CasCookie.fromJson(Map<String, dynamic>.from(raw)),
        ].where((cookie) {
          return cookie.name.isNotEmpty &&
              cookie.domain.isNotEmpty &&
              seen.add('${cookie.name}|${cookie.domain}|${cookie.path}');
        }).toList();
      }
      final map = await _channel.invokeMapMethod<String, String>('read', {
        'urls': targets,
      });
      if (map == null || map.isEmpty) return const <CasCookie>[];
      final out = <CasCookie>[];
      final seen = <String>{};
      for (final entry in map.entries) {
        final domain = cookieDomain(entry.key);
        for (final cookie in parseCookieHeader(entry.value, domain: domain)) {
          // 同名 cookie 只在第一次出现时保留（chaoxing 各子域值通常一致）
          if (seen.add(cookie.name)) out.add(cookie);
        }
      }
      return out;
    } on PlatformException {
      return const <CasCookie>[];
    } on MissingPluginException {
      return const <CasCookie>[];
    }
  }

  /// 退出登录时清一下 WebView 里的 cookie，别留着上一个账号的会话。
  static Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear', {'urls': chaoxingUrls});
    } catch (_) {
      // 没有通道（桌面端）就算了
    }
  }

  /// `Cookie` 头 → cookie 列表，例如 `_uid=123; _d=abc; fid=42`。
  @visibleForTesting
  static List<CasCookie> parseCookieHeader(
    String raw, {
    required String domain,
  }) {
    final out = <CasCookie>[];
    for (final piece in raw.split(';')) {
      final text = piece.trim();
      if (text.isEmpty) continue;
      final eq = text.indexOf('=');
      if (eq <= 0) continue;
      final name = text.substring(0, eq).trim();
      final value = text.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      out.add(CasCookie(name: name, value: value, domain: domain, path: '/'));
    }
    return out;
  }

  /// cookie 的归属域：chaoxing 的子域统一记到 `.chaoxing.com`，
  /// 这样 `i.chaoxing.com` / `mooc1.chaoxing.com` 都能带上；
  /// 其它域名按 host-only 处理（别把 `edu.cn` 当成可共享的域）。
  @visibleForTesting
  static String cookieDomain(String url) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) return '';
    if (host == 'chaoxing.com' || host.endsWith('.chaoxing.com')) {
      return '.chaoxing.com';
    }
    return host;
  }
}
