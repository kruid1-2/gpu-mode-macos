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

    public static var getModeCommand: GPUModeCommandSpec {
        GPUModeCommandSpec(
            executablePath: pmsetPath,
            arguments: ["-g"]
        )
    }
}
