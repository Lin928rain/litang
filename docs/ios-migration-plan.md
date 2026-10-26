# 理堂 iOS 迁移与 IPA 导出计划

更新日期：2026-10-26。状态：已开始代码迁移，实际验证进度见 `ios-migration-status.md`。

## 目标与已确认条件

- 开发电脑为 Windows，没有自有 Mac，也没有付费 Apple Developer Program 账号。
- 保留 Flutter 单仓库，迁移现有主要功能到 iPhone，兼顾 Android 回归。
- 第一版以免费、自用为目标；不把 TestFlight、App Store 上架作为交付前提。
- 最终交付可重复构建的真机 Release IPA，以及 Windows 签名、安装、续签说明；以真实 iPhone 安装运行通过作为验收依据。
- 暂沿用工程的 iOS 15.0 最低版本；最终最低版本须由锁定的 Flutter、插件和实际安装工具共同确认。

## 无 Mac 的主路线

Windows 修改代码 → GitHub 仓库 → GitHub Actions macOS runner / Xcode → 真机 Release .app → 包装为未签名 IPA → 下载到本地 → AltServer / AltStore Classic 使用用户自己的免费 Apple Account 重签并安装 → iPhone 自用。

iOS 编译仍然发生在 macOS 上，使用的是 GitHub 提供的云端机器。GitHub 标准托管 runner 在公开仓库可免费使用；私有仓库受账号额度及计费约束，执行前检查仓库可见性与用量。[GitHub 官方说明](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)

需要明确区分三个产物：

| 产物 | 用途 |
| --- | --- |
| 模拟器 .app | 云端模拟器验证界面，不能装到 iPhone |
| 未签名的真机 Release IPA | 本计划的 CI 下载产物，须经过个人签名才能安装 |
| 免费账号签名后的应用 | 安装到用户自己的 iPhone，受免费签名有效期约束 |

免费 Personal Team 的描述文件有效期为 7 天，每台设备最多安装 3 个此类应用。采用 Windows 安装的 AltStore Classic 时，AltStore 本身也占用一个名额。续签不需要每次重新编译理堂，但需要成功刷新签名。[Apple 账号限制](https://developer.apple.com/help/account/basics/about-your-developer-account)、[AltStore 使用说明](https://faq.altstore.io/altstore-classic/your-altstore)

AltStore 通过同一 Wi-Fi 下运行的 AltServer 或 USB 连接刷新应用。第一版先验证手动刷新，再配置方便的续签方式，不以后台刷新一定成功为前提。[AltServer 官方说明](https://faq.altstore.io/altstore-classic/altserver)

## 阶段 0：先确认安装路线，约半天至 1 天

1. 确认用户实际 iPhone 型号、iOS 版本，以及免费应用名额是否足够。
2. 在 Windows 按官方指南安装 AltServer 及所需 Apple 组件；USB 连接并信任 iPhone，在手机上完成所需信任及开发者模式设置。iOS 16 及以上按工具要求开启开发者模式。[Windows 安装指南](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
3. 用普通 Apple Account 完成 AltStore 安装和一次刷新；账号密码只在本地安装工具的授权流程输入，不进入源码、GitHub Secrets、构建日志或聊天。
4. 记录实际安装工具版本、iOS 版本及错误信息，作为后续验收环境。

验收：AltStore 能在用户手机打开且刷新成功。若这一前提不成立，先解决安装环境；应用源码迁移可独立推进。

备用路线是 SideStore：先在 Windows 完成初始安装，之后按其官方流程在手机上通过 Wi-Fi 与所需本地 VPN 刷新。它同样需要免费签名续期，应先核实目标系统兼容性，再作为主路线的替代。[SideStore 前置条件](https://docs.sidestore.io/docs/installation/prerequisites)

## 阶段 1：建立最小云构建，约 1 至 2 天

拟新增 `.github/workflows/build-ios.yml` 和 `tools/ios/package-unsigned-ipa.sh`。

- 初期使用手动触发，并在迁移分支迭代；不自动发布 Release 或分发安装包。
- 锁定通过验证的 macOS runner、Xcode、Flutter 版本，打印版本信息方便复现。当前 pubspec 要求 Dart ^3.13.5，lockfile 要求 Flutter >=3.47.0，不可直接套用旧 Flutter CI 示例。
- 使用提交的 pubspec.lock 安装依赖，执行静态检查、现有单元测试和 Widget 测试，记录已有失败与新引入失败。
- iOS 工程已经引用 FlutterGeneratedPluginSwiftPackage，先验证现有 Swift Package Manager 集成。若个别插件需要 CocoaPods，再配置兼容路径；缺少 Podfile 本身不能判定为工程错误。
- 运行真机 Release 构建；先获取现有项目的首轮编译结果，按编译日志修复 Swift、插件或工程问题。

计划使用的构建命令（运行于云端 macOS）：

```sh
flutter pub get
flutter analyze
flutter test
flutter build ios --release --no-codesign
```

包装脚本把 `build/ios/iphoneos/Runner.app` 放入 ZIP 根目录的 `Payload/Runner.app`，保留应用包结构及文件属性，输出 `litang-ios-<version>-<build>-unsigned.ipa`，附 SHA-256、源码 commit、工具链版本和编译日志。

不要把 `flutter build ipa --no-codesign` 当作自动生成可安装 IPA 的命令。Flutter 的无签名归档路径会跳过 IPA 导出，本计划明确增加 .app 包装步骤。[Flutter 构建工具源码](https://github.com/flutter/flutter/blob/master/packages/flutter_tools/lib/src/commands/build_ios.dart)

验收：首次未签名真机 IPA 可下载；通过 AltStore 重签并安装，至少可进入首页。CI 绿色和 ZIP 生成均不能替代真机验收。此时不要求所有功能已完成适配。

## 阶段 2：补齐基础 iOS 配置，约 1 天

涉及 `ios/Runner/Info.plist`、`ios/Runner.xcodeproj/project.pbxproj`、图标资源与必要的原生配置。

- 应用显示名称改为“理堂”，确认一个稳定的唯一 Bundle ID；具体值在实施时确定，后续升级维持身份一致。
- 添加相机、照片选择、前台定位用途说明；只有引入录音/视频拍摄时才添加麦克风声明。
- 核对所有插件实际最低 iOS 版本、SPM/CocoaPods 集成和所需权限；审核依赖自带的隐私清单及应用自身是否需要补充声明。
- 验证图片、文件选择、PDF 预览、外部文件打开、视频播放和地图显示。
- 验证学校登录和 WebView 跳转链。优先 HTTPS；如确有 ATS 阻拦，按具体域名和请求栈处理，不默认全局放开网络限制。

验收：首次启动无权限相关崩溃；相机、相册及定位在首次授权、拒绝和恢复授权后均有合理反馈。

## 阶段 3：补 iOS Cookie 桥接并验证会话，约 2 至 3 天

核心文件：`ios/Runner/AppDelegate.swift`、拟新增 `ios/Runner/WebCookieBridge.swift`、`lib/data/chaoxing/web_cookie_bridge.dart`，以及必要的 Cookie 注入逻辑。

- 当前 `litang/web_cookies` 的 read/clear 仅有 Android 实现；iOS 页面虽允许打开，但缺少读取 HttpOnly 会话的原生通道。
- 沿用现有 Dart 通道约定，使用 WKWebView 实际使用的数据存储中的 Cookie Store 读取并清除对应会话；确认原生通道绑定到当前 Flutter engine，适配现有 SceneDelegate / implicit engine 生命周期。
- Cookie 按目标 URL 的域、路径与有效期筛选，验证 HttpOnly Cookie、跨子域注入、退出和换账号，不依赖 document.cookie 获取 HttpOnly 会话。
- 先保留现有 webview_flutter，避免同时引入 WebView 全面替换；仅当实际兼容问题需要时再评估更换。
- 教务和一网畅学主要登录逻辑属于 Dart 网络层，复用现有实现，分别验证 CAS 重定向、接口会话和网页登录。
- 真机验证 Keychain 写入、关闭重启后恢复，以及免费工具重签/覆盖升级后读取是否正常。若权限或应用身份导致失败，修复签名或存储配置，不改为明文保存凭据。

验收：学习通网页登录后可以进入课程列表；关闭重开能恢复登录；退出与换号能清除旧会话；教务课表、成绩、一网畅学待办均能读取。

## 阶段 4：提醒与更新适配，约 1 至 2 天

涉及 `lib/services/reminder_service.dart`、`lib/services/update_service.dart`、启动更新检查、我的页面更新入口及必要的原生通知配置。

- 补齐 iOS 通知授权流程。当前 Darwin 初始化关闭权限申请，后续代码仅申请 Android 权限。
- 检查 iOS 通知代理和点击回调；测试前台、后台、应用被系统结束后已排定通知的送达及跳转。
- 处理待通知数量上限：插件文档注明 iOS 仅保留有限数量的待通知，应合并两个来源并按时间优先排最近任务，保留余量，避免后同步的任务挤掉更近提醒。[通知插件文档](https://pub.dev/packages/flutter_local_notifications)
- 保持“打开应用后拉取新作业并预排提醒”的现有模型，不把它描述为应用关闭后持续获取新作业。
- iOS 不运行 APK 下载/安装路径，也不受 Android 更新清单的强制升级逻辑阻塞。自用版展示版本信息及 IPA 获取入口，升级由 AltStore 重签覆盖安装完成。

验收：短时间测试提醒能送达并打开正确任务；拒绝通知授权后主功能仍可用；iOS 启动不会出现 APK 更新弹窗。

## 阶段 5：真机回归与稳定产物，约 2 至 3 天

| 范围 | 必测内容 |
| --- | --- |
| 登录与存储 | 教务、学习通、一网畅学；重启恢复、退出换号；重签覆盖升级后的 Keychain 和缓存 |
| 校园功能 | 通知、地图手势、校历、课表、成绩、排名、培养计划 |
| 学习功能 | 课程详情、作业列表、附件选择、PDF、视频及请求头兼容性 |
| 设备能力 | 扫码识别、定位及拒绝权限；只在用户参与的合法课堂场景验证签到提交 |
| 提醒 | 授权、前后台、点击冷启动、取消已完成任务、多来源合并调度 |
| 安装与升级 | 免费签名首次安装、同身份覆盖更新、手动刷新续签，后续观察实际有效期周期 |
| Android 回归 | 共享代码改动后的测试、Android 构建与主要登录/提醒/更新功能 |

云端模拟器负责无账号的界面和启动检查；相机、真实定位、学校账号和签名续期需要用户的 iPhone 配合。学校账号和真实会话不放入公开 CI。

验收后固定工具链，保存一个稳定版本的工作流、包装脚本、测试记录和产物元信息。拟新增 `docs/ios-install-windows.md`，写明从 GitHub Actions 下载 artifact ZIP、解压获得 IPA、导入 AltStore、升级及续签的完整步骤。

## 成本、排期和完成条件

目标成本为：不购买 Mac、不购买开发者会员。公开仓库的标准 GitHub runner 编译按官方规则可免费使用；私有仓库或额外存储超额不承诺免费。AltStore Classic 使用免费账号自用，承担每 7 天续签和应用名额限制。

预估总投入约 8 至 12 个工作日，预留工具链、学校登录、签名兼容问题后按 2 至 3 周安排；这是规划估算，首轮云构建和真机安装后校准，不包含等待用户设备操作的时间。

完成必须同时满足：

1. 能从指定源码 commit 重复构建真机 Release IPA，产物明确标为未签名。
2. 用户无需 Mac 或付费会员，能在 Windows 完成个人签名、安装、覆盖升级和一次续签验证。
3. 主要校园与学习功能通过真机回归，未通过项有明确记录。
4. iOS 不执行 APK 更新路径；Android 主要功能无回归。
5. 保留构建、安装、续签说明与工具链版本；不声称免费 IPA 可以永久免续签或直接点开安装。

未来若需要 TestFlight 或 App Store 分发，可继续使用同一云构建方案，另配置付费开发者账号、证书/描述文件或 API 集成；Codemagic 可作为减少签名维护工作的候选，而不是本次免费路线的必要服务。[Flutter iOS 发布说明](https://docs.flutter.dev/deployment/ios)、[Codemagic 签名说明](https://docs.codemagic.io/yaml-code-signing/signing-ios/)
