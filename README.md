# Finder Menu

轻量 macOS Finder 右键菜单工具。SwiftUI 配置窗口左侧配置、右侧实时预览，选中项目后在 inspector 中编辑：添加 App、拖动排序、启用或禁用，修改自动保存，退出配置应用后仍然生效。界面跟随系统浅色 / 深色外观，文案支持简体中文与英文。

## 使用

- 点击「添加应用」选择一个或多个 `.app`，使用真实应用图标；相同 bundle ID 不重复添加。
- 拖动列表行调整顺序；也可以选中项目后在 inspector 中点「上移」/「下移」或按 ⌥⌘↑ / ⌥⌘↓，键盘和 VoiceOver 均可操作。inspector 中可编辑名称、选择显示范围或移除 App。名称在回车、离开输入框、切换项目或退出时保存，不会在输入过程中逐字保存。
- 右侧预览可切换文件 / 文件夹，按当前顺序显示已启用且符合范围的项目，编辑时高亮对应菜单；切换预览不修改配置。
- 左侧列表中的开关控制菜单是否显示。内置「复制路径」可以禁用，但不能删除。
- 修改保存成功后显示「已保存」。保存失败会显示错误并保留上一次成功的列表。
- 点击「退出应用」或 Command-Q 后，Finder 扩展继续读取已保存配置。打开 App 的助手仅在操作时启动，完成后退出，不注册登录项，也不重启配置应用。
- 升级后需要先启动一次配置应用，以生成请求签名密钥；在此之前「用 … 打开」菜单项显示为不可用，「复制路径」不受影响。

添加应用不意味着该应用支持所有文件格式或文件夹；是否能处理选中项取决于目标 App。Finder 自身的系统菜单不能由此工具排序，窗口里的灰色系统项是示意。

## 构建与运行

需要完整 Xcode、macOS 14 或更新版本。

```sh
./script/build_and_run.sh
```

也可以使用 Codex 的 Run 按钮，或在 Xcode 中打开 `FinderMenu.xcodeproj`，运行 `FinderMenu` scheme。

产物位于 `.build/DerivedData/Build/Products/Debug/Finder Menu.app`。脚本注册此处的扩展，不复制到 Applications，不修改其他 Finder 扩展。首次运行点击底部「管理…」，在系统设置中开启 Finder Menu；若已启用，后续运行脚本会重新加载本扩展。

```sh
./script/build_and_run.sh --build-only # 构建及校验签名
./script/build_and_run.sh --verify     # 构建、启动并检查主应用进程
./script/build_and_run.sh --telemetry  # 构建、启动并观察操作日志
./script/build_and_run.sh --debug      # 用 LLDB 启动主应用
./script/test.sh                      # FinderMenuCore 单元测试（swift test）
```

默认使用本地 ad-hoc 签名，不需要开发者团队；这不是可分发或已公证的发布包。受限自动化沙箱可能阻止 Swift 宏编译、Launch Services 或 PlugInKit，构建需要允许访问这些本机服务。

## DMG 安装包

```sh
./script/package_dmg.sh
```

构建 Release Apple Silicon 二进制（仅 arm64，macOS 14+），校验主应用、扩展和助手签名，并确认三个组件的版本号与构建号一致，生成 `dist/Finder-Menu-<版本>-arm64.dmg` 及 SHA-256 校验文件。版本默认取自 `Config/Base.xcconfig`，可用 `MARKETING_VERSION`、`CURRENT_PROJECT_VERSION` 环境变量覆盖。脚本还会校验磁盘映像、以只读方式挂载，并再次检查其中的应用签名。

打开 DMG，将 Finder Menu 拖入 Applications，再从 Applications 启动，点击「管理…」启用 Finder 扩展。安装包仍使用本地 ad-hoc 签名，未进行 Apple 公证；跨机器安装时可能出现 macOS 安全提示。

## 自动发布

将代码提交并推送后，推送 `vMAJOR.MINOR.PATCH` 格式的 tag 即会触发 GitHub Actions：

```sh
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

工作流先运行 Core 测试，再构建和校验 Apple Silicon DMG，最后创建同名 GitHub Release，附上 DMG、SHA-256 校验文件和自动生成的更新说明。版本号从 tag 提取，构建号使用 Actions run number，二者以构建设置传给所有组件，无需修改 `Config/Base.xcconfig`。只接受正式版本号，暂不支持 `-beta` 等预发布后缀。

每个 Pull Request 和推送到 `master` 的提交会由 CI 工作流运行 Core 测试并构建应用。

在 Actions → Release → Run workflow 中也可以手动验证打包；手动运行仅保存构建产物，不创建 Release。无需配置额外 Secret，发布使用仓库自带的 `GITHUB_TOKEN`；只有发布步骤所在的 job 有 `contents: write` 权限。已发布的 tag 不应移动或重复使用，后续发布请递增版本号。

CI 包仍为未公证的 ad-hoc 签名版本。自动发布不等同于完成 Apple Developer ID 签名与公证。

## 实现

```text
Core/       FinderMenuCore 本地 Swift 包：模型与迁移、选择分类、编辑操作、签名请求、偏好存储
App/        SwiftUI 配置窗口（List + inspector）、应用选择与图标缓存
Extension/  Finder Sync 扩展
Opener/     嵌入主应用的短生命周期打开助手
Config/     所有 target 共享的构建设置与版本号
```

- 工程使用 Xcode 文件夹同步，新增源文件无需修改 `project.pbxproj`；三个 target 都依赖 `FinderMenuCore`，以 Swift 6 语言模式编译。
- 配置模型中，菜单动作是带关联值的枚举（`copyPaths` / `open(application:)`），不会出现「打开应用却没有 bundle ID」这类非法组合。配置以版本号 2 的 JSON 保存；读取 0.1.x 的版本 1 配置时自动迁移，首次修改后写回新格式。遇到更新版本的配置时拒绝读写，不会覆盖。
- 选择分类每次菜单只检查一次所选项目，结果为文件、文件夹或混合。`.app`、`.rtfd` 等 package 按 Finder 的习惯视为文件，符号链接按目标判断。
- `Extension/`：Finder Sync 每次生成菜单时重新读取配置。复制路径直接使用 AppKit 剪贴板，多选时每行一条。Finder 在 XPC 队列而非主线程调用菜单和动作，扩展会先切换到主线程再操作 AppKit。
- `Opener/`：扩展用签名 URL 事件把菜单 ID 和选中路径交给指定的助手。助手先验证签名和时效，再重新校验启用状态、显示范围及应用身份，然后调用 `NSWorkspace` 打开文件或文件夹。没有 shell 命令拼接，也不依赖 `code` 命令。

配置通过 `CFPreferences` 保存在 `dev.jojo.FinderMenu.Configuration` 域。主应用与扩展启用 App Sandbox，分别仅获得该域的读写 / 只读共享偏好例外。本地 ad-hoc 构建未使用需要团队签名的 App Groups。

### 打开请求的安全模型

打开助手不启用沙盒：本机实测从沙盒扩展直接指定 App 打开文件会失败，启动参数也不会传递。沙盒扩展拉起助手时，LaunchServices 要求助手声明 `findermenu-open` URL scheme；不声明时会报「杂项错误」。因此这个 scheme 对本机所有进程和网页都可见，助手不能信任请求内容。

- 主应用首次启动时生成 256 位随机密钥，存入上述偏好域。偏好文件权限为 `0600`，其他沙盒应用和网页读不到。
- 扩展用 HMAC-SHA256 对请求 JSON（菜单 ID、路径、签发时间）签名。助手先校验签名，再解码内容，并拒绝超过 30 秒或明显来自未来的请求。
- 签名无效的请求只记录日志并退出，不弹窗，避免外部调用方驱动界面。

此方案能阻止网页和其他沙盒应用借助手打开任意路径，但不防御同一用户下未沙盒的程序：它们能读取密钥，本来也可以直接用 `open -a` 打开文件。正式发行前仍需确定签名、分发渠道与沙盒方案。

扩展将 `/` 注册为菜单作用范围，不扫描磁盘、不添加文件徽章，此设置不授予全盘访问权限。Finder 可保留或按需启动 `FinderMenuExtension`，不承诺系统后台完全没有进程。动作使用菜单生成时保存的 URL 快照和 `NSMenuItem.tag`；Finder 不保留 `representedObject`。

## 验证

自动检查（`./script/test.sh`）覆盖：版本 1 配置迁移、编解码保留顺序与状态、拒绝更新版本 / 损坏 / 重复 ID / 空名称、与 SwiftUI `onMove` 一致的移动语义、内置项不可删除、添加应用去重、文件 / 文件夹 / 混合 / package / 符号链接分类，以及签名请求的伪造、篡改、过期、未签名旧格式和非法路径拒绝。

2026-10-15，在 macOS 27.0.1 / Apple Silicon、Xcode 27.0 上验证 0.2.0：

| 检查 | 结果 |
| --- | --- |
| Debug 构建、三个组件嵌入与签名，三个组件版本均为 0.2.0 (2) | 通过 |
| 安装覆盖 0.1.0 后读取原有版本 1 配置，首次保存后为版本 2 | 通过，顺序、禁用状态与显示范围保留 |
| Finder 中右键 PNG →「用 预览 打开」 | 通过 |
| Finder 空白处右键 →「复制路径」 | 通过，扩展记录复制成功 |
| Finder 中右键含中文与空格的文件夹 →「用 Visual Studio Code 打开」 | 通过 |
| 配置窗口拖动排序、inspector 改名与上下移动、深色模式、添加应用 | 通过（人工检查） |
| 0.1.0 可用的未签名请求 `open 'findermenu-open://open/<id>?paths=…'` | 已拒绝，不弹窗，未打开任何 App |
| 伪造签名、超过 30 秒的重放 | 已拒绝 |
| 有效签名但菜单项已禁用、或范围不符（仅文件的项用于文件夹） | 已拒绝，并提示原因 |
| 所有打开操作结束后检查进程 | 通过，`FinderMenu` 和 `FinderMenuOpener` 均无进程 |

本版本未验证多选复制、macOS 14、iCloud / File Provider，以及系统重启后的行为。`--verify` 仅检查构建与主应用启动，不能替代 Finder 菜单验收。

```sh
/usr/bin/log show --last 10m --style compact \
  --predicate 'subsystem == "dev.jojo.FinderMenu"'
pgrep -x FinderMenu
pgrep -x FinderMenuOpener
```

成功操作日志包含应用 bundle ID、结果和项目数量，不包含文件内容。原有 Context Menu 保持启用，可能显示相似菜单；本应用默认用「用 Visual Studio Code 打开」区分。

停用时在系统设置中关闭 Finder Menu 扩展。
