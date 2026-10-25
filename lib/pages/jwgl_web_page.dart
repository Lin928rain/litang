import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_theme.dart';
import '../data/auth/jwgl_auth.dart';

/// 免密进入教务系统网页版：先注入当前会话 cookie，再打开 jwglxt 首页。
class JwglWebPage extends StatefulWidget {
  const JwglWebPage({super.key});

  static const String homeUrl =
      'https://jwgl.usst.edu.cn/jwglxt/xtgl/index_initMenu.html?jsdm=xs';

  @override
  State<JwglWebPage> createState() => _JwglWebPageState();
}

class _JwglWebPageState extends State<JwglWebPage> {
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
        ),
      );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final client = JwglAuth.instance.client;
    if (client == null) {
      setState(() {
        _loading = false;
        _error = '登录状态已失效，请回 App 重新登录';
      });
      return;
    }
    try {
      final manager = WebViewCookieManager();
      for (final cookie in client.jar.cookiesForHost('jwgl.usst.edu.cn')) {
        await manager.setCookie(
          WebViewCookie(
            name: cookie.name,
            value: cookie.value,
            domain: 'jwgl.usst.edu.cn',
            path: cookie.path,
          ),
        );
      }
    } catch (_) {
      // 注入失败也继续尝试，CAS 可能仍能静默跳转
    }
    await controller.loadRequest(Uri.parse(JwglWebPage.homeUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('教务系统'),
        actions: <Widget>[
          if (_controller != null)
            IconButton(
              tooltip: '刷新',
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: () => _controller?.reload(),
            ),
        ],
      ),
      body: !_supported
          ? _message('网页版教务系统只能在手机 App 内打开')
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
