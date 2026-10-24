# 理堂

上海理工大学校园助手，Flutter 客户端。

## 功能

- 教务 CAS 登录 / 静默续期
- 本周课表（按教学周过滤）
- 成绩总览（含分项成绩）
- 学业情况 / 培养方案课程树
- 专业排名（PDF 解析）
- 一网畅学：待办、考试安排、签到雷达 / 数字签到 / 扫码签到
- 校园地图：官方地图 + 楼名图层，按名称搜索、点击楼栋、双击课表定位
- 通知聚合：教务处 / 通知公告 / 健康学院
- 待办与作业详情、附件预览

## 开发

```bash
flutter pub get
flutter run
```

## 构建

```bash
flutter build apk --release --target-platform android-arm64
```

产物：`build/app/outputs/flutter-apk/app-release.apk`

## 项目结构

```
lib/
  data/      数据抓取、解析与本地存储
  pages/     页面
  widgets/   通用组件
assets/map/  地图瓦片（底图 + 楼名层）
```

## 版本

0.1.0 beta

## 说明

个人学习项目，与上海理工大学官方无关；地图版权归学校所有，仅用于校内信息展示。
