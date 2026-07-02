import AppKit
import Foundation
import GPUModeShared

@MainActor
final class GPUService: ObservableObject {
    @Published private(set) var currentMode: GPUMode = .unknown
    @Published private(set) var isLoading = false
    @Published private(set) var isSupported = false
    @Published private(set) var statusMessage = "正在读取状态..."
    @Published private(set) var detectedGPUs: [String] = []
    @Published private(set) var activeGPUDescription = "无法可靠判断"
    @Published private(set) var hasExternalDisplay = false
    @Published private(set) var lastError: String?
    @Published private(set) var compatibilityMessage = "正在检测兼容性..."
    @Published private(set) var lastRefreshed: Date?
    @Published private(set) var helperStatus: HelperStatus = .notInstalled
    @Published private(set) var helperMessage = "当前每次切换都需要管理员授权。"
    @Published private(set) var pendingModeForAuthorization: GPUMode?

    private let processRunner: ProcessRunner
    private let hardwareInfoService: HardwareInfoService
    private let legacyAuthorizationService: LegacyAuthorizationService
    private let helperInstallationService: HelperInstallationService
    private let helperConnectionService: HelperConnectionService
    private var didAutoRefresh = false

    var menuBarTitle: String {
        switch currentMode {
        case .unknown:
            "GPU Mode"
        default:
            currentMode.title
        }
    }

    var menuBarSymbolName: String {
        currentMode.menuBarSymbolName
    }

    init(
        processRunner: ProcessRunner,
        hardwareInfoService: HardwareInfoService,
        legacyAuthorizationService: LegacyAuthorizationService,
        helperInstallationService: HelperInstallationService,
        helperConnectionService: HelperConnectionService
    ) {
        self.processRunner = processRunner
        self.hardwareInfoService = hardwareInfoService
        self.legacyAuthorizationService = legacyAuthorizationService
        self.helperInstallationService = helperInstallationService
        self.helperConnectionService = helperConnectionService

        if UserDefaults.standard.object(forKey: SettingsKeys.refreshOnLaunch) == nil {
            UserDefaults.standard.set(true, forKey: SettingsKeys.refreshOnLaunch)
        }

        if UserDefaults.standard.bool(forKey: SettingsKeys.refreshOnLaunch) {
            Task { [weak self] in
                await self?.refreshIfNeeded()
            }
        }
    }

    func refreshIfNeeded() async {
        guard !didAutoRefresh else {
            return
        }

        didAutoRefresh = true
        await refresh()
    }

    func refresh() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        lastError = nil
        statusMessage = "正在刷新状态..."

        async let hardwareTask = hardwareInfoService.load()
        async let modeTask = readCurrentMode()

        refreshHelperStatus()
        let hardwareInfo = await hardwareTask
        apply(hardwareInfo)

        do {
            currentMode = try await modeTask
            statusMessage = "状态已更新"
        } catch {
            currentMode = .unknown
            lastError = friendlyMessage(for: error)
            statusMessage = "无法读取当前模式"
        }

        lastRefreshed = Date()
        isLoading = false
    }

    func switchMode(_ mode: GPUMode) async {
        guard !isLoading else {
            return
        }

        guard isSupported else {
            lastError = compatibilityMessage
            statusMessage = "当前设备不支持切换"
            return
        }

        guard mode != currentMode else {
            statusMessage = "已经是\(mode.title)"
            return
        }

        guard let targetValue = mode.gpuSwitchValue, GPUModeCommandFactory.isValidMode(targetValue) else {
            lastError = "拒绝非法显卡模式。"
            statusMessage = "切换没有完成"
            return
        }

        refreshHelperStatus()

        guard helperStatus == .enabled else {
            pendingModeForAuthorization = mode
            lastError = "特权助手尚未启用。你可以启用免重复授权，或仅本次使用管理员权限切换。"
            statusMessage = "请选择授权方式"
            return
        }

        isLoading = true
        lastError = nil
        statusMessage = "正在切换至\(mode.title)..."

        do {
            try await helperConnectionService.setMode(targetValue)
            try await verifySwitchResult(expectedMode: mode)
            pendingModeForAuthorization = nil
        } catch {
            lastError = friendlyMessage(for: error)
            statusMessage = "切换没有完成"
        }

        isLoading = false
    }

    func enableHelper() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        lastError = nil
        statusMessage = "正在启用特权助手..."

        do {
            try helperInstallationService.register()
            refreshHelperStatus()
            switch helperStatus {
            case .enabled:
                statusMessage = "特权助手已启用"
            case .requiresApproval:
                statusMessage = "特权助手正在等待系统批准"
            default:
                statusMessage = helperStatus.title
            }
        } catch {
            lastError = friendlyMessage(for: error)
            statusMessage = "特权助手启用失败"
        }

        isLoading = false
    }

    func disableHelper() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        lastError = nil
        statusMessage = "正在停用特权助手..."

        do {
            try helperInstallationService.unregister()
            helperConnectionService.resetConnection()
            refreshHelperStatus()
            statusMessage = "特权助手已停用，后续切换将再次请求管理员授权。"
        } catch {
            lastError = friendlyMessage(for: error)
            statusMessage = "特权助手停用失败"
        }

        isLoading = false
    }

    func useLegacyAuthorizationForPendingMode() async {
        guard let pendingMode = pendingModeForAuthorization else {
            return
        }
        await switchModeUsingLegacyAuthorization(pendingMode)
    }

    func cancelPendingAuthorizationChoice() {
        pendingModeForAuthorization = nil
        lastError = nil
        statusMessage = "已取消切换"
    }

    func refreshHelperStatus() {
        helperStatus = helperInstallationService.status()
        helperMessage = helperStatus.explanation
    }

    func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func switchModeUsingLegacyAuthorization(_ mode: GPUMode) async {
        guard !isLoading else {
            return
        }

        guard mode != currentMode else {
            pendingModeForAuthorization = nil
            statusMessage = "已经是\(mode.title)"
            return
        }

        isLoading = true
        lastError = nil
        statusMessage = "正在使用单次管理员授权..."

        do {
            try await legacyAuthorizationService.apply(mode)
            try await verifySwitchResult(expectedMode: mode)
            pendingModeForAuthorization = nil
        } catch {
            lastError = friendlyMessage(for: error)
            statusMessage = "切换没有完成"
        }

        isLoading = false
    }

    private func apply(_ hardwareInfo: HardwareInfo) {
        isSupported = hardwareInfo.isSupported
        compatibilityMessage = hardwareInfo.compatibilityMessage
        detectedGPUs = hardwareInfo.detectedGPUs
        activeGPUDescription = hardwareInfo.activeGPUDescription
        hasExternalDisplay = hardwareInfo.hasExternalDisplay

        if let warningMessage = hardwareInfo.warningMessage {
            lastError = warningMessage
        }
    }

    private func verifySwitchResult(expectedMode: GPUMode) async throws {
        let verifiedMode = try await readCurrentMode()
        let hardwareInfo = await hardwareInfoService.load()
        apply(hardwareInfo)
        refreshHelperStatus()

        if verifiedMode == expectedMode {
            currentMode = verifiedMode
            statusMessage = "已切换至\(expectedMode.title)"
        } else {
            currentMode = verifiedMode
            lastError = "命令已执行，但系统返回的模式与预期不一致。"
            statusMessage = "切换结果需要确认"
        }
        lastRefreshed = Date()
    }

    private func readCurrentMode() async throws -> GPUMode {
        let result = try await processRunner.run("/usr/bin/pmset", arguments: ["-g"], timeout: 5)

        for line in result.standardOutput.components(separatedBy: .newlines) {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard parts.first == "gpuswitch", let rawValue = parts.dropFirst().first else {
                continue
            }

            guard let value = Int(rawValue) else {
                return .unknown
            }

            return GPUMode(gpuSwitchValue: value)
        }

        throw GPUServiceError.gpuSwitchNotFound
    }

    private func friendlyMessage(for error: Error) -> String {
        if let legacyError = error as? LegacyAuthorizationError {
            return legacyError.localizedDescription
        }

        if let helperError = error as? HelperConnectionError {
            return helperError.localizedDescription
        }

        if let runnerError = error as? ProcessRunnerError {
            switch runnerError {
            case .timedOut:
                return "系统命令响应超时，请稍后刷新重试。"
            default:
                return "无法读取显卡模式，请确认当前设备是支持双显卡切换的 Intel Mac。"
            }
        }

        if let serviceError = error as? GPUServiceError {
            return serviceError.localizedDescription
        }

        let nsError = error as NSError
        if nsError.domain == "SMAppServiceErrorDomain" || nsError.domain == "com.apple.ServiceManagement" {
            return "特权助手注册失败。请确认应用已正确签名，并在系统设置中允许后台项目。"
        }

        return "操作失败，请稍后再试。"
    }
}

enum GPUServiceError: LocalizedError, Sendable {
    case gpuSwitchNotFound

    var errorDescription: String? {
        switch self {
        case .gpuSwitchNotFound:
            "当前 macOS 或机型可能不支持此功能。"
        }
    }
}

enum SettingsKeys {
    static let refreshOnLaunch = "refreshOnLaunch"
}
