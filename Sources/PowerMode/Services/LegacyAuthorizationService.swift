import Foundation
import GPUModeShared

enum LegacyAuthorizationError: LocalizedError, Sendable {
    case unsupportedMode
    case userCancelled
    case commandFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedMode:
            "这个模式不能被切换。"
        case .userCancelled:
            "操作已取消，显卡模式未改变。"
        case .commandFailed:
            "切换命令没有执行成功，请确认当前 Mac 支持显卡切换。"
        }
    }
}

final class LegacyAuthorizationService: Sendable {
    private let processRunner: ProcessRunner

    init(processRunner: ProcessRunner) {
        self.processRunner = processRunner
    }

    func apply(_ mode: GPUMode) async throws {
        guard let targetValue = mode.gpuSwitchValue,
              let gpuSwitchCommand = GPUModeCommandFactory.setModeCommand(for: targetValue),
              let lowPowerModeCommand = GPUModeCommandFactory.setLowPowerModeCommand(for: targetValue) else {
            throw LegacyAuthorizationError.unsupportedMode
        }

        let gpuSwitchShellCommand = GPUModeCommandFactory.shellCommandString(for: [gpuSwitchCommand])
        let lowPowerModeShellCommand = GPUModeCommandFactory.shellCommandString(for: [lowPowerModeCommand])
        let fixedCommand = "\(gpuSwitchShellCommand) && { \(lowPowerModeShellCommand) || true; }"
        let appleScript = "do shell script \"\(fixedCommand)\" with administrator privileges"

        do {
            _ = try await processRunner.run(
                "/usr/bin/osascript",
                arguments: ["-e", appleScript],
                timeout: 120
            )
        } catch let error as ProcessRunnerError {
            let diagnostic = error.diagnosticText
            if diagnostic.localizedCaseInsensitiveContains("User canceled")
                || diagnostic.contains("-128")
                || diagnostic.contains("用户已取消") {
                throw LegacyAuthorizationError.userCancelled
            }
            throw LegacyAuthorizationError.commandFailed
        }
    }
}
