import 'dart:io';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

/// 常见图片后缀判断（附件决定是否内置预览时用）。
bool isImageName(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.bmp') ||
      lower.endsWith('.heic');
}

/// 本地图片预览（可缩放），右上角可交给系统保存/分享。
class ImagePreviewPage extends StatelessWidget {
  const ImagePreviewPage({super.key, required this.title, required this.path});

  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            tooltip: '下载 / 用其他应用打开',
            icon: const Icon(Icons.download_outlined),
            onPressed: () async {
              final result = await OpenFilex.open(path);
              if (result.type != ResultType.done && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.message.isEmpty ? '没有可打开该图片的应用' : result.message,
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 6,
          child: Image.file(
            File(path),
            errorBuilder: (_, _, _) => const Text(
              '图片加载失败',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ),
      ),
    );
  }
}
