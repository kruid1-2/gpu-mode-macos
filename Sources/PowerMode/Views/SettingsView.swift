import SwiftUI

struct SettingsView: View {
    @ObservedObject var service: GPUService
    @AppStorage(SettingsKeys.refreshOnLaunch) private var refreshOnLaunch = true
    @State private var launchAtLogin = false

    var body: some View {
        Form {
            Toggle("开机启动", isOn: $launchAtLogin)
                .disabled(true)

            Text("开机启动第一版暂未实现；目前不会注册登录项。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("启动时自动刷新状态", isOn: $refreshOnLaunch)

            Divider()

            Section("管理员权限") {
                LabeledContent("特权助手", value: service.helperStatus.title)

                Text(service.helperMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                switch service.helperStatus {
                case .enabled:
                    Button("停用特权助手") {
                        Task {
                            await service.disableHelper()
                        }
                    }
                    .disabled(service.isLoading)

                case .requiresApproval:
                    Text("请前往：系统设置 → 通用 → 登录项与扩展。允许 GPU Mode 后返回应用并点击刷新。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack {
                        Button("打开系统设置") {
                            service.openLoginItemsSettings()
                        }

                        Button("刷新状态") {
                            service.refreshHelperStatus()
                        }
                    }
                    .disabled(service.isLoading)

                case .notInstalled, .notFound, .failed:
                    Text("启用特权助手后，首次设置需要系统确认，之后日常切换通常无需重复输入密码。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("启用免重复授权") {
                        Task {
                            await service.enableHelper()
                        }
                    }
                    .disabled(service.isLoading || service.helperStatus == .notFound)
                }

                Text("GPU Mode 的特权助手只能修改 gpuswitch 的 0、1、2 三个固定值，不能执行其他终端命令，也不会保存管理员密码。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            LabeledContent("版本", value: "1.0")
            LabeledContent("兼容性", value: service.compatibilityMessage)

            if !service.detectedGPUs.isEmpty {
                LabeledContent("检测到的显卡", value: service.detectedGPUs.joined(separator: " / "))
            }

            Text("GPU Mode 不联网、不收集数据，也不会保存管理员密码。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("刷新兼容性") {
                Task {
                    await service.refresh()
                }
            }
            .disabled(service.isLoading)
        }
        .padding(20)
        .frame(width: 460)
    }
}
