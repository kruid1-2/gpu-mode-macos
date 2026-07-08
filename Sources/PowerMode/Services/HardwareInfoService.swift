import Foundation

struct HardwareInfo: Sendable {
    let architecture: String
    let detectedGPUs: [String]
    let activeGPUCandidates: [String]
    let discreteGPUClients: [String]
    let hasIntelGPU: Bool
    let hasAMDGPU: Bool
    let hasExternalDisplay: Bool
    let supportsAutomaticGraphicsSwitching: Bool
    let pmsetHasGPUSwitch: Bool
    let warningMessage: String?

    var isAppleSilicon: Bool {
        architecture == "arm64"
    }

    var isSupported: Bool {
        !isAppleSilicon && hasIntelGPU && hasAMDGPU && pmsetHasGPUSwitch
    }

    var compatibilityMessage: String {
        if isAppleSilicon {
            return "当前设备为 Apple Silicon Mac，不支持 gpuswitch 显卡切换。"
        }

        if !hasIntelGPU || !hasAMDGPU {
            return "当前 Mac 未检测到受支持的 Intel + AMD 双显卡配置。"
        }

        if !pmsetHasGPUSwitch {
            return "当前 macOS 或机型可能不支持此功能。"
        }

        return "当前设备支持显卡模式切换。"
    }

    var activeGPUDescription: String {
        if activeGPUCandidates.isEmpty {
            return "无法可靠判断"
        }

        return activeGPUCandidates.joined(separator: " / ")
    }

    var hasActiveDiscreteGPU: Bool {
        !discreteGPUClients.isEmpty || activeGPUCandidates.contains { gpuName in
            gpuName.localizedCaseInsensitiveContains("AMD")
                || gpuName.localizedCaseInsensitiveContains("Radeon")
        }
    }
}

final class HardwareInfoService: Sendable {
    private let processRunner: ProcessRunner

    init(processRunner: ProcessRunner) {
        self.processRunner = processRunner
    }

    func load() async -> HardwareInfo {
        async let architectureResult = readArchitecture()
        async let displayResult = readDisplayInfo()
        async let muxClientsResult = readDiscreteGPUClients()
        async let pmsetHasGPUSwitchResult = readGPUSwitchSupport()

        let architecture = await architectureResult
        let displayInfo = await displayResult
        let muxClients = await muxClientsResult
        let hasGPUSwitch = await pmsetHasGPUSwitchResult

        return HardwareInfo(
            architecture: architecture,
            detectedGPUs: displayInfo.detectedGPUs,
            activeGPUCandidates: displayInfo.activeGPUCandidates,
            discreteGPUClients: muxClients,
            hasIntelGPU: displayInfo.hasIntelGPU,
            hasAMDGPU: displayInfo.hasAMDGPU,
            hasExternalDisplay: displayInfo.hasExternalDisplay,
            supportsAutomaticGraphicsSwitching: displayInfo.supportsAutomaticGraphicsSwitching,
            pmsetHasGPUSwitch: hasGPUSwitch,
            warningMessage: displayInfo.warningMessage
        )
    }

    private func readArchitecture() async -> String {
        do {
            let result = try await processRunner.run("/usr/bin/uname", arguments: ["-m"], timeout: 3)
            return result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return "unknown"
        }
    }

    private func readGPUSwitchSupport() async -> Bool {
        do {
            let result = try await processRunner.run("/usr/bin/pmset", arguments: ["-g", "custom"], timeout: 5)
            return result.standardOutput.contains("gpuswitch")
        } catch {
            return false
        }
    }

    private func readDiscreteGPUClients() async -> [String] {
        do {
            let result = try await processRunner.run(
                "/usr/sbin/ioreg",
                arguments: ["-r", "-c", "AppleMuxControl", "-l"],
                timeout: 5
            )
            return Self.parseDiscreteGPUClients(from: result.standardOutput)
        } catch {
            return []
        }
    }

    private func readDisplayInfo() async -> DisplayInfoParseResult {
        do {
            let result = try await processRunner.run(
                "/usr/sbin/system_profiler",
                arguments: ["SPDisplaysDataType"],
                timeout: 12
            )
            return parseDisplayInfo(result.standardOutput, warningMessage: nil)
        } catch let error as ProcessRunnerError {
            return parseDisplayInfo("", warningMessage: friendlyProfilerMessage(error))
        } catch {
            return parseDisplayInfo("", warningMessage: "无法读取显卡信息。")
        }
    }

    private func friendlyProfilerMessage(_ error: ProcessRunnerError) -> String {
        switch error {
        case .timedOut:
            "读取显卡信息超时，可以稍后刷新。"
        default:
            "无法读取显卡信息，可以稍后刷新。"
        }
    }

    private func parseDisplayInfo(_ output: String, warningMessage: String?) -> DisplayInfoParseResult {
        var detectedGPUs: [String] = []
        var activeGPUCandidates: [String] = []
        var currentGPU: String?
        var hasIntelGPU = false
        var hasAMDGPU = false
        var hasExternalDisplay = false
        var supportsSwitching = false

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("Chipset Model:") {
                let name = trimmed
                    .replacingOccurrences(of: "Chipset Model:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                currentGPU = name
                if !detectedGPUs.contains(name) {
                    detectedGPUs.append(name)
                }
                if name.localizedCaseInsensitiveContains("Intel") {
                    hasIntelGPU = true
                }
                if name.localizedCaseInsensitiveContains("AMD")
                    || name.localizedCaseInsensitiveContains("Radeon") {
                    hasAMDGPU = true
                }
            } else if trimmed == "Automatic Graphics Switching: Supported" {
                supportsSwitching = true
            } else if trimmed == "Online: Yes", let currentGPU {
                if !activeGPUCandidates.contains(currentGPU) {
                    activeGPUCandidates.append(currentGPU)
                }
            } else if trimmed.hasPrefix("Connection Type:") {
                let connectionType = trimmed
                    .replacingOccurrences(of: "Connection Type:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !connectionType.localizedCaseInsensitiveContains("Internal") {
                    hasExternalDisplay = true
                }
            }
        }

        return DisplayInfoParseResult(
            detectedGPUs: detectedGPUs,
            activeGPUCandidates: activeGPUCandidates,
            hasIntelGPU: hasIntelGPU,
            hasAMDGPU: hasAMDGPU,
            hasExternalDisplay: hasExternalDisplay,
            supportsAutomaticGraphicsSwitching: supportsSwitching,
            warningMessage: warningMessage
        )
    }

    static func parseDiscreteGPUClients(from output: String) -> [String] {
        guard let lineRange = output.range(of: #""task-runtime"\s*=\s*\([^\n]*\)"#, options: .regularExpression),
              let regex = try? NSRegularExpression(pattern: #""[0-9]+,[0-9]+,([^"]+)""#) else {
            return []
        }

        let line = String(output[lineRange])
        let nsRange = NSRange(line.startIndex..<line.endIndex, in: line)
        var clients: [String] = []

        for match in regex.matches(in: line, range: nsRange) {
            guard let range = Range(match.range(at: 1), in: line) else {
                continue
            }

            let client = String(line[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !client.isEmpty && !clients.contains(client) {
                clients.append(client)
            }
        }

        return clients
    }
}

private struct DisplayInfoParseResult: Sendable {
    let detectedGPUs: [String]
    let activeGPUCandidates: [String]
    let hasIntelGPU: Bool
    let hasAMDGPU: Bool
    let hasExternalDisplay: Bool
    let supportsAutomaticGraphicsSwitching: Bool
    let warningMessage: String?
}
