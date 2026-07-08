import AppKit
import Foundation
import GPUModeShared

private struct PowerSettingsStatus: Sendable {
    let gpuMode: GPUMode
    let gpuSwitchValue: Int?
    let lowPowerModeValue: Int?

    var summary: String {
        "lowpowermode: \(lowPowerModeValue.map(String.init) ?? "未检测到")，gpuswitch: \(gpuSwitchValue.map(String.init) ?? "未检测到")"
    }
}

@MainActor
final class GPUService: ObservableObject {
    @Published private(set) var currentMode: GPUMode = .unknown
    @Published private(set) var currentGPUSwitchValue: Int?
    @Published private(set) var currentLowPowerModeValue: Int?
    @Published private(set) var isLoading = false
    @Published private(set) var isSupported = false
    @Published private(set) var statusMessage = "正在读取状态..."
    @Published private(set) var detectedGPUs: [String] = []
    @Published private(set) var activeGPUDescription = "无法可靠判断"
    @Published private(set) var discreteGPUClients: [String] = []
    @Published private(set) var integratedModeWarning: String?
    @Published private(set) var hasExternalDisplay = false
    @Published private(set) var architecture = "尚未检测"
    @Published private(set) var lastError: String?
    @Published private(set) var compatibilityMessage = "正在检测兼容性..."
    @Published private(set) var lastRefreshed: Date?
    @Published private(set) var helperStatus: HelperStatus = .notInstalled
    @Published private(set) var helperMessage = "当前每次切换都需要管理员授权。"
    @Published private(set) var pendingModeForAuthorization: GPUMode?

    private let processRunner: ProcessRunner
    private let appSettings: AppSettings
    private let hardwareInfoService: HardwareInfoService
    private let legacyAuthorizationService: LegacyAuthorizationService
    private let helperInstallationService: HelperInstallationService
    private let helperConnectionService: HelperConnectionService
    private let notificationService: NotificationService
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

    var gpuSwitchStatusText: String {
        currentGPUSwitchValue.map(String.init) ?? "未检测到"
    }

    var lowPowerModeStatusText: String {
        currentLowPowerModeValue.map(String.init) ?? "未检测到"
    }

    var powerStatusSummary: String {
        "lowpowermode: \(lowPowerModeStatusText)，gpuswitch: \(gpuSwitchStatusText)"
    }

    init(
        appSettings: AppSettings,
        processRunner: ProcessRunner,
        hardwareInfoService: HardwareInfoService,
        legacyAuthorizationService: LegacyAuthorizationService,
        helperInstallationService: HelperInstallationService,
        helperConnectionService: HelperConnectionService,
        notificationService: NotificationService
    ) {
        self.appSettings = appSettings
        self.processRunner = processRunner
        self.hardwareInfoService = hardwareInfoService
        self.legacyAuthorizationService = legacyAuthorizationService
        self.helperInstallationService = helperInstallationService
        self.helperConnectionService = helperConnectionService
        self.notificationService = notificationService

        if appSettings.refreshOnLaunch {
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
        async let statusTask = readPowerSettingsStatus()

        refreshHelperStatus()
        let hardwareInfo = await hardwareTask
        apply(hardwareInfo)

        do {
            apply(try await statusTask)
            statusMessage = "状态已更新（\(powerStatusSummary)）"
        } catch {
            currentMode = .unknown
            currentGPUSwitchValue = nil
            currentLowPowerModeValue = nil
            lastError = friendlyMessage(for: error)
            statusMessage = "无法读取当前模式"
        }

        updateIntegratedModeWarning()
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

        guard !isModeFullyApplied(mode) else {
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

    func isModeFullyApplied(_ mode: GPUMode) -> Bool {
        guard currentMode == mode,
              let targetValue = mode.gpuSwitchValue,
              let expectedLowPowerModeValue = GPUModeCommandFactory.lowPowerModeValue(for: targetValue) else {
            return false
        }

        return currentLowPowerModeValue == expectedLowPowerModeValue
    }

    private func switchModeUsingLegacyAuthorization(_ mode: GPUMode) async {
        guard !isLoading else {
            return
        }

        guard !isModeFullyApplied(mode) else {
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
        architecture = hardwareInfo.architecture.isEmpty ? "尚未检测" : hardwareInfo.architecture
        compatibilityMessage = hardwareInfo.compatibilityMessage
        detectedGPUs = hardwareInfo.detectedGPUs
        activeGPUDescription = hardwareInfo.activeGPUDescription
        discreteGPUClients = hardwareInfo.discreteGPUClients
        hasExternalDisplay = hardwareInfo.hasExternalDisplay
        updateIntegratedModeWarning(activeDiscreteGPU: hardwareInfo.hasActiveDiscreteGPU)

        if let warningMessage = hardwareInfo.warningMessage {
            lastError = warningMessage
        }
    }

    private func apply(_ status: PowerSettingsStatus) {
        currentMode = status.gpuMode
        currentGPUSwitchValue = status.gpuSwitchValue
        currentLowPowerModeValue = status.lowPowerModeValue
    }

    private func verifySwitchResult(expectedMode: GPUMode) async throws {
        let verifiedStatus = try await readPowerSettingsStatus()
        let hardwareInfo = await hardwareInfoService.load()
        apply(hardwareInfo)
        apply(verifiedStatus)
        refreshHelperStatus()

        let expectedLowPowerModeValue = expectedMode.gpuSwitchValue.flatMap {
            GPUModeCommandFactory.lowPowerModeValue(for: $0)
        }
        let lowPowerModeMatches = expectedLowPowerModeValue.map {
            verifiedStatus.lowPowerModeValue == $0
        } ?? true

        if verifiedStatus.gpuMode == expectedMode && lowPowerModeMatches {
            statusMessage = "已切换至\(expectedMode.title)（\(verifiedStatus.summary)）"
            updateIntegratedModeWarning(activeDiscreteGPU: hardwareInfo.hasActiveDiscreteGPU)
            await notificationService.sendSuccessNotification(for: expectedMode, appSettings: appSettings)
        } else {
            lastError = "命令已执行，但系统返回的 lowpowermode 或 gpuswitch 与预期不一致。"
            statusMessage = "切换结果需要确认（\(verifiedStatus.summary)）"
            updateIntegratedModeWarning(activeDiscreteGPU: hardwareInfo.hasActiveDiscreteGPU)
        }
        lastRefreshed = Date()
    }

    private func updateIntegratedModeWarning(activeDiscreteGPU: Bool? = nil) {
        let inferredDiscreteActivity = activeGPUDescription.localizedCaseInsensitiveContains("AMD")
            || activeGPUDescription.localizedCaseInsensitiveContains("Radeon")
        let isDiscreteActive = activeDiscreteGPU ?? inferredDiscreteActivity

        if currentMode == .integrated && isDiscreteActive {
            if discreteGPUClients.isEmpty {
                integratedModeWarning = "系统仍在使用独显，通常是外接显示器或其他应用触发。"
            } else {
                integratedModeWarning = "独显占用：\(discreteGPUClients.joined(separator: " / "))"
            }
        } else {
            integratedModeWarning = nil
        }
    }

    private func readPowerSettingsStatus() async throws -> PowerSettingsStatus {
        let result = try await processRunner.run("/usr/bin/pmset", arguments: ["-g"], timeout: 5)
        var gpuSwitchValue: Int?
        var lowPowerModeValue: Int?

        for line in result.standardOutput.components(separatedBy: .newlines) {
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard let key = parts.first, let rawValue = parts.dropFirst().first else {
                continue
            }

            switch key {
            case "gpuswitch":
                gpuSwitchValue = Int(rawValue)
            case "lowpowermode":
                lowPowerModeValue = Int(rawValue)
            default:
                continue
            }
        }

        guard let gpuSwitchValue else {
            throw GPUServiceError.gpuSwitchNotFound
        }

        return PowerSettingsStatus(
            gpuMode: GPUMode(gpuSwitchValue: gpuSwitchValue),
            gpuSwitchValue: gpuSwitchValue,
            lowPowerModeValue: lowPowerModeValue
        )
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
