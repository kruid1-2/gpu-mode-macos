import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var service: GPUService
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var notificationService: NotificationService

    var body: some View {
        Text("当前模式：\(service.currentMode == .unknown ? "当前模式未知" : service.currentMode.title)")
        Text("lowpowermode: \(service.lowPowerModeStatusText)")
        Text("gpuswitch: \(service.gpuSwitchStatusText)")

        if service.isLoading {
            Text("正在处理...")
        }

        if !service.isSupported {
            Text(shortMenuTitle(service.compatibilityMessage))
        }

        if let lastError = service.lastError {
            Text(shortMenuTitle(lastError))
        } else {
            Text(shortMenuTitle(service.statusMessage))
        }

        if service.pendingModeForAuthorization != nil {
            Divider()

            Button("启用特权助手") {
                Task {
                    await service.enableHelper()
                }
            }
            .disabled(service.isLoading)

            Button("仅本次授权") {
                Task {
                    await service.useLegacyAuthorizationForPendingMode()
                }
            }
            .disabled(service.isLoading)

            Button("取消") {
                service.cancelPendingAuthorizationChoice()
            }
            .disabled(service.isLoading)
        }

        Divider()

        Text("切换模式")

        ForEach(GPUMode.switchableCases) { mode in
            Button {
                Task {
                    await requestModeSwitch(mode)
                }
            } label: {
                Label(modeButtonTitle(mode), systemImage: mode.symbolName)
            }
            .disabled(service.isLoading || !service.isSupported || service.isModeFullyApplied(mode))
        }

        Divider()

        if appSettings.showHardwareStatus {
            Text("当前活动显卡")
            Text(shortMenuTitle(service.activeGPUDescription))
        }

        if let integratedModeWarning = service.integratedModeWarning {
            Divider()
            Text(shortMenuTitle(integratedModeWarning))
        }

        if appSettings.showHardwareStatus && !service.detectedGPUs.isEmpty {
            Divider()
            Text("检测到的显卡")
            ForEach(service.detectedGPUs, id: \.self) { gpuName in
                Text(shortMenuTitle(gpuName))
            }
        }

        if appSettings.showExternalDisplayWarning && service.hasExternalDisplay {
            Divider()
            Text("外接显示器可能会启用独显")
        }

        Divider()

        Button("刷新状态") {
            Task {
                await service.refresh()
            }
        }
        .disabled(service.isLoading)

        if #available(macOS 14.0, *) {
            ModernSettingsButton()
        } else {
            Button("设置…") {
                SettingsWindowPresenter.showLegacySettings()
            }
        }

        Divider()

        Button("退出 GPU Mode") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func modeButtonTitle(_ mode: GPUMode) -> String {
        service.isModeFullyApplied(mode) ? "✓ \(mode.title)" : mode.title
    }

    @MainActor
    private func requestModeSwitch(_ mode: GPUMode) async {
        if mode == .integrated {
            let safety = await service.checkIntegratedSwitchSafety()
            if let blockingMessage = safety.blockingMessage {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "独显仍被占用"
                alert.informativeText = blockingMessage
                alert.addButton(withTitle: "取消")
                alert.addButton(withTitle: "仍然强制切换")

                guard alert.runModal() == .alertSecondButtonReturn else {
                    return
                }
            }

            await service.switchMode(mode, allowUnsafeIntegratedSwitch: true)
            return
        }

        if appSettings.confirmDiscreteMode && mode == .discrete {
            let alert = NSAlert()
            alert.messageText = "切换到独显优先？"
            alert.informativeText = "该模式通常会增加耗电和发热。"
            alert.addButton(withTitle: "切换")
            alert.addButton(withTitle: "取消")

            guard alert.runModal() == .alertFirstButtonReturn else {
                return
            }
        }

        await service.switchMode(mode)
    }

}

@available(macOS 14.0, *)
private struct ModernSettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("设置…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
            SettingsWindowPresenter.bringSettingsWindowToFront()
        }
    }
}

@MainActor
private enum SettingsWindowPresenter {
    static func showLegacySettings() {
        NSApp.activate(ignoringOtherApps: true)
        if !NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
        bringSettingsWindowToFront()
    }

    static func bringSettingsWindowToFront(attemptsRemaining: Int = 4) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            let settingsWindow = NSApp.windows.first { window in
                window.styleMask.contains(.titled) && window.canBecomeKey
            }

            if let settingsWindow {
                if settingsWindow.isMiniaturized {
                    settingsWindow.deminiaturize(nil)
                }
                NSApp.activate(ignoringOtherApps: true)
                settingsWindow.makeKeyAndOrderFront(nil)
                settingsWindow.orderFrontRegardless()
            } else if attemptsRemaining > 1 {
                bringSettingsWindowToFront(attemptsRemaining: attemptsRemaining - 1)
            }
        }
    }
}

private func shortMenuTitle(_ title: String) -> String {
    guard title.count > 30 else {
        return title
    }

    return String(title.prefix(27)) + "..."
}

struct MenuBarStatusLabel: View {
    @ObservedObject var service: GPUService
    @ObservedObject var appSettings: AppSettings

    var body: some View {
        switch appSettings.menuBarDisplayStyle {
        case .iconOnly:
            Image(systemName: symbolName)
                .accessibilityLabel("GPU Mode，当前\(modeTitle)")
        case .iconAndMode:
            Label(modeTitle, systemImage: symbolName)
        case .modeOnly:
            Text(modeTitle)
        }
    }

    private var modeTitle: String {
        service.currentMode.shortTitle
    }

    private var symbolName: String {
        if service.isLoading {
            return "hourglass"
        }

        if service.lastError != nil {
            return "exclamationmark.triangle"
        }

        switch appSettings.menuBarIconStyle {
        case .automatic:
            return service.currentMode.menuBarSymbolName
        case .gauge:
            return "gauge.with.dots.needle.50percent"
        case .display:
            return "display"
        case .bolt:
            return "bolt"
        }
    }
}
