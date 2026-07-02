import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var service: GPUService

    var body: some View {
        Text("当前模式：\(service.currentMode.title)")

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
                    await service.switchMode(mode)
                }
            } label: {
                Label(modeButtonTitle(mode), systemImage: mode.symbolName)
            }
            .disabled(service.isLoading || !service.isSupported || service.currentMode == mode)
        }

        Divider()

        Text("当前活动显卡")
        Text(shortMenuTitle(service.activeGPUDescription))

        if !service.detectedGPUs.isEmpty {
            Divider()
            Text("检测到的显卡")
            ForEach(service.detectedGPUs, id: \.self) { gpuName in
                Text(shortMenuTitle(gpuName))
            }
        }

        if service.hasExternalDisplay {
            Divider()
            Text("⚠️ 外接显示器可能会启用独显")
        }

        Divider()

        Button("刷新状态") {
            Task {
                await service.refresh()
            }
        }
        .disabled(service.isLoading)

        Button("设置") {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }

        Divider()

        Button("退出 GPU Mode") {
            NSApplication.shared.terminate(nil)
        }
    }

    private func modeButtonTitle(_ mode: GPUMode) -> String {
        service.currentMode == mode ? "✓ \(mode.title)" : mode.title
    }
}

private func shortMenuTitle(_ title: String) -> String {
    guard title.count > 30 else {
        return title
    }

    return String(title.prefix(27)) + "..."
}
