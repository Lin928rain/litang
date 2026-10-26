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

Swift Cookie 范围测试已写入 RunnerTests，并接入工作流；本地 Windows 不具备 Apple SDK。

## 云端构建

- 已创建公开 fork [Lin928rain/litang](https://github.com/Lin928rain/litang)，迁移分支推送到该仓库，未向上游 extrisha/litang 写入。
- 第一轮构建发现原有 `.gitignore` 中一行注释不是 UTF-8，已规范为 UTF-8 注释，忽略规则保持一致；另检查了 210 个源码和配置文件的编码。
- [第二轮构建](https://github.com/Lin928rain/litang/actions/runs/40259844438)已成功，应用源码 commit `95bdd76f6fd4c0b345f7ad75f08cb621a917e37e`：云端依赖安装、静态检查、171 项 Dart/Widget 测试、iOS 真机 Release 编译、IPA 包装及 3 项原生 Cookie 测试全部通过。
- 原生测试在 iPhone 16 Pro 模拟器完成，覆盖域名隔离、Cookie 路径边界、有效期及 Secure 属性。这不等于真实学校账号或真实手机安装已验证。
- 固定版本的 `flutter_secure_storage` 9.2.4 尚未支持 Swift Package Manager，Flutter 自动使用 CocoaPods 兼容路径，当前固定工具链已验证构建成功。

## 已导出的 IPA

- 文件：`litang-ios-0.4.2-16-unsigned.ipa`，9,745,551 字节（约 9.3 MiB）。
- [GitHub 构建产物](https://github.com/Lin928rain/litang/actions/runs/40259844438/artifacts/12624263741)：登录 GitHub 后下载 ZIP 并解压得到 IPA、SHA-256 和构建元信息，保留期 14 天。
- 本地文件：`build/ios-downloads/40259844438/litang-ios-0.4.2-16-unsigned.ipa`。
- 最低系统：iOS 15.0；平台：iPhoneOS；架构：arm64；Bundle ID：`io.github.extrisha.litang`。
- SHA-256：`ca76a269af6dd9531632a8db6551b3e6009fb9d7dee96f57230b7f51706e5e8b`。
- 下载后已核对 SHA-256 与云端元信息一致、ZIP CRC、Payload 目录、应用 Info.plist、主程序及两个 Flutter Framework 的 Mach-O 架构，确认没有根应用签名或 embedded.mobileprovision。
- 本地校验记录：`build/ios-downloads/40259844438/verification.json`；完整编译及测试日志：`build/ios-logs/40259844438/`。

## 待完成

- [x] 选择有写权限的 GitHub 构建仓库并推送迁移分支：Lin928rain/litang。
- [x] 云端依赖安装、Swift 编译、真机 Release 构建和原生模拟器测试。
- [x] 下载首个成功的未签名 IPA，验证结构和元信息。
- [ ] 用户在 Windows 配好 AltServer/AltStore，并在 iPhone 完成首次个人签名安装。
- [ ] 真机验证教务、学习通、一网畅学、Keychain、扫码、定位、附件、视频与通知。
- [ ] 验证同账号覆盖升级及一次免费签名刷新。
- [ ] 更换或确认 iOS 图标：当前仍使用仓库原有 AppIcon 资源，尚未完成品牌图标验收。
- [ ] Android 原生构建与手机回归；目前仅共享 Dart 代码的静态检查和自动化测试通过。

云端构建、原生模拟器测试和 IPA 下载校验已通过。IPA 仍需用户的免费 Apple Account 重签后安装，真实 iPhone 安装、学校账号功能及续签验收尚未完成。
