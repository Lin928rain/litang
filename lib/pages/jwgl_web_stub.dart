import 'package:flutter/material.dart';

import '../app_theme.dart';

/// 网页版不支持：WebView 只在移动端可用。
class JwglWebPage extends StatelessWidget {
  const JwglWebPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('教务系统')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '网页版教务系统只能在手机 App 内打开。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
