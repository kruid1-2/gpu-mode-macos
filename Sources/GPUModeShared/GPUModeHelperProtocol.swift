import Foundation

@objc public protocol GPUModeHelperProtocol {
    func setGPUMode(_ mode: Int, reply: @escaping (Bool, String?) -> Void)
    func getCurrentMode(reply: @escaping (Int, String?) -> Void)
}

public enum GPUModeHelperConstants {
    public static let appBundleIdentifier = "local.gpumode.control"
    public static let helperBundleIdentifier = "local.gpumode.control.helper"
    public static let helperExecutableName = "GPUModeHelper"
    public static let launchDaemonPlistName = "\(helperBundleIdentifier).plist"
    public static let machServiceName = helperBundleIdentifier
    public static let helperBundleProgram = "Contents/Library/LaunchDaemons/\(helperExecutableName)"

    public static let developmentClientRequirement = #"identifier "\#(appBundleIdentifier)""#
    public static let developmentHelperRequirement = #"identifier "\#(helperBundleIdentifier)""#
}
