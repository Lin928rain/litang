import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_theme.dart';
import '../data/auth/cas_client.dart';

/// 带 cookie 注入的通用内嵌网页，可以单独塞进任意页面里用。
class CookieWebView extends StatefulWidget {
  const CookieWebView({
    super.key,
    required this.url,
    this.cookies = const <CasCookie>[],
    this.html,
  });

  final String url;
  final List<CasCookie> cookies;

  /// 已经抓到的 HTML。给了就直接渲染它（baseUrl 用 [url]），
  /// 用来绕开"某些站点在 WebView 里认不出 cookie、跳登录页"的问题。
  final String? html;

  @override
  State<CookieWebView> createState() => CookieWebViewState();
}

class CookieWebViewState extends State<CookieWebView> {
  static final bool _supported =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  void reload() => _controller?.reload();

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
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
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
    if (controller == null) return;
    if (widget.cookies.isNotEmpty) {
      try {
        final manager = WebViewCookieManager();
        final target = Uri.parse(widget.url);
        final host = target.host;
        for (final cookie in widget.cookies) {
          // 每条 cookie 按「它自己适用的 host」注入：
          //   - 带前导点的（.chaoxing.com）→ 当前页面的 host；
          //   - host-only 的（mooc1.chaoxing.com）→ 它自己的域名。
          // 这样万一页面中途跳到别的子域，那边的登录态也在。
          final String targetUrl;
          if (cookie.domain.startsWith('.')) {
            if (host.isEmpty || !cookie.matchesHost(host)) continue;
            targetUrl = 'https://$host/';
          } else {
            if (cookie.domain.isEmpty) continue;
            targetUrl = 'https://${cookie.domain}/';
          }
          // Android 的 setCookie(url, ...) 只能设成 host-only cookie，
          // 所以 URL 必须带上目标 host，不能用裸域名。
          final domain = defaultTargetPlatform == TargetPlatform.android
              ? targetUrl
              : cookie.domain;
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
    final html = widget.html;
    if (html != null && html.isNotEmpty) {
      await controller.loadHtmlString(html, baseUrl: widget.url);
      return;
    }
    await controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '该页面只能在手机 App 内打开',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      );
    }
    return Stack(
      children: <Widget>[
        if (_controller != null) WebViewWidget(controller: _controller!),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.white,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
