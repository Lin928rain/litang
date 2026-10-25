import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/models.dart';
import '../data/notice_prefs.dart';
import '../data/notice_rank.dart';
import '../data/notice_source.dart';
import 'simple_web.dart';

/// 首页：AI 搜索框（搜索中心）+ 通知聚合流。数据来自可注入的 [NoticeSource]。
///
/// 通知不再按部门分块（那样 50 多个学院就是 50 个嵌套滚动区），
/// 改成一条按"分类权重 + 新鲜度 + 本院"排好序的扁平列表，顶部用筛选条收窄。
class HomePage extends StatefulWidget {
  const HomePage({super.key, this.source = const DemoNoticeSource()});

  /// 通知数据源：默认演示数据，正式运行时由底部导航注入远端数据源。
  final NoticeSource source;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  NoticeFeed? _feed;
  Object? _error;
  bool _loading = true;

  List<Notice> _ranked = const <Notice>[];
  List<String> _kinds = const <String>[];

  String? _college;
  String _kind = '全部';
  bool _collegeOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    if (!force) setState(() => _loading = true);
    try {
      final feed = await widget.source.fetch(force: force);
      if (!mounted) return;
      setState(() {
        _feed = feed;
        _error = null;
        _kinds = NoticeRanker.kindsIn(feed.notices);
        _loading = false;
      });
      _recompute();

      // 学院偏好单独读：存储偶尔会慢（甚至没有实现），不该把首屏卡在白屏上
      final college = await NoticePrefs.college();
      if (!mounted || college == null || college == _college) return;
      setState(() => _college = college);
      _recompute();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _recompute() {
    final feed = _feed;
    if (feed == null) return;
    _ranked = NoticeRanker.rank(
      feed.notices,
      college: _college,
      kind: _kind,
      collegeOnly: _collegeOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _searchBar(context),
            if (_feed?.isOffline ?? false) _offlineBanner(),
            if (!_loading && _ranked.isNotEmpty) _filterBar(context),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_feed == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '通知加载失败',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _load(force: true),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  '$_error',
                  maxLines: 3,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (_ranked.isEmpty) {
      return const Center(
        child: Text(
          '这个分类暂时没有通知',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.usstRed,
      onRefresh: () => _load(force: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        itemCount: _ranked.length,
        itemBuilder: (context, i) => _noticeRow(_ranked[i]),
      ),
    );
  }

  // ---------------------------------------------------------------- 顶部

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
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.usstRed, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '问点什么，比如“寒假哪天才开始”',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(Icons.search, color: AppColors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _offlineBanner() {
    final feed = _feed!;
    final at = feed.fetchedAt;
    final when = at == null
        ? ''
        : '（数据 ${at.month}-${at.day}）';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '当前是离线数据$when，下拉可重试',
        style: const TextStyle(fontSize: 11.5, color: Color(0xFF9A6A1F)),
      ),
    );
  }

  Widget _filterBar(BuildContext context) {
    final chips = <String>['全部', ..._kinds];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: <Widget>[
          _collegeChip(context),
          const SizedBox(width: 6),
          for (final k in chips)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _chip(
                label: k,
                selected: _kind == k,
                onTap: () {
                  setState(() => _kind = k);
                  _recompute();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.usstRed : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.usstRed : const Color(0xFFE5E5E5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _collegeChip(BuildContext context) {
    final college = _college;
    final label = college == null
        ? '本院·未设置'
        : (_collegeOnly ? '只看 $college' : '本院优先');
    return GestureDetector(
      onTap: () async {
        if (college == null) {
          await _pickCollege();
          return;
        }
        setState(() => _collegeOnly = !_collegeOnly);
        _recompute();
      },
      onLongPress: _pickCollege,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _collegeOnly ? AppColors.usstRed : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _collegeOnly ? AppColors.usstRed : const Color(0xFFE5E5E5),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.school_outlined,
              size: 13,
              color: _collegeOnly ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: _collegeOnly ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCollege() async {
    final feed = _feed;
    if (feed == null) return;
    final depts = <String>{
      for (final n in feed.notices)
        if (n.kind != '新闻' && n.kind != '党群') n.dept,
    }.toList()..sort();

    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => ListView(
          controller: controller,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '你所在的学院',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                '设置后，本院的通知会排在前面（长按顶部按钮可随时改）',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.clear, size: 20),
              title: const Text('不设置', style: TextStyle(fontSize: 14)),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final d in depts)
              ListTile(
                dense: true,
                title: Text(d, style: const TextStyle(fontSize: 14)),
                trailing: d == _college
                    ? const Icon(Icons.check, size: 18, color: AppColors.usstRed)
                    : null,
                onTap: () => Navigator.pop(ctx, d),
              ),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;
    await NoticePrefs.setCollege(picked.isEmpty ? null : picked);
    setState(() {
      _college = picked.isEmpty ? null : picked;
      if (_college == null) _collegeOnly = false;
    });
    _recompute();
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
            Text(
              '搜索中心',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'AI 智能问答 · 功能直达 · 历史通知检索',
              style: TextStyle(color: AppColors.textSecondary),
            ),
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

  // ---------------------------------------------------------------- 列表项

  static const Map<String, Color> _kindColors = <String, Color>{
    '竞赛': Color(0xFFE53935),
    '教学': Color(0xFF1E88E5),
    '通知': Color(0xFFF29D38),
    '讲座': Color(0xFF7E57C2),
    '学工': Color(0xFF26A69A),
    '就业': Color(0xFF43A047),
    '科研': Color(0xFF3949AB),
    '招生': Color(0xFF00ACC1),
    '新闻': Color(0xFF8D8D8D),
    '党群': Color(0xFF9E9E9E),
  };

  Future<void> _openNotice(Notice notice) async {
    final raw = notice.url;
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    final url = (uri != null && uri.hasScheme)
        ? raw
        : 'https://jwc.usst.edu.cn${raw.startsWith('/') ? '' : '/'}$raw';
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SimpleWebPage(title: notice.title, url: url),
      ),
    );
  }

  Widget _noticeRow(Notice n) {
    final color = _kindColors[n.kind] ?? const Color(0xFF9E9E9E);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openNotice(n),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(top: 2, right: 10),
                width: 3,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            n.kind,
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            n.dept,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: <Widget>[
                  Text(
                    n.timeLabel,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
