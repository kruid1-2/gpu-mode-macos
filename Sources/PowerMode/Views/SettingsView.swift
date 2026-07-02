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
