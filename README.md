# Finder Menu

轻量 macOS Finder 右键菜单工具。SwiftUI 亮色配置窗口采用「静谧工作台」双栏布局，左侧配置、右侧实时预览：添加 App、拖动排序、启用或禁用，修改自动保存，退出配置应用后仍然生效。

## 使用

- 点击「添加应用」选择一个或多个 `.app`，使用真实应用图标；相同 bundle ID 不重复添加。
- 拖动菜单行左侧六点手柄调整顺序，悬停时高亮并显示抓取光标；点击项目可展开或收起设置，编辑名称、选择显示范围或移除 App。修改自动保存，无需点击完成。
- 右侧预览可切换文件 / 文件夹，按当前顺序显示已启用且符合范围的项目，编辑时高亮对应菜单；切换预览不修改配置。
- 左侧列表中的开关控制菜单是否显示。内置「复制路径」可以禁用，但不能删除。
- 修改保存成功后显示「已保存」。保存失败会显示错误并保留上一次成功的列表。
- 点击「退出应用」或 Command-Q 后，Finder 扩展继续读取已保存配置。打开 App 的助手仅在操作时启动，完成后退出，不注册登录项，也不重启配置应用。

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
./script/test.sh                      # 配置编解码、顺序、禁用和作用范围检查
```

默认使用本地 ad-hoc 签名，不需要开发者团队；这不是可分发或已公证的发布包。受限自动化沙箱可能阻止 Swift 宏编译、Launch Services 或 PlugInKit，构建需要允许访问这些本机服务。

## DMG 安装包

```sh
./script/package_dmg.sh
```

构建 Release Apple Silicon 二进制（仅 arm64，macOS 14+），校验主应用、扩展和助手签名，生成 `dist/Finder-Menu-0.1.0-arm64.dmg` 及 SHA-256 校验文件。脚本还会校验磁盘映像、以只读方式挂载，并再次检查其中的应用签名。

打开 DMG，将 Finder Menu 拖入 Applications，再从 Applications 启动，点击「管理…」启用 Finder 扩展。安装包仍使用本地 ad-hoc 签名，未进行 Apple 公证；跨机器安装时可能出现 macOS 安全提示。

## 自动发布

将代码提交并推送后，推送 `vMAJOR.MINOR.PATCH` 格式的 tag 即会触发 GitHub Actions：

```sh
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

工作流先运行配置测试，再构建和校验 Apple Silicon DMG，最后创建同名 GitHub Release，附上 DMG、SHA-256 校验文件和自动生成的更新说明。版本号从 tag 提取并写入 CI 工作目录中的主应用、扩展和助手，构建号使用 Actions run number，无需提前修改三个 Info.plist。只接受正式版本号，暂不支持 `-beta` 等预发布后缀。

在 Actions → Release → Run workflow 中也可以手动验证打包；手动运行仅保存构建产物，不创建 Release。无需配置额外 Secret，发布使用仓库自带的 `GITHUB_TOKEN`；只有发布步骤所在的 job 有 `contents: write` 权限。已发布的 tag 不应移动或重复使用，后续发布请递增版本号。

CI 包仍为未公证的 ad-hoc 签名版本。自动发布不等同于完成 Apple Developer ID 签名与公证。

## 实现

- `App/`：SwiftUI 配置窗口、应用选择面板、保存状态。没有菜单栏常驻项。
- `Shared/`：配置模型与持久化，包含稳定 ID、菜单顺序、启用状态、显示范围及应用 bundle ID / 路径。
- `Extension/`：Finder Sync 每次生成菜单时重新读取配置；复制路径直接使用 AppKit 剪贴板，多选时每行一条。
- `Opener/`：嵌入主应用的短生命周期 App。扩展通过指定助手的 URL 事件传递选中路径和菜单 ID；助手重新校验启用状态、显示范围及应用身份，再调用 `NSWorkspace` 打开文件或文件夹。没有 shell 命令拼接或 `code` 命令依赖。

配置通过 `CFPreferences` 保存在 `dev.jojo.FinderMenu.Configuration` 域。主应用与扩展启用 App Sandbox，分别仅获得该域的读写 / 只读共享偏好例外。本地 ad-hoc 构建未使用需要团队签名的 App Groups。

通用打开助手不启用沙盒：本机实测从沙盒扩展直接指定 App 打开文件会失败，而启动参数也不会传递。因此采用显式指定助手的 URL 事件，再由助手调用系统打开 API。此架构适用于当前本地原型；正式发行前需确定签名、分发渠道与沙盒方案。

扩展将 `/` 注册为菜单作用范围，不扫描磁盘、不添加文件徽章，此设置不授予全盘访问权限。Finder 可保留或按需启动 `FinderMenuExtension`，不承诺系统后台完全没有进程。动作使用菜单生成时保存的 URL 快照和 `NSMenuItem.tag`；Finder 不保留 `representedObject`。

## 验证

自动检查覆盖配置编解码、顺序和禁用状态保留、文件 / 文件夹 / 混合选择范围，以及非法版本和重复 ID 拒绝。

2026-10-15，在 macOS 27.0.1 / Apple Silicon、Xcode 27.0 上完成本版本的真实 UI 验证：

| 检查 | 结果 |
| --- | --- |
| Debug 构建、三个组件嵌入与签名 | 通过 |
| 双栏实时预览 | 通过，文件 / 文件夹切换、名称编辑、开关及上下移动同步显示 |
| 系统面板添加 Cursor 和预览 | 通过，列表显示真实应用图标 |
| 拖动预览到首位、禁用 Cursor、设置预览仅文件 | 通过，Finder 中顺序一致、禁用项隐藏、文件夹不显示预览 |
| 配置应用退出后重新打开 | 通过，顺序、禁用与显示范围恢复 |
| 退出后复制路径 | 通过，本扩展记录复制成功 |
| 退出后用 VS Code 打开文件和文件夹 | 通过，VS Code 显示对应文件和项目目录；路径含中文及空格 |
| 退出后用新增的预览打开 PNG | 通过，预览显示目标图片 |
| 所有打开操作结束后检查进程 | 通过，`FinderMenu` 和 `FinderMenuOpener` 均无进程 |

此前最小原型还验证了多选复制及空白处复制当前目录。本版本未重复验证这些路径，也未在 macOS 14、iCloud / File Provider、系统重启后验证。`--verify` 仅检查构建与主应用启动，不能替代 Finder 菜单验收。

```sh
/usr/bin/log show --last 10m --style compact \
  --predicate 'subsystem == "dev.jojo.FinderMenu"'
pgrep -x FinderMenu
pgrep -x FinderMenuOpener
```

成功操作日志包含应用 bundle ID、结果和项目数量，不包含文件内容。原有 Context Menu 保持启用，可能显示相似菜单；本应用默认用「用 Visual Studio Code 打开」区分。

停用时在系统设置中关闭 Finder Menu 扩展。
