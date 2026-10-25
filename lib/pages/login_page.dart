import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/auth/cas_client.dart';
import '../data/auth/jwgl_auth.dart';

/// 教务系统登录页（统一身份认证 CAS）。
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _busy = false;
  String? _error;
  bool _remember = true;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    final username = _idController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = '请填写学号和密码');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await JwglAuth.instance.login(username, password, remember: _remember);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on CasLoginException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = '网络异常，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('登录教务系统')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: <Widget>[
          const Icon(Icons.school_outlined, size: 56, color: AppColors.usstRed),
          const SizedBox(height: 12),
          const Text(
            '使用统一身份认证登录',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            '和学校统一身份认证同一套学号密码',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _idController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '学号',
              prefixIcon: Icon(Icons.badge_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: const InputDecoration(
              labelText: '密码',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
          ),
          SwitchListTile(
            value: _remember,
            onChanged: (value) => setState(() => _remember = value),
            contentPadding: EdgeInsets.zero,
            title: const Text('记住登录', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              '学号密码用系统级加密（Keystore/Keychain）保存在本机，仅用于自动登录',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.usstRed, fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: AppColors.usstRed),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('登录'),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '非官方项目。账号密码只在本机使用：未勾选记住登录时只保存登录状态；'
            '勾选后密码会加密保存在系统密钥库（Android Keystore / iOS Keychain），'
            '不会上传到任何服务器，也不会写入日志。登录后仅读取你本人的课表、成绩等信息。',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
