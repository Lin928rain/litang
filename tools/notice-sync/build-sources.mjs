// 由 discovery/*.json 生成 sources.json
//
// 做法：
//   1. 只保留「近两年内还有更新」的栏目（跟 fetch.mjs 的 KEEP_YEARS 对齐）
//   2. 按栏目名猜分类（kind），分类决定默认权重；猜不出就用「其他」
//   3. kind 为「下载 / 其他」的栏目默认 enabled=false —— 保留在配置里，
//      想收的时候把一个 false 改成 true 就行，不用再跑一遍发现
//   4. 输出既保留机器人可读字段（kind/weight/enabled），也保留人可读的 column（栏目原名）
//
// 用法：
//   node build-sources.mjs             # 写入 sources.json
//   node build-sources.mjs --dry       # 只打印统计
//   node build-sources.mjs --min-date 2026-01-01

import { readFile, writeFile, readdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DISC = join(__dirname, 'discovery');

const args = process.argv.slice(2);
const dry = args.includes('--dry');
const mi = args.indexOf('--min-date');
const MIN_DATE = mi >= 0 ? args[mi + 1] : twoYearsAgo();

function twoYearsAgo() {
  const d = new Date();
  d.setFullYear(d.getFullYear() - 2);
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

// ------------------------------------------------------------ 分类规则
// 顺序很重要：越具体的写在越前面。
// 「动态」这类词要小心：「学工动态」是学工、「党建动态」是党群、「工作动态」才是新闻，
// 所以党群/学工排在新闻前面，通知规则里也不放「动态」。
const RULES = [
  // 竞赛 / 创新创业：学生最关心，权重最高
  { re: /竞赛|创新创业|双创|大创|挑战杯|建模|科创/, kind: '竞赛', weight: 95 },
  // 讲座 / 学术活动
  { re: /讲座|讲坛|论坛|沙龙|学术活动|学术报告|报告会|会议|研讨会/, kind: '讲座', weight: 85 },
  // 教学教务
  { re: /教学|教务|培养|课程|考务|考试|选课|学籍|教材|实践|实验|实习|毕设|毕业/, kind: '教学', weight: 90 },
  // 学工
  { re: /学工|学生工作|学生事务|思政|奖助|资助|勤工|心理|宿舍|公寓|军训|迎新|班级/, kind: '学工', weight: 80 },
  // 就业
  { re: /就业|招聘|职业|生涯|用人单位|校招/, kind: '就业', weight: 75 },
  // 党群（要排在新闻前面，否则「党建动态」「工会动态」会被当成新闻）
  { re: /党建|党务|党委|支部|党员|工会|教工|团学|团委|团青|纪检|廉政|巡察|统战|信访/, kind: '党群', weight: 25 },
  // 科研
  { re: /科研|学术|项目|成果|论文|课题|基金|申报|专利/, kind: '科研', weight: 60 },
  // 招生
  { re: /招生|招考|录取|推免|调剂|复试|夏令营/, kind: '招生', weight: 55 },
  // 通知公告：放在这里，避免「教学通知」「竞赛通知」被吃掉
  { re: /通知|公告|公示|通报|告示|信息|文件|安排/, kind: '通知', weight: 88 },
  // 新闻
  { re: /新闻|要闻|快讯|速递|资讯|报道|掠影|风采|动态/, kind: '新闻', weight: 45 },
  // 下载 / 制度
  { re: /下载|资料|表格|附件|规章|制度|条例|黄页|名录/, kind: '下载', weight: 15 },
  // 其他（概况类）
  { re: /概况|简介|名单|师资|队伍|联系|指南|问答|English|English Version|校友|基金|图集|校报|文明|大事记|沿革|章程/, kind: '其他', weight: 10 },
];

function classify(name, dept) {
  for (const r of RULES) if (r.re.test(name)) return r;
  // 部门本身决定性质
  if (/图书馆|信息化|财务处|保卫|后勤|档案馆/.test(dept)) return { kind: '通知', weight: 80 };
  return { kind: '其他', weight: 20 };
}

const KIND_ORDER = ['竞赛', '教学', '通知', '讲座', '学工', '就业', '科研', '招生', '新闻', '党群', '下载', '其他'];
const ENABLED_KINDS = new Set(['竞赛', '教学', '通知', '讲座', '学工', '就业', '科研', '招生', '新闻']);

// 部门层面的加成：这些部门的通知优先级更高
const DEPT_BONUS = [
  { re: /^教务处$|^本科生院$|^研究生院$/, bonus: 12 },
  { re: /^上海理工大学$/, bonus: 10 },
  { re: /图书馆|信息化|财务处|保卫|后勤/, bonus: 6 },
];

// ------------------------------------------------------------ 主流程
const files = (await readdir(DISC)).filter((f) => f.endsWith('.json') && !f.startsWith('_'));
const sites = [];
for (const f of files) {
  try {
    sites.push(JSON.parse(await readFile(join(DISC, f), 'utf8')));
  } catch {
    console.warn(`跳过损坏文件 ${f}`);
  }
}
sites.sort((a, b) => (a.group ?? '').localeCompare(b.group ?? '') || a.dept.localeCompare(b.dept));

const out = [];
const dropped = [];
const seenUrl = new Set();

for (const site of sites) {
  if (site.error) continue;
  for (const col of site.columns ?? []) {
    if (!col.url || !col.cid) continue;
    if ((col.latest ?? '') < MIN_DATE) {
      dropped.push({ ...col, dept: site.dept, why: 'too-old' });
      continue;
    }
    if (seenUrl.has(col.url)) {
      dropped.push({ ...col, dept: site.dept, why: 'dup-url' });
      continue;
    }
    seenUrl.add(col.url);

    const name = col.name || `栏目${col.cid}`;
    const cls = classify(name, site.dept);
    if (cls.kind === '其他') {
      // 概况/师资/联系方式这类静态页，对通知流没有意义，直接不进配置
      dropped.push({ ...col, dept: site.dept, why: 'static-page' });
      continue;
    }
    const bonus = DEPT_BONUS.find((b) => b.re.test(site.dept))?.bonus ?? 0;
    const scope = site.group === '学院' ? 'college' : 'school';

    out.push({
      id: `${site.host}-${col.cid}`,
      dept: site.dept,
      column: name,
      linkText: col.linkText || '',
      category: cls.kind,
      kind: cls.kind,
      scope,
      group: site.group,
      weight: cls.weight + bonus,
      enabled: ENABLED_KINDS.has(cls.kind),
      url: col.url,
      latest: col.latest,
      paging: Boolean(col.hasPaging),
    });
  }
}

// 同 id 只留一条
const byId = new Map();
for (const s of out) if (!byId.has(s.id)) byId.set(s.id, s);

// 首页直链兜底：有些栏目根本没有列表页（GET /<cid>/list.htm 回「提示信息」），
// 但首页上挂着它们的文章。把首页当成一个源、只收这些 cid，算是补漏。
for (const site of sites) {
  if (site.error || !site.home) continue;
  const fresh = (site.unresolvedCids ?? []).filter((o) => (o.date ?? '') >= MIN_DATE);
  if (!fresh.length) continue;
  const id = `${site.host}-home`;
  if (byId.has(id)) continue;
  byId.set(id, {
    id,
    dept: site.dept,
    column: '首页直链',
    linkText: '',
    category: '通知',
    kind: '通知',
    scope: site.group === '学院' ? 'college' : 'school',
    group: site.group,
    weight: 70,
    enabled: true,
    type: 'home',
    onlyCids: fresh.map((o) => o.cid),
    url: site.home,
    latest: fresh.map((o) => o.date).sort().pop(),
    paging: false,
  });
}
const sources = [...byId.values()].sort(
  (a, b) => b.weight - a.weight || a.dept.localeCompare(b.dept) || (b.latest ?? '').localeCompare(a.latest ?? ''),
);

// 同一部门里的重名栏目（很多站点的 <title> 都只写「最新通知」）用导航文字 / cid 区分
const nameGroups = new Map();
for (const s of sources) {
  const k = `${s.dept}#${s.column}`;
  if (!nameGroups.has(k)) nameGroups.set(k, []);
  nameGroups.get(k).push(s);
}
let renamed = 0;
for (const list of nameGroups.values()) {
  if (list.length < 2) continue;
  for (const s of list) {
    const tag = s.linkText && s.linkText !== s.column ? s.linkText : s.id;
    s.column = `${s.column}（${tag}）`;
    renamed++;
  }
}

// 统计
const stat = (list) => {
  const m = new Map();
  for (const s of list) m.set(s.kind, (m.get(s.kind) ?? 0) + 1);
  return KIND_ORDER.filter((k) => m.has(k)).map((k) => `${k}:${m.get(k)}`).join('  ');
};
const enabledCount = sources.filter((s) => s.enabled).length;

console.log(`站点 ${sites.filter((s) => !s.error).length} 个，栏目 ${sources.length} 个（启用 ${enabledCount}）`);
console.log(`分类：${stat(sources)}`);
console.log(
  `丢弃：${dropped.length} 个（过旧 ${dropped.filter((d) => d.why === 'too-old').length}，` +
    `静态页 ${dropped.filter((d) => d.why === 'static-page').length}，` +
    `重复 URL ${dropped.filter((d) => d.why === 'dup-url').length}）`,
);
if (renamed) console.log(`重名栏目去重：${renamed} 个加了后缀`);

if (dry) {
  for (const k of KIND_ORDER) {
    const xs = sources.filter((s) => s.kind === k);
    if (!xs.length) continue;
    console.log(`\n=== ${k} (${xs.length}) ===`);
    for (const s of xs.slice(0, 12)) console.log(`  ${String(s.weight).padStart(3)} ${s.dept} / ${s.column}  ${s.url}`);
    if (xs.length > 12) console.log(`  …另有 ${xs.length - 12} 个`);
  }
} else {
  const payload = {
    schemaVersion: 3,
    updatedAt: new Date().toISOString().slice(0, 10),
    _note:
      '由 build-sources.mjs 从 discovery/ 自动生成。想加/减栏目改 discovery 结果或直接改本文件；enabled=false 的栏目会被 fetch.mjs 跳过。',
    minDate: MIN_DATE,
    count: sources.length,
    enabledCount,
    sources,
  };
  await writeFile(join(__dirname, 'sources.json'), JSON.stringify(payload, null, 2), 'utf8');
  console.log(`\n已写入 sources.json`);
}
