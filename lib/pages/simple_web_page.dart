import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_theme.dart';
import '../data/auth/cas_client.dart';

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
  static final bool _supported =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!_supported) {
      _loading = false;
      return;
    }
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => _loading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => _loading = false);
            }
          },
          onWebResourceError: (error) {
            if (mounted && (error.isForMainFrame ?? false)) {
              setState(() {
                _loading = false;
                _error = '页面加载失败：${error.description}';
              });
            }
          },
        ),
      );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (widget.cookies.isNotEmpty) {
      try {
        final manager = WebViewCookieManager();
        for (final cookie in widget.cookies) {
          // Android 的实现把 domain 当成 URL 传给 CookieManager，
          // 直接传 .usst.edu.cn / chaoxing.com 会被当成非法 URL 而静默失败。
          final rawDomain = cookie.domain;
          final bareDomain = rawDomain.startsWith('.')
              ? rawDomain.substring(1)
              : rawDomain;
          final domain = defaultTargetPlatform == TargetPlatform.android
              ? 'https://$bareDomain/'
              : bareDomain;
          await manager.setCookie(
            WebViewCookie(
              name: cookie.name,
              value: cookie.value,
              domain: domain,
              path: cookie.path,
            ),
          );
        }
      } catch (_) {
        // 注入失败也继续打开
      }
    }
    await controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          if (_controller != null)
            IconButton(
              tooltip: '刷新',
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => _controller?.reload(),
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
      body: !_supported
          ? _message('该页面只能在手机 App 内打开')
          : Stack(
              children: <Widget>[
                if (_controller != null)
                  WebViewWidget(controller: _controller!),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_error != null)
                  Positioned.fill(
                    child: ColoredBox(
                      color: Colors.white,
                      child: _message(_error!),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _message(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
    ),
  );
}
