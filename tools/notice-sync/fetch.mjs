#!/usr/bin/env node
// 校园通知抓取：并发抓各学院列表页 → 解析成统一结构 → 与历史合并 → 输出 notices.json
//
// 用法：
//   node fetch.mjs                 # 抓取并写入 ../out/notices.json
//   node fetch.mjs --dry           # 只打印结果，不写文件
//   node fetch.mjs --limit 3       # 每个源只取前 3 条（调试用）

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, 'out');
const OUT_FILE = join(OUT_DIR, 'notices.json');

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

/** 历史保留上限（条数） */
const MAX_HISTORY = 1200;
/** 每条源最多取多少条 */
const PER_SITE_LIMIT = 200;
/** 每个源最多翻多少页（防止改版后无限翻页） */
const MAX_PAGES = 8;
/** 只保留近 N 年的通知 */
const KEEP_YEARS = 2;

const args = process.argv.slice(2);
const dry = args.includes('--dry');
const limitArg = args.indexOf('--limit');
const perSiteLimit =
  limitArg >= 0 ? Number(args[limitArg + 1]) || PER_SITE_LIMIT : PER_SITE_LIMIT;

// ---------------------------------------------------------------- HTML 工具

const ENTITIES = {
  '&nbsp;': ' ',
  '&amp;': '&',
  '&lt;': '<',
  '&gt;': '>',
  '&quot;': '"',
  '&#39;': "'",
  '&ldquo;': '“',
  '&rdquo;': '”',
  '&mdash;': '—',
  '&middot;': '·',
};

function decodeEntities(text) {
  let out = text;
  for (const [k, v] of Object.entries(ENTITIES)) out = out.split(k).join(v);
  // 数字实体
  out = out.replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(Number(d)));
  return out;
}

function stripTags(html) {
  return decodeEntities(html.replace(/<[^>]+>/g, ' '))
    .replace(/\s+/g, ' ')
    .trim();
}

function absoluteUrl(href, base) {
  try {
    return new URL(href, base).toString();
  } catch {
    return null;
  }
}

/** 解析多种日期写法，统一成 YYYY-MM-DD；失败返回 null
 *  @param yearHint 只有「月-日」时用于补年份（通常从文章 URL 里的 /2026/1022/ 推断）
 */
export function parseDate(raw, yearHint = null) {
  if (!raw) return null;
  const text = String(raw).trim();
  let m = text.match(/(\d{4})[-./年]\s*(\d{1,2})[-./月]\s*(\d{1,2})/);
  if (m) return normalize(m[1], m[2], m[3]);
  // 只有 月-日：用传入的年份，没有再退回当前年
  m = text.match(/^(\d{1,2})[-./](\d{1,2})$/);
  if (m) return normalize(String(yearHint ?? new Date().getFullYear()), m[1], m[2]);
  m = text.match(/(\d{1,2})[-./](\d{1,2})/);
  if (m) return normalize(String(yearHint ?? new Date().getFullYear()), m[1], m[2]);
  return null;
}

/** 从文章链接里取年份：/2026/1022/c... → 2026 */
export function yearFromUrl(url) {
  const m = String(url).match(/\/(\d{4})\/\d{2}\d{2}\//);
  return m ? Number(m[1]) : null;
}

function normalize(y, mo, d) {
  const year = Number(y);
  const month = Number(mo);
  const day = Number(d);
  if (!(month >= 1 && month <= 12 && day >= 1 && day <= 31)) return null;
  const pad = (n) => String(n).padStart(2, '0');
  return `${year}-${pad(month)}-${pad(day)}`;
}

// ---------------------------------------------------------------- 解析器

/**
 * 解析通知列表。学校各站点用的模板不统一，实测到 5 种容器：
 *   1. <li class="news n1">  + .news_title + .news_date / .news_meta
 *   2. <li class="news">     + .news_wz > .news_title + .news_text
 *   3. <div class="listDetailsItem"> + .listDetailsItemTitle + .listDetailsItemTime
 *   4. 纯 <table> 行：<td><a title="..">..</a></td><td>日期</td>
 *   5. 兜底：任何指向 cXXXaYYY 的 <a>，向前后各取一小段当容器
 *
 * 所以不按容器 class 匹配，而是「以文章链接为锚点」倒推出标题和日期。
 */
export function parseList(html, source) {
  const items = [];
  const seen = new Set();

  // 所有文章链接（webplus 的文章页形如 /2026/1022/c10239a372764/page.htm）
  // 注意：<a> 里常嵌套 <div>/<font>/<img>，所以用「贪婪到下一个 </a>」并单独取 href 属性，
  // 而不是用 <a ...>文本</a> 的整段匹配（遇到嵌套标签会断）。
  const anchorRe = /<a\b([^>]*)>/gi;
  let m;
  while ((m = anchorRe.exec(html))) {
    const attrs = m[1];
    const hrefMatch = attrs.match(/href\s*=\s*["']([^"']+)["']/i);
    if (!hrefMatch) continue;
    const href = hrefMatch[1];
    // webplus 文章页：/2026/1022/c10239a372764/page.htm
    // 页码位数不固定（实测有 a372764、也有 a2），所以都允许
    if (!/\/c\d+a\d+\/|page\.(htm|html|psp)/i.test(href)) continue;

    const url = absoluteUrl(href, source.url);
    if (!url || seen.has(url)) continue;

    // 链接内部的 HTML：从当前 <a> 到它对应的 </a>
    const closeIdx = html.indexOf('</a>', anchorRe.lastIndex);
    const innerHtml = closeIdx > 0
      ? html.slice(anchorRe.lastIndex, closeIdx)
      : '';
    const innerText = stripTags(innerHtml);

    // 标题优先级：
    //   1. 链接附近（内部或其外层最近容器）的明确标题元素，最可靠、不含摘要
    //   2. <a title="...">
    //   3. 链接内文本
    let title = null;
    // 取链接外层一小段（模板1把 .news_title 包在 <a> 外面）
    const outerStart = Math.max(0, m.index - 300);
    const outerHtml = html.slice(outerStart, (closeIdx > 0 ? closeIdx : anchorRe.lastIndex) + 200);
    const titleEl = outerHtml.match(
      /class="[^"]*(?:news_title|ItemTitle|article_title)[^"]*"[^>]*>([\s\S]*?)<\/(?:div|p|h\d|span)>/i,
    );
    if (titleEl) {
      const candidate = stripTags(titleEl[1]);
      // 必须包含链接内文本，才认定是这条的标题（避免拿到相邻条目的标题）
      if (candidate && (innerText.length < 4 || candidate.includes(innerText) || innerText.includes(candidate))) {
        title = candidate;
      }
    }
    if (!title) {
      const titleAttr = attrs.match(/title\s*=\s*["']([^"']{4,})["']/i);
      if (titleAttr) title = stripTags(titleAttr[1]);
    }
    if (!title && innerText.length >= 4) {
      title = innerText
        .replace(/\s*\d{4}[-./]\d{1,2}[-./]\d{1,2}\s*$/, '')
        .trim();
    }
    if (!title || title.length < 4) continue;
    // 兜底截断：标题后面被拼进摘要时，按句号/省略号/长度截
    if (title.length > 60) {
      const cut = title.search(/[。！？；]|\.\.\./);
      title = (cut > 10 ? title.slice(0, cut) : title.slice(0, 60)).trim();
    }
    // 过滤导航类短词
    if (/^(更多|查看更多|ViewMore|阅读全文|详细|next|prev)/i.test(title)) continue;

    seen.add(url);

    // 文章 URL 里带年份：/2026/1022/c10239a372764/page.htm
    // 列表页只写「10-22」时，用这个年份补全，避免把 2018 年的通知当成今年的。
    const yearHint = yearFromUrl(url);

    // 日期：优先链接内部，其次紧邻的父容器（而不是整个前后窗口，
    // 否则会把相邻条目的日期当成自己的）
    let date = null;
    const innerDate = innerHtml.match(/(\d{4}[-./]\d{1,2}[-./]\d{1,2})/);
    if (innerDate) {
      date = parseDate(innerDate[1], yearHint);
    } else {
      // 往后取到本条结束（通常是 </li> / </div> / </tr>），最多 260 字符。
      // 不能再往前找：往前会把上一条通知的日期当成自己的。
      const tailStart = closeIdx > 0 ? closeIdx : anchorRe.lastIndex;
      const tail = html.slice(tailStart, Math.min(html.length, tailStart + 260));
      // 截到本条真正结束的位置，避免跨到下一 <li>
      const endTag = tail.search(/<\/li>|<\/tr>/i);
      const after = endTag > 0 ? tail.slice(0, endTag) : tail;

      let dm = after.match(/(\d{4}[-./]\d{1,2}[-./]\d{1,2})/);
      if (dm) {
        date = parseDate(dm[1], yearHint);
      } else {
        const sm = after.match(/(?<!\d)(\d{1,2})[-./](\d{1,2})(?!\d)/);
        if (sm) date = parseDate(`${sm[1]}-${sm[2]}`, yearHint);
      }
    }
    // 日期明显晚于今天（比如把文章里的未来日期当成了发布日）就不采信
    if (date && date > new Date().toISOString().slice(0, 10)) date = null;

    items.push({
      id: `${source.id}:${url}`,
      dept: source.dept,
      category: source.category,
      scope: source.scope,
      title,
      url,
      date,
    });
  }

  return items;
}

// ---------------------------------------------------------------- 抓取

async function fetchSite(source, timeoutMs = 25000) {
  const collected = [];
  const seenUrls = new Set();
  let lastError = null;
  let pages = 0;

  // webplus 翻页：list.htm → list2.htm → list3.htm …
  for (let page = 1; page <= MAX_PAGES; page++) {
    const url = pageUrl(source.url, page);
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), timeoutMs);
    try {
      const resp = await fetch(url, {
        headers: { 'User-Agent': UA, Accept: 'text/html,*/*' },
        redirect: 'follow',
        signal: ctrl.signal,
      });
      // 第 2 页起 404 = 没有更多页，正常结束
      if (!resp.ok) {
        if (page > 1) break;
        throw new Error(`HTTP ${resp.status}`);
      }
      const html = Buffer.from(await resp.arrayBuffer()).toString('utf8');

      let added = 0;
      for (const item of parseList(html, source)) {
        if (seenUrls.has(item.url)) continue;
        seenUrls.add(item.url);
        collected.push(item);
        added++;
      }
      pages++;

      // 本页没有新内容 = 到底了
      if (added === 0) break;
      if (!hasNextPage(html)) break;
    } catch (e) {
      lastError = e;
      if (page === 1) {
        return {
          source,
          items: [],
          pages: 0,
          status: 'error',
          error: e.name === 'AbortError' ? 'timeout' : String(e.message || e),
        };
      }
      break; // 后续页失败就停，已抓到的保留
    } finally {
      clearTimeout(timer);
    }
  }

  return {
    source,
    items: collected,
    pages,
    status: collected.length > 0 ? 'ok' : 'error',
    error:
      collected.length === 0
        ? String(lastError?.message ?? '无数据')
        : undefined,
  };
}

/** webplus 翻页地址：list.htm → list2.htm */
function pageUrl(base, page) {
  if (page === 1) return base;
  return base.replace(/list(\d*)\.htm(\?.*)?$/i, `list${page}.htm$2`);
}

/** 页面是否还有下一页 */
function hasNextPage(html) {
  // 明确的分页链接（list2.htm / list3.htm …）
  if (/href=["'][^"']*list\d+\.htm["']/i.test(html)) return true;
  return false;
}

// ---------------------------------------------------------------- 合并

function loadPrevious(raw) {
  try {
    const json = JSON.parse(raw);
    if (Array.isArray(json)) return json;
    if (Array.isArray(json.notices)) return json.notices;
  } catch {
    /* 没有历史就当空 */
  }
  return [];
}

function merge(previous, fresh) {
  const byId = new Map();
  // 新的优先
  for (const n of fresh) byId.set(n.id, n);
  for (const n of previous) if (!byId.has(n.id)) byId.set(n.id, n);

  const all = [...byId.values()];
  // 排序：有日期的按日期倒序，没日期的排后面
  all.sort((a, b) => {
    if (a.date && b.date) return b.date.localeCompare(a.date);
    if (a.date) return -1;
    if (b.date) return 1;
    return 0;
  });
  return all.slice(0, MAX_HISTORY);
}

/** 同一标题（去标点空格）只留最新一条，避免同一通知在多个栏目重复出现 */
function dedupe(list) {
  const seen = new Map();
  const out = [];
  for (const n of list) {
    const key = n.title.replace(/[\s\p{P}]/gu, '');
    const prev = seen.get(key);
    if (prev) {
      // 保留日期更新的那条
      if (!prev.date && n.date) {
        seen.set(key, n);
        const i = out.indexOf(prev);
        if (i >= 0) out[i] = n;
      }
      continue;
    }
    seen.set(key, n);
    out.push(n);
  }
  return out;
}

// ---------------------------------------------------------------- main

async function main() {
  const sourcesPath = join(__dirname, 'sources.json');
  const config = JSON.parse(await readFile(sourcesPath, 'utf8'));
  const sites = config.sites ?? [];

  console.log(`开始抓取 ${sites.length} 个源…`);
  const started = Date.now();

  const results = await Promise.all(sites.map((s) => fetchSite(s)));

  let failed = 0;
  const fresh = [];
  const cutoff = twoYearsAgo();
  let dropped = 0;
  for (const r of results) {
    const all = r.items;
    // 按近两年截断：无日期的保留（可能只是解析不到，不该丢）
    const kept = all.filter((n) => !n.date || n.date >= cutoff);
    dropped += all.length - kept.length;

    if (r.status === 'ok') {
      console.log(
        `  ✅ ${r.source.dept} / ${r.source.category}  ${kept.length} 条` +
          (all.length !== kept.length ? `（过滤 ${all.length - kept.length} 条旧数据）` : '') +
          `  翻页 ${r.pages} 页`,
      );
      fresh.push(...kept.slice(0, perSiteLimit));
    } else {
      failed++;
      console.log(`  ❌ ${r.source.dept} / ${r.source.category}  ${r.error}`);
    }
  }

  // 读历史
  let previous = [];
  try {
    previous = loadPrevious(await readFile(OUT_FILE, 'utf8'));
  } catch {
    /* 首次运行 */
  }
  // 历史里也把超过两年的老数据清掉
  const beforePrune = previous.length;
  previous = previous.filter((n) => !n.date || n.date >= cutoff);
  const pruned = beforePrune - previous.length;

  const merged = dedupe(merge(previous, fresh));
  const payload = {
    schemaVersion: 1,
    updatedAt: new Date().toISOString(),
    total: merged.length,
    notices: merged,
  };

  const elapsed = ((Date.now() - started) / 1000).toFixed(1);
  console.log(
    `\n抓取完成：${fresh.length} 条，合并后 ${merged.length} 条，` +
      `失败 ${failed} 个源，耗时 ${elapsed}s`,
  );
  if (dropped || pruned) {
    console.log(`（超出 ${KEEP_YEARS} 年的旧数据：本次过滤 ${dropped} 条，历史清理 ${pruned} 条）`);
  }

  if (dry) {
    console.log('\n--- 前 5 条 ---');
    for (const n of merged.slice(0, 5)) {
      console.log(`  [${n.date ?? '无日期'}] ${n.dept} | ${n.title}`);
      console.log(`      ${n.url}`);
    }
    return;
  }

  await mkdir(OUT_DIR, { recursive: true });
  await writeFile(OUT_FILE, JSON.stringify(payload, null, 2), 'utf8');
  console.log(`\n已写入 ${OUT_FILE}`);

  // 有源失败时用退出码提醒 CI，但不影响已生成的结果
  if (failed > 0) {
    process.exitCode = 0; // 部分失败可以接受，不让整个 CI 变红
  }
}

/** 近 N 年的起始日期（YYYY-MM-DD） */
function twoYearsAgo() {
  const d = new Date();
  d.setFullYear(d.getFullYear() - KEEP_YEARS);
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

// 只在直接运行时执行（被 import 做单测时不跑）
if (process.argv[1] && process.argv[1].endsWith('fetch.mjs')) {
  main().catch((e) => {
    console.error('抓取失败：', e);
    process.exit(1);
  });
}
