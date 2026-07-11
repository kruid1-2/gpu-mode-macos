import CryptoKit
import Foundation
import GPUModeShared
import Security
import ServiceManagement

enum HelperStatus: Equatable, Sendable {
    case notInstalled
    case requiresApproval
    case enabled
    case notFound
    case unavailable(String)
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
        case .unavailable:
            "当前版本不可用"
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
        case .unavailable(let message):
            message
        case .failed(let message):
            message
        }
    }
}

final class HelperInstallationService: Sendable {
    private let registeredFingerprintKey = "GPUMode.RegisteredHelperFingerprint"

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

        guard hasStableSigningIdentity else {
            return .unavailable("当前 App 使用本地临时签名，macOS 不允许可靠启动免密特权助手；切换时将改用系统管理员授权。")
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
        recordCurrentFingerprint()
    }

    func unregister() throws {
        try appService.unregister()
        UserDefaults.standard.removeObject(forKey: registeredFingerprintKey)
    }

    func refreshRegistrationIfNeeded() throws {
        guard hasStableSigningIdentity,
              appService.status == .enabled,
              currentFingerprint() != UserDefaults.standard.string(forKey: registeredFingerprintKey) else {
            return
        }

        try refreshRegistration()
    }

    func refreshRegistration() throws {
        if appService.status != .notRegistered {
            try appService.unregister()
        }
        try appService.register()
        recordCurrentFingerprint()
    }

    func removeUnsupportedRegistrationIfNeeded() {
        guard !hasStableSigningIdentity,
              appService.status == .enabled || appService.status == .requiresApproval else {
            return
        }

        try? appService.unregister()
        UserDefaults.standard.removeObject(forKey: registeredFingerprintKey)
    }

    private var hasStableSigningIdentity: Bool {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode else {
            return false
        }

        var signingInfo: CFDictionary?
        guard SecCodeCopySigningInformation(
            staticCode,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &signingInfo
        ) == errSecSuccess,
              let signingInfo else {
            return false
        }

        return (signingInfo as NSDictionary)[kSecCodeInfoTeamIdentifier] as? String != nil
    }

    private func recordCurrentFingerprint() {
        guard let fingerprint = currentFingerprint() else {
            return
        }
        UserDefaults.standard.set(fingerprint, forKey: registeredFingerprintKey)
    }

    private func currentFingerprint() -> String? {
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons")
            .appendingPathComponent(GPUModeHelperConstants.helperExecutableName)
        guard let data = try? Data(contentsOf: helperURL) else {
            return nil
        }

        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
