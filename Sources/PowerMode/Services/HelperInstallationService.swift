import Foundation
import GPUModeShared
import ServiceManagement

enum HelperStatus: Equatable, Sendable {
    case notInstalled
    case requiresApproval
    case enabled
    case notFound
    case failed(String)

    var title: String {
        switch self {
        case .notInstalled:
            "未启用"
        case .requiresApproval:
            "等待系统批准"
        case .enabled:
            "已启用"
        case .notFound:
            "未找到 Helper"
        case .failed:
            "状态异常"
        }
    }

    var explanation: String {
        switch self {
        case .notInstalled:
            "当前每次切换都需要管理员授权。"
        case .requiresApproval:
            "特权助手正在等待系统批准。"
        case .enabled:
            "日常切换显卡模式时不需要重复输入管理员密码。"
        case .notFound:
            "应用包中没有找到特权助手文件。"
        case .failed(let message):
            message
        }
    }
}

final class HelperInstallationService: Sendable {
    private var appService: SMAppService {
        SMAppService.daemon(plistName: GPUModeHelperConstants.launchDaemonPlistName)
    }

    func status() -> HelperStatus {
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons")
            .appendingPathComponent(GPUModeHelperConstants.helperExecutableName)
        let plistURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons")
            .appendingPathComponent(GPUModeHelperConstants.launchDaemonPlistName)

        guard FileManager.default.fileExists(atPath: helperURL.path),
              FileManager.default.fileExists(atPath: plistURL.path) else {
            return .notFound
        }

        switch appService.status {
        case .notRegistered:
            return .notInstalled
        case .enabled:
            return .enabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .notFound
        @unknown default:
            return .failed("无法识别特权助手状态。")
        }
    }

    func register() throws {
        try appService.register()
    }

    func unregister() throws {
        try appService.unregister()
    }
}
