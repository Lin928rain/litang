import 'package:flutter/material.dart';

import '../app_theme.dart';

/// 生活页。
///
/// 开源版本**不包含**学习通、一网畅学的课程 / 作业 / 签到等集成功能
/// （相关实现属于第三方平台的接口逆向，不对外发布）。
/// 这里只保留校园卡入口占位，保持界面结构完整。
class LifePage extends StatelessWidget {
  const LifePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: <Widget>[
            const Text(
              '生活学习',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _notice(),
            const SizedBox(height: 12),
            _campusCard(context),
          ],
        ),
      ),
    );
  }

  Widget _notice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.usstRed,
              ),
              const SizedBox(width: 8),
              const Text(
                '开源版本说明',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '这个仓库是「理堂」的开源版本，保留首页通知、校园地图、课表、'
            '成绩 / 绩点 / 排名、培养计划等功能。\n\n'
            '学习通、一网畅学的课程、作业、考试、签到、讨论等集成，'
            '涉及对第三方平台接口的逆向，出于合规考虑不在此仓库发布。',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.7,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _campusCard(BuildContext context) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('校园卡功能还在接入中，先用官方渠道出示二维码')),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.redTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.credit_card,
                size: 20,
                color: AppColors.usstRed,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '校园卡',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '余额 · 消费记录 · 挂失',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
