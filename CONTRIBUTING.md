# Contributing

感谢你愿意改进 GPU Mode。这个项目涉及 macOS 电源管理和特权 Helper，请优先保持改动小、可审查、可验证。

## 构建要求

- macOS 13 Ventura 或更新版本。
- Xcode 16 或更新版本。
- Swift 6 工具链。

常用检查：

```bash
swift build
swift test
swift build -c release
```

## 分支和提交建议

- 从最新主分支创建功能分支。
- 一次提交只做一类改动。
- 提交信息用简短中文或英文说明实际变化。
- 不要提交本地构建产物、日志、签名证书、provisioning profile、公证凭据或个人开发环境配置。

## Pull Request 要求

Pull Request 建议包含：

- 改动目的。
- 影响范围。
- 已执行的构建和测试命令。
- 是否涉及 Helper、管理员权限、签名、公证或 `pmset` 行为。
- 必要时附上截图，但截图中不要包含设备敏感信息。

## 安全规定

不得扩大特权 Helper 的命令范围。Helper 只能围绕固定的 `gpuswitch` 模式值工作：

- `0`
- `1`
- `2`

不得把 Helper 改成任意 shell 命令执行器，不得保存管理员密码，不得读取钥匙串密码，不得收集 Apple ID、设备序列号或无关系统信息。

涉及以下内容的改动需要特别谨慎，并在 PR 中明确说明：

- XPC 接口。
- ServiceManagement 注册逻辑。
- 代码签名要求。
- Helper 可执行命令。
- 管理员授权流程。
- 诊断信息内容。
