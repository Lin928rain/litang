# 在 Windows 获取、安装和续签理堂 iOS 版

本指南适用于无 Mac、无付费开发者会员的个人自用路线。代码迁移中的构建和真机验证状态见 `ios-migration-status.md`；有 IPA 文件不代表已签名，也不代表真机测试完成。

## 准备

- 一台 Windows 电脑、一部与构建最低系统版本相容的 iPhone、数据线和普通 Apple Account。
- 初版工程目标为 iOS 15.0 及以上，安装工具与实际构建的系统要求仍需一起核对。
- 按 [AltStore Classic Windows 官方指南](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)安装 AltServer 及所需的 Apple 软件组件，连接并信任 iPhone，安装 AltStore。
- iOS 16 及以上按安装流程开启“设置 → 隐私与安全性 → 开发者模式”，并完成系统要求的重启和确认。
- Apple 账号认证在本地安装工具中完成，不需要向项目维护者提供账号密码，也不需要配置 GitHub 签名 Secrets。

## 获取 IPA

1. 打开实际构建仓库的 GitHub Actions，选择 **Build iOS IPA (unsigned)** 工作流。
2. 在 `codex/ios-migration` 分支推送相关修改会触发构建；工作流进入默认分支后也可通过 **Run workflow** 手动构建。
3. 打开成功的运行记录，在 **Artifacts** 下载 `litang-ios-unsigned-<运行序号>`。下载 artifact 一般需要登录有访问权限的 GitHub 账号。
4. 解压 GitHub 提供的 artifact ZIP，得到 `litang-ios-<版本>-<构建号>-unsigned.ipa`、对应 `.sha256` 和 `build-info.json`。
5. IPA 本身保留 `.ipa` 扩展名，不要再解压它。可在 PowerShell 使用 `Get-FileHash -LiteralPath '<IPA绝对路径>' -Algorithm SHA256` 对照校验值。

工作流保存 IPA 产物 14 天；超过保留期可重新构建。该 IPA 为真机 arm64 Release 产物；模拟器 .app 不能拿来安装。

## 安装到 iPhone

1. 在 Windows 启动 AltServer，通过 USB 连接 iPhone；也可以按官方说明配置同一 Wi-Fi 下的连接。
2. 将下载的 IPA 传到 iPhone 的“文件”App，例如通过自己的网盘或文件传输工具。
3. 在 AltStore Classic 的 **My Apps** 中点 **+**，选择 IPA；首次使用时按提示完成 Apple Account 登录和所需信任操作。
4. 等待 AltStore 完成个人签名和安装后，打开“理堂”。直接在 Safari 点 IPA 文件不会自动完成签名安装。
5. 在理堂中进行教务和学习通登录。学校密码与 Cookie 不要放进 GitHub Actions 或上传到公开问题报告。

若提示名额不足，检查已安装的免费个人签名应用。此方式最多 3 个应用，AltStore 本身占一个名额，通常还能安装两个其它应用。[Apple 账号说明](https://developer.apple.com/help/account/basics/about-your-developer-account)、[AltStore 使用说明](https://faq.altstore.io/altstore-classic/your-altstore)

## 每 7 天续签

免费账号的描述文件有效期为 7 天。需要在到期前让 AltStore 的刷新成功，续签不需要每次重新编译理堂。

1. Windows 上运行 AltServer，手机通过 USB 或同一 Wi-Fi 连接。
2. 打开 AltStore 的 **My Apps → Refresh All**，确认有效期已经延长。
3. 初期手动操作确认可靠后再依赖自动刷新；不能仅因为电脑开机就认为续签已完成。
4. 若 AltStore 自身已经过期，按官方指南通过 AltServer 覆盖安装恢复，优先保留现有应用数据，不先卸载理堂。[AltServer 官方说明](https://faq.altstore.io/altstore-classic/altserver)

如果希望减少续签对电脑的依赖，可以在初版安装跑通后再评估 [SideStore](https://docs.sidestore.io/docs/installation/prerequisites)。它需要初始电脑设置、Wi-Fi 和相应本地 VPN 配置，也不能免除免费签名续期。

## 升级

- 从新一次成功运行下载新版 IPA，以同一 Apple Account 和相同应用身份重签覆盖安装，避免随意修改 Bundle ID。
- 首次升级验证课表缓存和登录态能否保留；签名工具或账号身份改变可能影响 Keychain 访问。
- iOS 版“我的 → iOS 安装包”打开实际构建仓库的工作流页面；安装和升级由签名工具完成。
- APK 更新清单仅用于 Android，iOS 不会执行 APK 下载和强制安装。

## 真机验收记录

- [ ] 能从 GitHub 下载 IPA，SHA-256 与元信息一致。
- [ ] 免费账号重签安装后进入首页，关闭重开正常。
- [ ] 教务登录、课表、成绩、排名正常。
- [ ] 学习通网页登录后可读取课程，退出和换号正常。
- [ ] 一网畅学课程、作业、考试内容正常。
- [ ] 附件选择、PDF、视频、扫码和定位正常，拒绝权限不会崩溃。
- [ ] 提醒授权、送达和点击跳转正常。
- [ ] 同账号覆盖升级及一次手动续签成功，缓存和登录态情况已记录。

这些验收需要实际手机配合，不能由云端编译通过替代。
