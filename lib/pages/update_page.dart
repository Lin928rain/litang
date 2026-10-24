import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../services/update_service.dart';

/// 发现新版本时的提示 + 下载进度。
Future<void> showUpdateDialog(
  BuildContext context,
  UpdateInfo info, {
  bool startup = false,
}) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('发现新版本 ${info.version}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              info.notes.isEmpty ? '建议更新到最新版本。' : info.notes,
              style: const TextStyle(fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 12),
            const Text(
              '下载后会自动打开系统安装器；部分手机需要在系统设置里允许「安装未知应用」。',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(startup ? '稍后' : '取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('下载并更新'),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateProgressDialog(info: info),
  );
}

class _UpdateProgressDialog extends StatefulWidget {
  const _UpdateProgressDialog({required this.info});

  final UpdateInfo info;

  @override
  State<_UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<_UpdateProgressDialog> {
  double _progress = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final path = await UpdateService.download(
        widget.info,
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      await UpdateService.install(path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().split('\n').first;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('正在下载更新'),
      content: _error != null
          ? Text(
              _error!,
              style: const TextStyle(fontSize: 13, color: AppColors.usstRed),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LinearProgressIndicator(
                  value: _progress <= 0 ? null : _progress,
                ),
                const SizedBox(height: 10),
                Text(
                  '${(_progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
      actions: <Widget>[
        if (_error != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
      ],
    );
  }
}
