import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// 通知数据源抽象。UI 面向这个接口，来源可插拔。
abstract class NoticeSource {
  Future<List<Notice>> fetch();
}

/// 演示数据源：答辩 / 离线 / 抓取失败时的兜底。
class DemoNoticeSource implements NoticeSource {
  const DemoNoticeSource();

  @override
  Future<List<Notice>> fetch() async => const [
    Notice(dept: '教务处', title: '关于调整校园上下课铃声的通知', time: '今天 08:30'),
    Notice(dept: '校务公告', title: '关于举办校分析测试中心第一届微结构摄影大赛的通知', time: '昨天 15:20'),
    Notice(
      dept: '教务处',
      title: '关于 2026 上海市高等学校信息技术水平考试模拟考试的通知',
      time: '10-20 09:30',
    ),
    Notice(
      dept: '光电信息与计算机工程学院',
      title: '学术讲座：2026 年诺贝尔光遗传学奖与类脑深度计算（三教 313）',
      time: '10-14 13:30',
    ),
  ];
}

/// 官网抓取数据源：抓教务处公开列表页（无需登录），失败时回退到 [_fallback]。
///
/// 备注：Flutter Web 预览会被浏览器 CORS 拦截而回退到演示数据；
/// 打包成移动端 App 后无 CORS 限制，可抓到真实数据。
class JwcNoticeSource implements NoticeSource {
  JwcNoticeSource([this._fallback = const DemoNoticeSource()]);

  final NoticeSource _fallback;

  static const Map<String, String> _listUrls = {
    '教务处': 'https://jwc.usst.edu.cn/10239/list.htm',
    '通知公告': 'https://jwc.usst.edu.cn/zygg/list.htm',
    '健康学院': 'https://jiankang.usst.edu.cn/',
  };

  @override
  Future<List<Notice>> fetch() async {
    final result = <Notice>[];
    for (final entry in _listUrls.entries) {
      try {
        final res = await http
            .get(Uri.parse(entry.value))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final parsed = _parse(
            utf8.decode(res.bodyBytes),
            entry.key,
            entry.value,
          );
          // 每个来源只取前 8 条，避免一个栏目把首页刷满
          result.addAll(parsed.take(8));
        }
      } catch (_) {
        // 忽略单条失败，继续下一个源
      }
    }
    if (result.isEmpty) return _fallback.fetch();
    return result.take(30).toList();
  }

  /// 解析 wisedu(webplus) 列表页：
  /// <li class="news n1 clearfix">
  ///   <span class="news_title"><a href='...' title='标题'>标题</a></span>
  ///   <span class="news_meta">2026-10-22</span>
  /// </li>
  List<Notice> _parse(String html, String dept, String baseUrl) {
    final items = <Notice>[];
    final liRe = RegExp(r'<li class="news[^"]*">([\s\S]*?)</li>');
    final titleRe = RegExp(
      r'''title=['"]([^'"]+)['"]|<div class="news_title">([^<]+)</div>|<span class="news_title">([^<]+)</span>''',
    );
    final dateRe = RegExp(
      r'<span class="news_meta">([^<]*)</span>|(\d{4}-\d{2}-\d{2})',
    );
    final hrefRe = RegExp(r'''href=['"]([^'"]+)['"]''');
    final base = Uri.parse(baseUrl);

    for (final m in liRe.allMatches(html)) {
      final block = m.group(1) ?? '';
      final tm = titleRe.firstMatch(block);
      final title = (tm?.group(1) ?? tm?.group(2) ?? tm?.group(3) ?? '').trim();
      if (title.isEmpty) {
        continue;
      }
      final date =
          (dateRe.firstMatch(block)?.group(1) ??
                  dateRe.firstMatch(block)?.group(2) ??
                  '')
              .trim();
      final href = hrefRe.firstMatch(block)?.group(1);
      String? url;
      if (href != null && href.isNotEmpty) {
        url = base.resolve(href).toString();
      }
      items.add(Notice(dept: dept, title: title, time: date, url: url));
    }
    return items;
  }
}
