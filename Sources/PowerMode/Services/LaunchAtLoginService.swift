import AppKit
import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
    case failed(String)

    var title: String {
        switch self {
        case .notRegistered:
            "未启用"
        case .enabled:
            "已启用"
        case .requiresApproval:
            "等待系统批准"
        case .notFound:
            "不可用"
        case .failed:
            "状态异常"
        }
    }

    var isEnabled: Bool {
        if case .enabled = self {
            return true
        }
        return false
    }
}

@MainActor
final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var status: LaunchAtLoginStatus = .notRegistered
    @Published private(set) var lastError: String?

    init() {
        refresh()
    }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .notRegistered:
            status = .notRegistered
        case .enabled:
            status = .enabled
        case .requiresApproval:
            status = .requiresApproval
        case .notFound:
            status = .notFound
        @unknown default:
            status = .failed("无法识别开机启动状态。")
        }
    }

    func setEnabled(_ isEnabled: Bool) {
        lastError = nil

        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            refresh()
        } catch {
            refresh()
            lastError = isEnabled ? "无法启用开机启动。请确认 GPU Mode 位于“应用程序”文件夹，然后重试。" : "无法关闭开机启动。"
        }
    }

    func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
