import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/models.dart';
import '../data/notice_source.dart';
import 'simple_web.dart';

/// 首页：AI 搜索框（搜索中心）+ 通知聚合流。数据来自可注入的 [NoticeSource]。
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.source = const DemoNoticeSource()});

  /// 通知数据源：默认演示数据，正式运行时由底部导航注入官网抓取源。
  final NoticeSource source;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<List<Notice>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.source.fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(context),
            Expanded(
              child: FutureBuilder<List<Notice>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snap.data ?? const <Notice>[];
                  return _noticeList(list);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: GestureDetector(
        onTap: () => _openSearchCenter(context),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.usstRed, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '问点什么，比如“寒假哪天才开始”',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
              Icon(Icons.search, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _openSearchCenter(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('搜索中心', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text('AI 智能问答 · 功能直达 · 历史通知检索',
                style: TextStyle(color: AppColors.textSecondary)),
            SizedBox(height: 16),
            Text(
              '（占位）接入 RAG 校园知识库后，可语义检索历史通知 / 校历 / 规章制度 / 培养计划，\n并支持自然语言直接问答。',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openNotice(Notice notice) async {
    final raw = notice.url;
    if (raw == null || raw.isEmpty) {
      return;
    }
    final uri = Uri.tryParse(raw);
    final url = (uri != null && uri.hasScheme)
        ? raw
        : 'https://jwc.usst.edu.cn${raw.startsWith('/') ? '' : '/'}$raw';
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SimpleWebPage(title: notice.title, url: url),
      ),
    );
  }

  Widget _noticeList(List<Notice> notices) {
    if (notices.isEmpty) {
      return const Center(
        child: Text('暂无通知', style: TextStyle(color: AppColors.textSecondary)),
      );
    }
    final groups = <String, List<Notice>>{};
    for (final n in notices) {
      groups.putIfAbsent(n.dept, () => <Notice>[]).add(n);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: <Widget>[
        for (final entry in groups.entries) _noticeModule(entry.key, entry.value),
      ],
    );
  }

  Widget _noticeModule(String dept, List<Notice> notices) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.usstRed,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dept,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${notices.length} 条',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: notices.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => _noticeRow(notices[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _noticeRow(Notice n) {
    return InkWell(
      onTap: () => _openNotice(n),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                n.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.35),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              n.time,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
