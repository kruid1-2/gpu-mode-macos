import Foundation

enum DiagnosticInfoBuilder {
    @MainActor
    static func makeText(
        service: GPUService,
        launchAtLoginStatus: LaunchAtLoginStatus,
        appSettings: AppSettings
    ) -> String {
        let gpus = service.detectedGPUs.isEmpty
            ? "- 尚未检测"
            : service.detectedGPUs.map { "- \($0)" }.joined(separator: "\n")
        let lastError = service.lastError?.isEmpty == false ? service.lastError! : "无"

        return """
        GPU Mode \(BundleInfo.shortVersion) (\(BundleInfo.buildNumber))

        系统：
        macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        架构：\(service.architecture)

        兼容性：
        支持状态：\(service.isSupported ? "支持" : "不支持")
        检测到的显卡：
        \(gpus)

        运行状态：
        当前切换策略：\(service.currentMode.title)
        外接显示器：\(service.hasExternalDisplay ? "是" : "否")
        开机启动：\(launchAtLoginStatus.title)
        授权方式：\(service.helperStatus == .enabled ? "特权助手" : "AppleScript 管理员授权")
        菜单栏显示方式：\(appSettings.menuBarDisplayStyle.title)
        最近一次错误：\(lastError)
        """
    }
}
