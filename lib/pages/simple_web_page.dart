import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_theme.dart';
import '../data/auth/cas_client.dart';
import '../widgets/cookie_web_view.dart';

/// 通用内嵌网页（如学工一体化、学工系统）。
///
/// 需要登录的页面会跳转学校登录页，用户在页面里登录一次即可（WebView cookie 会保留）。
class SimpleWebPage extends StatefulWidget {
  const SimpleWebPage({
    super.key,
    required this.title,
    required this.url,
    this.cookies = const <CasCookie>[],
  });

  final String title;
  final String url;

  /// 打开前注入的 cookie（如学工登录态）。
  final List<CasCookie> cookies;

  @override
  State<SimpleWebPage> createState() => _SimpleWebPageState();
}

class _SimpleWebPageState extends State<SimpleWebPage> {
  final GlobalKey<CookieWebViewState> _webKey = GlobalKey<CookieWebViewState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => _webKey.currentState?.reload(),
          ),
          IconButton(
            tooltip: '在浏览器打开',
            icon: const Icon(Icons.open_in_new, size: 20),
            onPressed: () async {
              final uri = Uri.tryParse(widget.url);
              if (uri == null) return;
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                // 忽略
              }
            },
          ),
        ],
      ),
      body: CookieWebView(
        key: _webKey,
        url: widget.url,
        cookies: widget.cookies,
      ),
    );
  }
}
