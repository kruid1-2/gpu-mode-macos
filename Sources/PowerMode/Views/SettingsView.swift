import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var service: GPUService
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var launchAtLoginService: LaunchAtLoginService
    @ObservedObject var notificationService: NotificationService

    var body: some View {
        TabView {
            GeneralSettingsView(
                service: service,
                appSettings: appSettings,
                launchAtLoginService: launchAtLoginService,
                notificationService: notificationService
            )
            .tabItem {
                Label("通用", systemImage: "gearshape")
            }

            MenuBarSettingsView(appSettings: appSettings)
                .tabItem {
                    Label("菜单栏", systemImage: "menubar.rectangle")
                }

            AboutSettingsView(
                service: service,
                appSettings: appSettings,
                launchAtLoginService: launchAtLoginService
            )
            .tabItem {
                Label("关于", systemImage: "info.circle")
            }
        }
        .scenePadding()
        .frame(width: 620, height: 500)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var service: GPUService
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var launchAtLoginService: LaunchAtLoginService
    @ObservedObject var notificationService: NotificationService
    @State private var resetConfirmationPresented = false

    var body: some View {
        Form {
            Section("启动") {
                Toggle(
                    "登录时启动 GPU Mode",
                    isOn: Binding(
                        get: { launchAtLoginService.status.isEnabled },
                        set: { launchAtLoginService.setEnabled($0) }
                    )
                )

                Text("登录 macOS 后自动在菜单栏运行。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                launchAtLoginStatusView
            }

            Section("行为") {
                Toggle("启动时刷新显卡状态", isOn: $appSettings.refreshOnLaunch)
                Text("每次启动 GPU Mode 时重新检测当前模式、显卡和显示器。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(
                    "切换成功后显示通知",
                    isOn: Binding(
                        get: { appSettings.showNotifications },
                        set: { isOn in
                            if isOn {
                                Task {
                                    await notificationService.enableNotificationsIfPossible(appSettings: appSettings)
                                }
                            } else {
                                appSettings.showNotifications = false
                            }
                        }
                    )
                )
                Text("只控制成功通知；必要的错误信息仍会显示。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                notificationStatusView

                Toggle("切换到独立显卡前确认", isOn: $appSettings.confirmDiscreteMode)
                Text("防止误触后增加耗电和发热。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("管理员权限") {
                LabeledContent("特权助手", value: service.helperStatus.title)
                Text(service.helperMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                helperControlView

                Text("特权助手只能修改 gpuswitch 的 0、1、2 三个固定值，不能执行其他终端命令，也不会保存管理员密码。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("恢复默认设置…") {
                    resetConfirmationPresented = true
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "确定恢复默认设置吗？",
            isPresented: $resetConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("恢复默认设置", role: .destructive) {
                appSettings.resetBehaviorPreferences()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这只会恢复 GPU Mode 的界面和行为偏好，不会修改当前显卡模式。")
        }
        .task {
            launchAtLoginService.refresh()
            await notificationService.refreshAuthorizationStatus()
            if notificationService.authorizationStatus == .denied {
                appSettings.showNotifications = false
            }
        }
    }

    @ViewBuilder
    private var launchAtLoginStatusView: some View {
        switch launchAtLoginService.status {
        case .enabled:
            Text("开机启动已启用。")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .notRegistered:
            Text("开机启动未启用。")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .requiresApproval:
            Text("GPU Mode 正在等待系统批准。请前往：系统设置 → 通用 → 登录项与扩展，允许 GPU Mode 在登录时运行。")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("打开系统设置") {
                    launchAtLoginService.openLoginItemsSettings()
                }
                Button("重新检查") {
                    launchAtLoginService.refresh()
                }
            }
        case .notFound:
            Text("当前应用包不支持开机启动。")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .failed(let message):
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        if let error = launchAtLoginService.lastError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var notificationStatusView: some View {
        if let error = notificationService.lastError {
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("打开通知设置") {
                notificationService.openNotificationSettings()
            }
        }
    }

    @ViewBuilder
    private var helperControlView: some View {
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
        case .notInstalled, .failed:
            Button("启用免重复授权") {
                Task {
                    await service.enableHelper()
                }
            }
            .disabled(service.isLoading)
        case .notFound:
            Text("应用包中没有找到特权助手文件。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct MenuBarSettingsView: View {
    @ObservedObject var appSettings: AppSettings

    var body: some View {
        Form {
            Section("显示") {
                Picker("菜单栏显示方式", selection: $appSettings.menuBarDisplayStyle) {
                    ForEach(MenuBarDisplayStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.radioGroup)

                Picker("图标样式", selection: $appSettings.menuBarIconStyle) {
                    ForEach(MenuBarIconStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section("菜单内容") {
                Toggle("在菜单中显示硬件状态", isOn: $appSettings.showHardwareStatus)
                Text("显示活动显卡、检测到的显卡和外接显示器信息。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("检测到外接显示器时显示警告", isOn: $appSettings.showExternalDisplayWarning)
                Text("只隐藏或显示提示文字，不改变系统行为。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutSettingsView: View {
    @ObservedObject var service: GPUService
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var launchAtLoginService: LaunchAtLoginService
    @State private var copyStatus: String?

    var body: some View {
        Form {
            Section("GPU Mode") {
                LabeledContent("版本", value: "\(BundleInfo.shortVersion) (\(BundleInfo.buildNumber))")
                Text("GPU Mode 是一个用于 Intel 双显卡 Mac 的菜单栏工具，可以读取并切换系统的显卡使用策略。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("GPU Mode 不联网、不收集数据，也不会读取或保存管理员密码。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("适用于部分配备 Intel 集成显卡和 AMD 独立显卡的 Intel Mac。Apple Silicon Mac 不支持 gpuswitch。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("当前设备状态") {
                LabeledContent("处理器架构", value: service.architecture)
                LabeledContent("检测到的显卡", value: service.detectedGPUs.isEmpty ? "尚未检测" : service.detectedGPUs.joined(separator: " / "))
                LabeledContent("当前切换策略", value: service.currentMode.title)
                LabeledContent("外接显示器", value: service.hasExternalDisplay ? "是" : "否")
                LabeledContent("设备兼容性", value: service.compatibilityMessage)
                LabeledContent("管理员执行方式", value: service.helperStatus == .enabled ? "特权助手" : "AppleScript 管理员授权")
                LabeledContent("开机启动状态", value: launchAtLoginService.status.title)
            }

            Section {
                HStack {
                    Button("刷新设备信息") {
                        Task {
                            launchAtLoginService.refresh()
                            await service.refresh()
                        }
                    }
                    .disabled(service.isLoading)

                    Button("复制诊断信息") {
                        copyDiagnostics()
                    }
                }

                if let copyStatus {
                    Text(copyStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            launchAtLoginService.refresh()
        }
    }

    private func copyDiagnostics() {
        let text = DiagnosticInfoBuilder.makeText(
            service: service,
            launchAtLoginStatus: launchAtLoginService.status,
            appSettings: appSettings
        )

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if pasteboard.setString(text, forType: .string) {
            copyStatus = "诊断信息已复制"
        } else {
            copyStatus = "无法复制诊断信息。"
        }
    }
}
