import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/auth/cas_client.dart';

/// 网页版不支持 WebView。
class SimpleWebPage extends StatelessWidget {
  const SimpleWebPage({
    super.key,
    required this.title,
    required this.url,
    this.cookies = const <CasCookie>[],
  });

  final String title;
  final String url;
  final List<CasCookie> cookies;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(title)),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '该页面只能在手机 App 内打开。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
