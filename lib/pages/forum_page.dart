import 'package:flutter/material.dart';

import '../app_theme.dart';

/// 论坛：MVP 先做“课程小组作业找搭子”。
class ForumPage extends StatelessWidget {
  const ForumPage({super.key});

  static const List<Map<String, String>> _posts = [
    {
      'course': '数据结构',
      'demand': '课程大作业找 2 名队友，一起做图算法部分',
      'people': '还差 2 人',
      'author': '22 计科 · 小王',
    },
    {
      'course': '大学物理实验',
      'demand': '求组队做双缝干涉实验报告',
      'people': '还差 1 人',
      'author': '22 光电 · A 同学',
    },
    {
      'course': '机械设计基础',
      'demand': '想找人一起复习期末，约图书馆 3 楼',
      'people': '队伍 3 人',
      'author': '22 机械 · 阿哲',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _publish(context),
        backgroundColor: AppColors.usstRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('发起找搭子'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('课程找搭子',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: _posts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final p = _posts[i];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.redTint,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p['course']!,
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.usstRed),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              p['people']!,
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p['demand']!,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p['author']!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _publish(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('发起找搭子（占位）',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text('绑定课号 · 填写需求 / 人数 / 技能，发布到对应课程专区。',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
          ],
        ),
      ),
    );
  }
}