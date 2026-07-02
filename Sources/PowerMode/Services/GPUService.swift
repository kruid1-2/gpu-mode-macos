import Foundation

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

    private let processRunner: ProcessRunner
    private let hardwareInfoService: HardwareInfoService
    private let privilegedCommandService: PrivilegedCommandService
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
        privilegedCommandService: PrivilegedCommandService
    ) {
        self.processRunner = processRunner
        self.hardwareInfoService = hardwareInfoService
        self.privilegedCommandService = privilegedCommandService

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

        isLoading = true
        lastError = nil
        statusMessage = "正在切换至\(mode.title)..."

        do {
            try await privilegedCommandService.apply(mode)
            let verifiedMode = try await readCurrentMode()
            let hardwareInfo = await hardwareInfoService.load()
            apply(hardwareInfo)

            if verifiedMode == mode {
                currentMode = verifiedMode
                statusMessage = "已切换至\(mode.title)"
            } else {
                currentMode = verifiedMode
                lastError = "命令已执行，但系统返回的模式与预期不一致。"
                statusMessage = "切换结果需要确认"
            }
            lastRefreshed = Date()
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
        if let privilegedError = error as? PrivilegedCommandError {
            return privilegedError.localizedDescription
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
