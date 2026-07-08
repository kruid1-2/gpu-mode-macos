# GPU Mode

GPU Mode 是一个面向部分 Intel 双显卡 Mac 的 macOS 菜单栏工具，用于查看并切换系统的电源与显卡使用策略：集显优先、独显优先和自动切换。

English summary: GPU Mode is a macOS menu bar utility for selected Intel Macs with dual GPUs. It reads and switches the system `lowpowermode` and `gpuswitch` settings with clear safety boundaries.

## 主要功能

- 菜单栏查看当前低电量模式和显卡切换策略。
- 在“集显优先”“独显优先”“自动切换”之间切换。
- 显示检测到的显卡、当前活动显卡和外接显示器提示。
- 原生 macOS 设置面板，支持开机启动、菜单栏显示样式、通知和诊断信息。
- 可选特权 Helper，减少日常切换时重复输入管理员密码。
- 保留一次性管理员授权路径，未启用 Helper 时仍可手动授权切换。

## 软件截图

截图暂未提交到仓库。建议后续放在以下位置：

- `docs/screenshots/menu-bar.png`
- `docs/screenshots/settings-general.png`
- `docs/screenshots/settings-menubar.png`
- `docs/screenshots/settings-about.png`

## 系统要求

- macOS 13 Ventura 或更新版本。
- Swift 6 / Xcode 16 或更新版本用于源码构建。
- Intel Mac，并且系统支持 `pmset gpuswitch`。

## 兼容机型说明

GPU Mode 只适用于部分同时配备 Intel 集成显卡和 AMD 独立显卡的 Intel MacBook 机型。应用会在启动或刷新时检测当前设备是否支持 `gpuswitch`。

如果当前 Mac 没有双显卡，或者系统不提供 `gpuswitch`，应用会显示不兼容提示，切换按钮会保持不可用。

## Apple Silicon 不支持说明

Apple Silicon Mac 不支持 `pmset gpuswitch`，也没有 Intel 集显和 AMD 独显之间的传统切换机制。因此 GPU Mode 不支持 M1、M2、M3、M4 或后续 Apple Silicon 机型。

## 安装方法

当前仓库主要面向源码构建和本地测试。获得构建好的 `GPU Mode.app` 后：

1. 将 `GPU Mode.app` 放入“应用程序”文件夹。
2. 打开应用后，它会出现在菜单栏。
3. 如需开机启动，在“设置...”里的“通用”页面启用。
4. 如需免重复授权，在设置页启用特权 Helper，并按 macOS 系统设置提示批准后台项目。

## 从源码构建

克隆仓库后，在仓库根目录执行：

```bash
swift build
swift test
swift build -c release
```

本地生成可运行 `.app` 包可使用：

```bash
./script/build_and_run.sh --verify
```

该脚本会构建 `PowerMode` 和 `GPUModeHelper`，生成本地 `GPU Mode.app`，并使用 ad hoc 签名方便本机调试。生成的应用包会声明支持 macOS 自动显卡切换，避免菜单栏应用自身无意中唤起独显。脚本不会注册或安装特权 Helper；只有在应用内主动启用 Helper 时，才会调用 macOS 的 ServiceManagement 注册流程。

## 管理员权限用途

切换策略需要修改系统电源管理设置，本质上会执行固定形式的命令：

```bash
/usr/bin/pmset -a lowpowermode <0|1>
/usr/bin/pmset -a gpuswitch <mode>
```

三种模式对应关系如下：

- 集显优先：`lowpowermode 1`，`gpuswitch 0`。
- 独显优先：`lowpowermode 0`，`gpuswitch 1`。
- 自动切换：`lowpowermode 0`，`gpuswitch 2`。

## Helper 安全边界

特权 Helper 的目标是减少重复输入管理员密码，不是扩大应用能力。当前安全边界如下：

- Helper 只接受固定的模式参数，并只会写入 `lowpowermode` 的 `0`、`1` 和 `gpuswitch` 的 `0`、`1`、`2`。
- Helper 不接受任意 shell 命令。
- Helper 固定调用 `/usr/bin/pmset`。
- Helper 不保存管理员密码。
- Helper 的 XPC 接口只暴露读取当前模式和设置固定模式两个能力。

发布版本需要使用正式 Developer ID 签名，并将主应用和 Helper 的代码签名要求更新为包含你的 Team ID 的严格要求。

## 隐私说明

GPU Mode 不联网，不收集遥测数据，不读取 Apple ID，不读取钥匙串密码，不保存管理员密码。

诊断信息只包含应用版本、macOS 版本、处理器架构、显卡检测结果、当前模式、`lowpowermode`、`gpuswitch`、外接显示器状态、开机启动状态和最近一次应用错误。诊断信息不应包含用户名、主目录路径、设备序列号、Apple ID、密码或无关硬件信息。

## 外接显示器限制

`gpuswitch 0` 是系统显卡策略，不是硬件级禁用独显。很多 Intel 双显卡 Mac 在连接外接显示器时，macOS 可能会强制启用独立显卡；部分正在运行的应用也可能继续请求独显。这些是硬件和系统行为限制，不一定能通过 `gpuswitch` 覆盖。GPU Mode 会声明自身支持自动显卡切换，并尽量显示提示，但不能保证所有场景下持续只使用集成显卡。

## 已知问题

- 仅支持部分 Intel 双显卡 Mac。
- Apple Silicon Mac 不支持。
- 外接显示器可能导致系统强制使用独显。
- 本地调试脚本使用 ad hoc 签名，不适合直接公开分发。
- 正式分发前需要 Developer ID 签名、公证和更严格的 XPC 代码签名要求。

## 卸载方法

1. 如果启用了特权 Helper，先在 GPU Mode 设置页停用。
2. 在“系统设置 -> 通用 -> 登录项与扩展”中移除或关闭 GPU Mode。
3. 退出 GPU Mode。
4. 删除 `GPU Mode.app`。

如果曾批准后台项目，但应用已被手动删除，请在系统设置的登录项与后台项目页面确认并清理残留项。

## 免责声明

GPU Mode 会修改 macOS 电源管理中的显卡切换策略。错误使用可能导致更高功耗、发热、续航下降，或者在特定硬件组合下表现不符合预期。请自行确认设备兼容性，并理解使用 `pmset gpuswitch` 的风险。

## 许可证

本项目使用 MIT License。详情见 `LICENSE`。
