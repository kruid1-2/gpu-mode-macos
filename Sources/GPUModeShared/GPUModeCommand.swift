import Foundation

public struct GPUModeCommandSpec: Equatable, Sendable {
    public let executablePath: String
    public let arguments: [String]

    public init(executablePath: String, arguments: [String]) {
        self.executablePath = executablePath
        self.arguments = arguments
    }
}

public enum GPUModeCommandFactory {
    public static let pmsetPath = "/usr/bin/pmset"
    public static let validModes = Set([0, 1, 2])

    public static func isValidMode(_ mode: Int) -> Bool {
        validModes.contains(mode)
    }

    public static func setModeCommand(for mode: Int) -> GPUModeCommandSpec? {
        guard isValidMode(mode) else {
            return nil
        }

        return GPUModeCommandSpec(
            executablePath: pmsetPath,
            arguments: ["-a", "gpuswitch", String(mode)]
        )
    }

    public static func lowPowerModeValue(for mode: Int) -> Int? {
        guard isValidMode(mode) else {
            return nil
        }

        return mode == 0 ? 1 : 0
    }

    public static func setLowPowerModeCommand(for mode: Int) -> GPUModeCommandSpec? {
        guard let lowPowerModeValue = lowPowerModeValue(for: mode) else {
            return nil
        }

        return GPUModeCommandSpec(
            executablePath: pmsetPath,
            arguments: ["-a", "lowpowermode", String(lowPowerModeValue)]
        )
    }

    public static func setModeCommands(for mode: Int) -> [GPUModeCommandSpec]? {
        guard let gpuSwitchCommand = setModeCommand(for: mode),
              let lowPowerCommand = setLowPowerModeCommand(for: mode) else {
            return nil
        }

        return [gpuSwitchCommand, lowPowerCommand]
    }

    public static func shellCommandString(for commands: [GPUModeCommandSpec]) -> String {
        commands.map { command in
            ([command.executablePath] + command.arguments).joined(separator: " ")
        }
        .joined(separator: "; ")
    }

    public static var getModeCommand: GPUModeCommandSpec {
        GPUModeCommandSpec(
            executablePath: pmsetPath,
            arguments: ["-g"]
        )
    }
}
