# 通知抓取（服务端）

把各学院站点的通知列表抓成一个统一的 `notices.json`，App 只拉这个文件，
不再让每台设备各自去爬学校站点。

## 目录

```
tools/notice-sync/
├── sources.json        # 抓取源配置（加源只改这里）
├── fetch.mjs           # 抓取 + 解析 + 合并历史
├── fetch.test.mjs      # 解析器单测（5 种实测模板）
├── debug.mjs           # 排查用：打印站点真实结构（随时可删）
└── out/notices.json    # 产物（CI 自动提交）
```

## 本地运行

```bash
# 只预览不写文件
node tools/notice-sync/fetch.mjs --dry

# 正式抓取并写入 out/notices.json
node tools/notice-sync/fetch.mjs

# 跑解析器单测
node --test tools/notice-sync/fetch.test.mjs
```

## 自动化

`.github/workflows/sync-notices.yml`：每天 3 次定时抓取，跑完自动提交
`out/notices.json`；如果配置了 `GITEE_TOKEN` secret，还会顺带同步到 Gitee。

## 数据结构

```json
{
  "schemaVersion": 1,
  "updatedAt": "2026-10-25T11:54:57.323Z",
  "total": 154,
  "notices": [
    {
      "id": "ndxy:https://ndxy.usst.edu.cn/2026/1025/c14380a372908/page.htm",
      "dept": "能源与动力工程学院",
      "category": "新闻动态",
      "scope": "college",
      "title": "能动学院师生应邀参观第十三届中国（上海）国际流体机械展",
      "url": "https://ndxy.usst.edu.cn/2026/1025/c14380a372908/page.htm",
      "date": "2026-10-25"
    }
  ]
}
```

| 字段 | 说明 |
|---|---|
| `id` | `源ID:url`，也是跨次抓取的唯一键（用于合并历史） |
| `dept` | 发布部门 / 学院 |
| `category` | 栏目名（通知公告 / 科研通知 / 新闻动态…） |
| `scope` | `school` 全校级 / `college` 学院级，用于「本院优先」排序 |
| `date` | `YYYY-MM-DD`，解析不出时为 `null` |

## 维护

- **加一个源**：往 `sources.json` 的 `sites` 里加一条即可，不用改代码。
- **学院改版**：先跑 `node tools/notice-sync/debug.mjs` 看新结构，
  再在 `fetch.test.mjs` 里补一个该结构的 fixture，最后调 `parseList`。
- **历史**：每次抓取都会和 `out/notices.json` 里已有的数据合并，按 `id` 去重，
  最多保留 800 条，老通知不会因为翻页消失。

## 已知情况

| 站点 | 状态 |
|---|---|
| 中德国际学院 | 首页可达但导航里没有独立通知栏目，暂未接入 |
| 中英国际学院 | 站点返回 502 / 不可达，暂未接入 |
| 机械工程学院 | 公告公示栏目内容较少（约 4 条） |
