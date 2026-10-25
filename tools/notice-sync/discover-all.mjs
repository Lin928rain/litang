// 批量栏目发现：对 sites.json 里全部 USST 站点跑 discover，结果存到 discovery/
//
// 踩过的坑（都体现在代码里）：
//  1. 学院站点几乎每页侧栏都会挂一块「学院新闻」，导致每个列表页都出现同一个 cid 的文章。
//     如果按「出现最多的 cid」判断栏目 id，所有栏目会塌缩成一个 —— 所以先统计
//     跨页面高频出现的 cid（侧栏 cid）并剔除，再判断本页栏目 id。
//  2. 「首页孤儿栏目」不是真的没有列表页：首页直接链文章、不给「更多」链接而已，
//     探一下 /<cid>/list.htm 基本都能出来。
//  3. 栏目名以列表页 <title> 为准，「更多」「下一页」这类链接文字不作数。
//  4. 学院首页里指向 www.usst.edu.cn 的「学校要闻」不算本栏目文章（主站由 www 自己抓）。
//
// 用法：
//   node discover-all.mjs                 # 全部站点，写入 discovery/
//   node discover-all.mjs me jcxb         # 只跑指定 host
//   node discover-all.mjs --concurrency 6

import { writeFile, mkdir, readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT = join(__dirname, 'discovery');

const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
  '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

const args = process.argv.slice(2);
const ci = args.indexOf('--concurrency');
const CONCURRENCY = ci >= 0 ? Math.max(1, Number(args[ci + 1]) || 5) : 5;
const only = args.filter((a) => !a.startsWith('--') && a !== args[ci + 1]);

const registry = JSON.parse(await readFile(join(__dirname, 'sites.json'), 'utf8'));
const sites = registry.sites.filter((s) => only.length === 0 || only.includes(s.host));

async function get(url, timeout = 20000) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeout);
  try {
    const r = await fetch(url, {
      headers: { 'User-Agent': UA, Accept: 'text/html,*/*' },
      redirect: 'follow',
      signal: ctrl.signal,
    });
    if (r.status !== 200) return null;
    return Buffer.from(await r.arrayBuffer()).toString('utf8');
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

// ---------------------------------------------------------------- 解析

/** 页面里所有文章链接 → Map<path, {cid, date, host}> */
function analyzeArticles(html, baseUrl) {
  const base = new URL(baseUrl);
  const articles = new Map();
  const re = /href=["']([^"']*\/20(\d{2})\/(\d{2})(\d{2})\/c(\d+)a(\d+)[^"']*)["']/g;
  let m;
  while ((m = re.exec(html))) {
    let abs;
    try {
      abs = new URL(m[1], base);
    } catch {
      continue;
    }
    const date = `20${m[2]}-${m[3]}-${m[4]}`;
    const prev = articles.get(abs.pathname);
    if (!prev || date > prev.date) {
      articles.set(abs.pathname, { cid: m[5], date, host: abs.host });
    }
  }
  return articles;
}

function extractColumns(html, baseUrl, host) {
  const cols = new Map();
  const re =
    /href=["']([^"']*(?:list\.(?:htm|psp)|list\d+\.(?:htm|psp)))["'][^>]*>([\s\S]{0,80}?)<\/a>/g;
  let m;
  while ((m = re.exec(html))) {
    const text = m[2]
      .replace(/<[^>]+>/g, '')
      .replace(/&gt;/g, '>')
      .replace(/&nbsp;/g, '')
      .replace(/\s+/g, '')
      .trim();
    let abs;
    try {
      abs = new URL(m[1], baseUrl);
    } catch {
      continue;
    }
    if (abs.host !== host) continue;
    abs.protocol = 'https:';
    const key = abs.toString();
    if (!cols.has(key)) cols.set(key, text);
  }
  return cols;
}

const JUNK_NAME =
  /^(更多|下一页|上一页|尾页|末页|首页|English|MORE|more|提示信息|上海理工大学|上海理工|404|无|返回)?[>»·]*$/;

function cleanName(s) {
  return (s || '')
    .replace(/&gt;/g, '>')
    .replace(/&nbsp;/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/^[>»·\s]+/, '')
    .replace(/[>»\s]+$/, '');
}

function goodName(s) {
  if (!s) return false;
  if (s.length < 2 || s.length > 24) return false;
  if (JUNK_NAME.test(s)) return false;
  if (/上海理工大学|usst\.edu\.cn/i.test(s)) return false;
  return true;
}

function nameFromTitle(t) {
  for (const part of cleanName(t).split(/[-_|–—]/)) {
    const s = part.trim();
    if (goodName(s)) return s;
  }
  return '';
}

function nameFromHtml(html) {
  const pats = [
    /<h2[^>]*class="[^"]*(?:listDetailsTitle|col_title)[^"]*"[^>]*>([\s\S]{0,60}?)<\/h2>/,
    /<div[^>]*class="[^"]*(?:col_title|columnTitle|lanmu)[^"]*"[^>]*>([\s\S]{0,60}?)<\/div>/,
    /class="[^"]*bread[^"]*"[^>]*>([\s\S]{0,200}?)<\/div>/i,
  ];
  for (const p of pats) {
    const m = html.match(p);
    if (!m) continue;
    const texts = [...m[1].matchAll(/>([^<>]{2,24})</g)].map((x) => cleanName(x[1]));
    for (const t of texts.reverse()) if (goodName(t)) return t;
  }
  return '';
}

/** 分析一个已下载的列表页 */
function pageInfo(url, html, host) {
  const all = analyzeArticles(html, url);
  const same = new Map([...all].filter(([, v]) => v.host === host));
  const counts = new Map();
  for (const v of same.values()) counts.set(v.cid, (counts.get(v.cid) ?? 0) + 1);
  const tm = html.match(/<title>([^<]*)<\/title>/i);
  return {
    url,
    html,
    arts: same,
    counts,
    pageTitle: tm ? cleanName(tm[1]) : '',
    htmlName: nameFromHtml(html),
    hasPaging: /href=["'][^"']*list\d+\.(?:htm|psp)["']/i.test(html),
  };
}

const isPagingUrl = (u) => /\/list\d+\.(?:htm|psp)$/i.test(u);

/**
 * 找出侧栏 cid：在大量不同列表页里都出现的 cid（每页都挂「学院新闻」）
 * @param pages 页面数组
 */
function sidebarCids(pages) {
  const hit = new Map();
  for (const p of pages) for (const cid of p.counts.keys()) hit.set(cid, (hit.get(cid) ?? 0) + 1);
  const n = pages.length;
  const threshold = Math.max(4, Math.ceil(n * 0.45));
  return new Set([...hit].filter(([, c]) => c >= threshold).map(([cid]) => cid));
}

/** 去掉侧栏 cid 后，本页最主要的栏目 cid */
function pickCid(p, side) {
  const rest = [...p.counts].filter(([cid]) => !side.has(cid));
  if (rest.length === 0) {
    const dir = p.url.match(/\/(\d{3,6})\/list/);
    return dir ? dir[1] : [...p.counts].sort((a, b) => b[1] - a[1])[0]?.[0] ?? null;
  }
  rest.sort((a, b) => b[1] - a[1]);
  // 同名量时优先 URL 目录里那个 cid
  const dir = p.url.match(/\/(\d{3,6})\/list/);
  if (dir) {
    const hit = rest.find(([cid]) => cid === dir[1]);
    if (hit) return hit[0];
  }
  return rest[0][0];
}

// ---------------------------------------------------------------- 站点发现

async function discover(site) {
  const home = new URL(site.url);
  const host = home.host;
  const homeHtml = await get(site.url);
  if (!homeHtml) return { ...site, error: 'unreachable' };

  const homeAll = analyzeArticles(homeHtml, site.url);
  const homeArts = new Map([...homeAll].filter(([, v]) => v.host === host));
  const homeCols = extractColumns(homeHtml, site.url, host);

  /** @type {Map<string,{text:string,via:string}>} */
  const cands = new Map();
  for (const [u, t] of homeCols) cands.set(u, { text: t, via: 'home' });
  // 有些栏目的入口是 JS 渲染的（主站导航就是这样），首页抓不到链接，用 seeds 手工补
  for (const u of site.seeds ?? []) cands.set(u, { text: '', via: 'seed' });

  // ---- 第一轮：首页栏目页
  const pages = [];
  for (const [url, meta] of cands) {
    const html = await get(url);
    if (!html) continue;
    const info = pageInfo(url, html, host);
    if (info.arts.size === 0) continue;
    info.linkText = meta.text;
    info.via = meta.via;
    pages.push(info);
  }

  const side1 = sidebarCids(pages);

  // ---- 孤儿栏目：首页文章 cid 没有任何页面对应
  const covered1 = new Set(pages.map((p) => pickCid(p, side1)));
  const seen = new Set();
  for (const [, v] of homeArts) {
    if (covered1.has(v.cid) || seen.has(v.cid)) continue;
    seen.add(v.cid);
    for (const suffix of ['list.htm', 'list.psp']) {
      const u = `https://${host}/${v.cid}/${suffix}`;
      const html = await get(u);
      if (!html) continue;
      const info = pageInfo(u, html, host);
      if (info.arts.size && pickCid(info, side1) === v.cid) {
        info.linkText = '';
        info.via = 'orphan';
        pages.push(info);
        break;
      }
    }
  }

  // ---- 第二轮：从已发现页面里再挖栏目
  const known = new Set([site.url, ...cands.keys()]);
  const level2 = new Map();
  for (const p of pages.slice(0, 60)) {
    for (const [u, t] of extractColumns(p.html, p.url, host)) {
      if (known.has(u) || level2.has(u) || isPagingUrl(u)) continue;
      level2.set(u, t);
    }
  }
  for (const [url, text] of level2) {
    const html = await get(url);
    if (!html) continue;
    const info = pageInfo(url, html, host);
    if (info.arts.size === 0) continue;
    info.linkText = text;
    info.via = 'depth2';
    pages.push(info);
  }

  // ---- 用全部页面重新判定侧栏，再落定每个页面的栏目 cid
  const side = pages.length >= 5 ? sidebarCids(pages) : new Set();
  const byCid = new Map();
  for (const p of pages) {
    const cid = pickCid(p, side);
    if (!cid) continue;
    if (isPagingUrl(p.url) && !byCid.has(cid)) continue;
    // 只统计本栏目文章（排除侧栏、排除串进来的别的栏目）
    const arts = [...p.arts.entries()].filter(([, v]) => v.cid === cid);
    if (arts.length === 0) continue;
    const dates = arts.map(([, v]) => v.date).sort();
    const col = {
      url: p.url,
      cid,
      name:
        nameFromTitle(p.pageTitle) ||
        p.htmlName ||
        (goodName(cleanName(p.linkText)) ? cleanName(p.linkText) : '') ||
        `栏目${cid}`,
      linkText: goodName(cleanName(p.linkText)) ? cleanName(p.linkText) : '',
      articles: arts.length,
      latest: dates[dates.length - 1],
      oldest: dates[0],
      hasPaging: p.hasPaging,
      foundVia: p.via,
    };
    const cur = byCid.get(cid);
    if (!cur) {
      byCid.set(cid, col);
      continue;
    }
    const better =
      (col.oldest ?? '9999') < (cur.oldest ?? '9999') || col.articles > cur.articles;
    if (better) byCid.set(cid, { ...col, url: cur.url, name: cur.name !== `栏目${cid}` ? cur.name : col.name });
  }

  const columns = [...byCid.values()].sort((a, b) =>
    (b.latest ?? '').localeCompare(a.latest ?? ''),
  );

  const covered = new Set(byCid.keys());
  const unresolved = [];
  for (const [path, v] of homeArts) {
    if (covered.has(v.cid)) continue;
    if (!unresolved.some((o) => o.cid === v.cid)) {
      unresolved.push({ cid: v.cid, sample: path, date: v.date });
    }
  }

  return {
    dept: site.dept,
    host: site.host,
    group: site.group,
    home: site.url,
    homeArticles: homeArts.size,
    pagesProbed: pages.length,
    columns,
    unresolvedCids: unresolved,
  };
}

// ---------------------------------------------------------------- 运行

await mkdir(OUT, { recursive: true });
const summary = [];
let idx = 0;

async function worker() {
  while (idx < sites.length) {
    const site = sites[idx++];
    const t0 = Date.now();
    process.stdout.write(`\n[${site.dept}] ${site.url}\n`);
    let r;
    try {
      r = await discover(site);
    } catch (e) {
      r = { ...site, error: `crash: ${e.message}` };
    }
    r.elapsedMs = Date.now() - t0;
    await writeFile(join(OUT, `${site.host}.json`), JSON.stringify(r, null, 2), 'utf8');
    if (r.error) {
      console.log(`  ❌ ${r.error}`);
      summary.push({ dept: site.dept, host: site.host, error: r.error });
    } else {
      const active = r.columns.filter((c) => (c.latest ?? '') >= '2026-01-01');
      console.log(
        `  栏目 ${r.columns.length}（2026 年活跃 ${active.length}），` +
          `页面 ${r.pagesProbed}，未解析 cid ${r.unresolvedCids.length}，` +
          `用时 ${(r.elapsedMs / 1000).toFixed(0)}s`,
      );
      summary.push({
        dept: site.dept,
        host: site.host,
        group: site.group,
        columns: r.columns.length,
        active: active.length,
        unresolved: r.unresolvedCids.length,
        elapsedMs: r.elapsedMs,
      });
    }
  }
}

await Promise.all(Array.from({ length: CONCURRENCY }, worker));

summary.sort((a, b) => (b.active ?? -1) - (a.active ?? -1));
await writeFile(join(OUT, '_summary.json'), JSON.stringify(summary, null, 2));

console.log('\n=== 汇总 ===');
let totalCols = 0;
let totalActive = 0;
for (const s of summary) {
  totalCols += s.columns ?? 0;
  totalActive += s.active ?? 0;
  console.log(
    `${(s.dept ?? '').padEnd(16)} 栏目=${String(s.columns ?? '-').padStart(4)} ` +
      `活跃=${String(s.active ?? '-').padStart(4)} 未解析=${String(s.unresolved ?? '-').padStart(2)} ${s.error ?? ''}`,
  );
}
console.log(`\n合计：栏目 ${totalCols} 个，2026 年活跃 ${totalActive} 个`);
