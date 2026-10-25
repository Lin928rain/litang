// 看一眼 out/notices.json 的分布，确认抓取没跑偏
//
// 用法：node check-stats.mjs [--dept 教研室] [--days 30]

import { readFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const raw = await readFile(join(__dirname, 'out', 'notices.json'), 'utf8');
const data = JSON.parse(raw);
const notices = data.notices ?? data;

const args = process.argv.slice(2);
const di = args.indexOf('--dept');
const onlyDept = di >= 0 ? args[di + 1] : null;
const days = Number(args[args.indexOf('--days') + 1]) || 30;

const list = onlyDept ? notices.filter((n) => n.dept?.includes(onlyDept)) : notices;

const count = (arr, key) => {
  const m = new Map();
  for (const n of arr) m.set(key(n), (m.get(key(n)) ?? 0) + 1);
  return [...m].sort((a, b) => b[1] - a[1]);
};

console.log(`总计 ${list.length} 条，更新于 ${data.updatedAt ?? '-'}`);
console.log(`体积 ${(raw.length / 1024 / 1024).toFixed(2)} MB`);

const noDate = list.filter((n) => !n.date).length;
console.log(`无日期 ${noDate} 条（${((noDate / list.length) * 100).toFixed(1)}%）`);

console.log('\n按分类：');
for (const [k, c] of count(list, (n) => n.kind ?? '-')) console.log(`  ${String(k).padEnd(4)} ${String(c).padStart(5)}`);

console.log('\n按年份：');
for (const [k, c] of count(list, (n) => (n.date ?? '?').slice(0, 4)).sort()) console.log(`  ${k} ${String(c).padStart(5)}`);

console.log(`\n按部门（前 15）：`);
for (const [k, c] of count(list, (n) => n.dept ?? '-').slice(0, 15)) console.log(`  ${String(k).padEnd(14)} ${String(c).padStart(5)}`);

// 近 N 天各分类的新增量：能看出哪些源其实没在更新
const since = new Date(Date.now() - days * 864e5).toISOString().slice(0, 10);
const recent = list.filter((n) => (n.date ?? '') >= since);
console.log(`\n近 ${days} 天新增 ${recent.length} 条，按分类：`);
for (const [k, c] of count(recent, (n) => n.kind ?? '-')) console.log(`  ${String(k).padEnd(4)} ${String(c).padStart(5)}`);
console.log(`近 ${days} 天活跃部门 ${new Set(recent.map((n) => n.dept)).size} 个`);

console.log('\n最新 10 条：');
for (const n of list.slice(0, 10)) {
  console.log(`  ${n.date ?? '无日期'}  [${n.kind}] ${n.dept}  ${n.title.slice(0, 40)}`);
}
