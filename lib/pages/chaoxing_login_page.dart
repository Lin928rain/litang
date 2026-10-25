import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../app_theme.dart';
import '../data/chaoxing/chaoxing_auth.dart';
import '../data/chaoxing/web_cookie_bridge.dart';

/// 学习通登录：直接开内嵌网页，登完把 cookie 读回来。
///
/// 为什么不用「手机号 + 密码」的自建表单：超星的登录接口要求用一段写死在前端
/// JavaScript 里的 AES 密钥加密密码，复现它属于分析对方前端，既脆弱也不体面。
/// 走网页登录则完全绕开这层 —— 密码只在对方页面上输入，我们只拿会话 cookie。
class ChaoxingLoginPage extends StatefulWidget {
  const ChaoxingLoginPage({super.key});

  /// 学校专属的登录页：`fid=207` 是上海理工在超星那边的机构号，
  /// 带上它进去就是「机构账号登录 · 上海理工大学」，用户直接输学号 + 超星密码。
  ///
  /// 207 不是猜的：`usst.fanya.chaoxing.com` 页面里的 `p_wfwfid = 207`，
  /// 而且这个 fid 会原样回显在登录页的隐藏域里（瞎填的 fid 会被服务端归一成 -1）。
  static const String loginUrl =
      'https://passport2.chaoxing.com/login?fid=207&newversion=true'
      '&refer=https%3A%2F%2Fi.chaoxing.com';

  @override
  State<ChaoxingLoginPage> createState() => _ChaoxingLoginPageState();
}

class _ChaoxingLoginPageState extends State<ChaoxingLoginPage> {
  static final bool _supported =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  WebViewController? _controller;
  bool _loading = true;
  bool _finishing = false;
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
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => _loading = false);
            // 登录成功后超星会跳到 i.chaoxing.com（或课程首页），这时抓一次 cookie
            if (!_finishing && _looksLoggedIn(url)) {
              _finish();
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(ChaoxingLoginPage.loginUrl));
  }

  bool _looksLoggedIn(String url) {
    if (url.contains('passport2.chaoxing.com')) return false;
    return url.contains('i.chaoxing.com') ||
        url.contains('mooc1.chaoxing.com') ||
        url.contains('mooc2-ans.chaoxing.com');
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _error = null;
    });
    try {
      final cookies = await WebCookieBridge.read();
      if (cookies.isEmpty) {
        if (mounted) {
          setState(() {
            _finishing = false;
            _error = '还没读到登录状态，请先完成登录';
          });
        }
        return;
      }
      final ok = await ChaoxingAuth.instance.loginWithCookies(cookies);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _finishing = false;
          _error = '登录状态无效，请重新登录';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _finishing = false;
          _error = '读取登录状态失败，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('登录学习通'),
        actions: <Widget>[
          if (_controller != null)
            TextButton(
              onPressed: _finishing ? null : _finish,
              child: _finishing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('完成'),
            ),
        ],
      ),
      body: !_supported
          ? _message('网页登录只能在手机 App 内使用')
          : Column(
              children: <Widget>[
                if (_error != null)
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFFFF4E5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9A6A1F),
                      ),
                    ),
                  ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      if (_controller != null)
                        WebViewWidget(controller: _controller!),
                      if (_finishing)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0x66FFFFFF),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    ],
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
