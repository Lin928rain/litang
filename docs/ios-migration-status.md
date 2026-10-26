# iOS 迁移状态

更新日期：2026-10-26。迁移分支：`codex/ios-migration`。

## 已实现

- GitHub Actions 无签名真机 Release 构建，固定 Flutter 3.47.7 / Dart 3.13.5、macOS 15、Xcode 26.3。
- IPA 包装脚本：检查真机平台与 arm64，生成 IPA、SHA-256、源码 commit 和工具链元信息。CI 产物为未签名 IPA。
- iOS 应用名称“理堂”，Bundle ID `io.github.extrisha.litang`，相机、照片选择及前台定位用途说明。
- iOS 原生 `litang/web_cookies` 通道，连接当前 implicit Flutter engine；从默认 WKWebsiteDataStore 读取 HttpOnly Cookie，按域、路径、安全属性和有效期筛选，退出时清除对应学习通会话。
- Dart 在 iOS 使用结构化 Cookie 记录，保留 host-only/domain 和同名不同路径 Cookie；Android 继续使用原来的桥接协议。
- iOS 通知授权、原生通知代理，以及跨作业来源的持久化通知候选计划；最多提交最近的 60 条并扣除其它通知占用，减少未变化计划的重复调度。
- Android APK 清单、下载和安装逻辑与 iOS 隔离；iOS 的安装包入口可由 CI 注入实际构建仓库地址。
- Windows 安装、覆盖升级和免费账号续签指南：`ios-install-windows.md`。

## 本地验证

在 Windows 使用官方 Flutter 3.47.7 SDK（SDK 压缩包已核对官方 SHA-256）完成：

- `flutter analyze --no-pub`：通过，无问题。
- `flutter test --no-pub`：171 项测试全部通过。
- 新增/调整的测试覆盖 iOS 禁止 APK 更新、Cookie 域/路径保留，以及超过容量时按跨来源的时间顺序选择提醒、持久化恢复后补位。
- 修改通知提交去重逻辑后，相关 23 项测试再次通过。
- Bash 包装脚本语法与 Info.plist 结构检查通过。

Swift Cookie 范围测试已写入 RunnerTests，并接入工作流；需要在云端 Xcode 执行，本地 Windows 不具备 Apple SDK。

## 待完成

- [ ] 选择有写权限的 GitHub 构建仓库并推送迁移分支。当前 GitHub CLI 登录 Lin928rain，对上游 extrisha/litang 的 viewerPermission 为 READ，不能直接在上游提交或触发工作流。
- [ ] 首轮云端依赖安装、Swift 编译、真机 Release 构建和原生模拟器测试。根据日志处理实际的 SPM/CocoaPods 兼容问题。
- [ ] 下载首个成功的未签名 IPA，验证结构和元信息。
- [ ] 用户在 Windows 配好 AltServer/AltStore，并在 iPhone 完成首次个人签名安装。
- [ ] 真机验证教务、学习通、一网畅学、Keychain、扫码、定位、附件、视频与通知。
- [ ] 验证同账号覆盖升级及一次免费签名刷新。
- [ ] 更换或确认 iOS 图标：当前仍使用仓库原有 AppIcon 资源，尚未完成品牌图标验收。
- [ ] Android 原生构建与手机回归；目前仅共享 Dart 代码的静态检查和自动化测试通过。

尚未生成或验证 IPA，不将代码适配完成等同于迁移验收完成。后续构建结果和实际安装情况应更新到本文件。
