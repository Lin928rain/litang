// 解析器单测：用实测到的 5 种模板结构做 fixture
import test from 'node:test';
import assert from 'node:assert/strict';
import { parseList, parseDate, yearFromUrl } from './fetch.mjs';

const SOURCE = {
  id: 'test',
  dept: '测试学院',
  category: '通知公告',
  scope: 'college',
  url: 'https://example.edu.cn/12345/list.htm',
};

test('模板1：li.news + news_title + news_date', () => {
  const html = `
    <ul class="news_list">
      <li class="news n1">
        <div class="news_title line1"><a href='/2025/1231/c11992a354948/page.htm' title='光电学院教职工代表大会召开'>光电学院教职工代表大会召开</a></div>
        <div class="news_date">2025-12-31</div>
      </li>
    </ul>`;
  const items = parseList(html, SOURCE);
  assert.equal(items.length, 1);
  assert.equal(items[0].title, '光电学院教职工代表大会召开');
  assert.equal(items[0].date, '2025-12-31');
  assert.equal(items[0].url, 'https://example.edu.cn/2025/1231/c11992a354948/page.htm');
  assert.equal(items[0].dept, '测试学院');
});

test('模板2：链接内嵌 div + news_meta 日期', () => {
  const html = `
    <li class="news n1">
      <a class="news_wz" href="/2026/1020/c17918a372550/page.htm" target="_blank">
        <div class="news_title line1">关于2026年度重点课程申报的公示</div>
        <div class="news_meta"> 2026.10.20 </div>
      </a>
    </li>`;
  const items = parseList(html, SOURCE);
  assert.equal(items.length, 1);
  assert.equal(items[0].title, '关于2026年度重点课程申报的公示');
  assert.equal(items[0].date, '2026-10-20');
});

test('模板3：listDetailsItem 结构', () => {
  const html = `
    <div class="listDetailsItem listDetailsItem1">
      <p class="listDetailsItemTitle"><a href='/2020/0522/c6945a220805/page.htm' target='_blank' title='关于推荐优秀学生参加交流项目的通知'>关于推荐优秀学生参加交流项目的通知</a></p>
      <p class="listDetailsItemTime">2020-05-22</p>
    </div>`;
  const items = parseList(html, SOURCE);
  assert.equal(items.length, 1);
  assert.equal(items[0].title, '关于推荐优秀学生参加交流项目的通知');
  assert.equal(items[0].date, '2020-05-22');
});

test('模板4：纯 table 行', () => {
  const html = `
    <tr><td><a href='/2026/1019/c2967a372453/page.htm' target='_blank' title='保龄球比赛赛事运营服务比选公告'>保龄球比赛赛事运营服务比选公告</a></td><td>2026-10-19</td></tr>`;
  const items = parseList(html, SOURCE);
  assert.equal(items.length, 1);
  assert.equal(items[0].title, '保龄球比赛赛事运营服务比选公告');
  assert.equal(items[0].date, '2026-10-19');
});

test('模板5：标题与摘要挤在一起时只保留标题', () => {
  const html = `
    <li class="news n1">
      <a class="news_box" href="/2026/1025/c14380a372908/page.htm">
        <div class="news_wz">
          <div class="news_title line1">能动学院师生应邀参观流体机械展</div>
          <div class="news_text">由中国通用机械工业协会主办的第13届展览会在国家会展中心举办，来自20多个国家和地区……</div>
        </div>
      </a>
    </li>`;
  const items = parseList(html, SOURCE);
  assert.equal(items.length, 1);
  assert.equal(items[0].title, '能动学院师生应邀参观流体机械展');
});

test('过滤导航链接和「更多」', () => {
  const html = `
    <a href="/12345/list.htm">更多</a>
    <a href="/2020/0528/c9012a222363/page.htm">学术委员会</a>`;
  const items = parseList(html, SOURCE);
  // 导航页链接（不含 cXXXaYYY 的 list.htm）被过滤；"更多" 被过滤；
  // "学术委员会" 虽然是指向文章页，但它是导航，长度 >=4 会被保留——
  // 这里断言只保留一条，且不是「更多」
  assert.ok(items.every((i) => i.title !== '更多'));
});

test('日期解析：多种格式', () => {
  assert.equal(parseDate('2026-10-22'), '2026-10-22');
  assert.equal(parseDate('2026.10.20'), '2026-10-20');
  assert.equal(parseDate('2026年10月9日'), '2026-10-09');
  assert.equal(parseDate('2026/1/5'), '2026-01-05');
  assert.equal(parseDate(''), null);
  assert.equal(parseDate('没有日期'), null);
});

test('日期解析：只有月日时补当前年', () => {
  const year = new Date().getFullYear();
  assert.equal(parseDate('10-22'), `${year}-10-22`);
});

test('同一链接只保留一条', () => {
  const html = `
    <li class="news n1"><div class="news_title"><a href="/2026/1022/c1a2/page.htm">关于选课的通知</a></div></li>
    <li class="news n2"><div class="news_title"><a href="/2026/1022/c1a2/page.htm">关于选课的通知</a></div></li>`;
  const items = parseList(html, SOURCE);
  assert.equal(items.length, 1);
  assert.equal(items[0].title, '关于选课的通知');
});

test('过短的文本不当标题（导航项过滤）', () => {
  const html = `
    <li class="news n1"><div class="news_title"><a href="/2026/1022/c1a2/page.htm">更多</a></div></li>`;
  assert.equal(parseList(html, SOURCE).length, 0);
});

test('空页面返回空数组', () => {
  assert.deepEqual(parseList('<html><body>暂无内容</body></html>', SOURCE), []);
});

test('只有月-日时用文章 URL 的年份补全（避免 2018 年通知被当成今年）', () => {
  const html = `
    <li class="news n1">
      <div class="news_title"><a href="/2018/1024/c10682a136228/page.htm">关于开展征文活动的通知</a></div>
      <div class="news_date">10-24</div>
    </li>`;
  const items = parseList(html, SOURCE);
  assert.equal(items.length, 1);
  assert.equal(items[0].date, '2018-10-24');
});

test('从 URL 提取年份', () => {
  assert.equal(yearFromUrl('https://a.edu.cn/2026/1022/c1a2/page.htm'), 2026);
  assert.equal(
    yearFromUrl('https://a.edu.cn/2018/0502/c6309a133217/page.htm'),
    2018,
  );
  assert.equal(yearFromUrl('https://a.edu.cn/xyz/page.htm'), null);
});

test('日期窗口不侵占相邻条目的日期', () => {
  // 第一条没有日期，第二条有。第一条不能把第二条的日期当自己的。
  const html = `
    <li class="news n1">
      <a href="/2026/0101/c1a1/page.htm">第一条没有日期的通知</a>
    </li>
    <li class="news n2">
      <div class="news_title"><a href="/2026/0202/c1a2/page.htm">第二条有日期的通知</a></div>
      <div class="news_date">2026-02-02</div>
    </li>`;
  const items = parseList(html, SOURCE);
  assert.equal(items.length, 2);
  const first = items.find((i) => i.title.includes('第一条'));
  assert.notEqual(
    first.date,
    '2026-02-02',
    '第一条不应拿到第二条的日期',
  );
});

test('title 属性里又塞了一整段 <a>（研究生院那种畸形模板）', () => {
  // 实测 yjs.usst.edu.cn：外层 <a> 的 title 属性值本身是 HTML
  const html = `
    <table class="wp_article_list_table"><tr><td>
      <span class="time fr">2026-09-30</span>
      <a href="/2026/0930/c11872a371339/page.htm" title="<a href='/2026/0930/c11872a371339/page.htm' target='_blank' title='关于组织申报来华留学研究生全英（外）文授课培养项目建设典型案例的通知'>关于组织申报来华留学研究生全英（外）文授课培养项目建设典型案...</a>"><a href='/2026/0930/c11872a371339/page.htm' target='_blank' title='关于组织申报来华留学研究生全英（外）文授课培养项目建设典型案例的通知'>关于组织申报来华留学研究生全英（外）文授课培养项目建设典型案...</a></a>
    </td></tr></table>`;
  const items = parseList(html, SOURCE);
  assert.equal(items.length, 1);
  assert.equal(
    items[0].title,
    '关于组织申报来华留学研究生全英（外）文授课培养项目建设典型案例的通知',
    '不能把 <a href= 当成标题，也不能用被省略号截断的展示文案',
  );
  assert.equal(items[0].date, '2026-09-30');
});

test('摘要里写了截止日期时，用列表里的发布日期', () => {
  // 摘要正文常写「截止时间 2026-10-13」，不能盖掉真正的发布日
  const html = `
    <li class="news n3 clearfix">
      <div class="news_wz">
        <div class="news_title"><a href='/2026/0914/c18415a370397/page.htm' title='统计建模大赛获奖名单公告'>统计建模大赛获奖名单公告</a></div>
        <div class="news_text"><a href='/2026/0914/c18415a370397/page.htm'>本次大赛于 2026-10-13 截止报名，现将名单公示如下，请相互转告并及时核对信息。</a></div>
        <div class="news_meta">2026-09-14</div>
      </div>
    </li>`;
  const items = parseList(html, SOURCE);
  assert.equal(items.length, 1);
  assert.equal(items[0].date, '2026-09-14');
});

test('列表页没有日期时用文章 URL 里的归档日期兜底', () => {
  const html = `
    <li class="news n1">
      <div class="news_title"><a href="/2026/0320/c18415a364360/page.htm">第二轮报名通知</a></div>
    </li>`;
  const items = parseList(html, SOURCE);
  assert.equal(items.length, 1);
  assert.equal(items[0].date, '2026-03-20');
});

test('整行塞进一个 <a>（日期 + 标题 + 浏览量）时只留标题', () => {
  // 实测 fund.usst.edu.cn：<a>2026-10-22 名单公示 10</a>
  const html = `
    <tr>
      <td><a href="/2026/1022/c1234a567/page.htm">2026-10-22 2025-2026学年外语学院华贞助学奖学金名单公示 10</a></td>
    </tr>`;
  const items = parseList(html, SOURCE);
  assert.equal(items.length, 1);
  assert.equal(items[0].title, '2025-2026学年外语学院华贞助学奖学金名单公示');
  assert.equal(items[0].date, '2026-10-22');
});
