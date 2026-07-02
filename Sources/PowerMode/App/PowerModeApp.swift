import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct GPUModeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appSettings: AppSettings
    @StateObject private var gpuService: GPUService
    @StateObject private var launchAtLoginService: LaunchAtLoginService
    @StateObject private var notificationService: NotificationService

    init() {
        let appSettings = AppSettings()
        let runner = ProcessRunner()
        let hardwareInfoService = HardwareInfoService(processRunner: runner)
        let legacyAuthorizationService = LegacyAuthorizationService(processRunner: runner)
        let helperInstallationService = HelperInstallationService()
        let helperConnectionService = HelperConnectionService()
        let launchAtLoginService = LaunchAtLoginService()
        let notificationService = NotificationService()
        _appSettings = StateObject(wrappedValue: appSettings)
        _launchAtLoginService = StateObject(wrappedValue: launchAtLoginService)
        _notificationService = StateObject(wrappedValue: notificationService)
        _gpuService = StateObject(
            wrappedValue: GPUService(
                appSettings: appSettings,
                processRunner: runner,
                hardwareInfoService: hardwareInfoService,
                legacyAuthorizationService: legacyAuthorizationService,
                helperInstallationService: helperInstallationService,
                helperConnectionService: helperConnectionService,
                notificationService: notificationService
            )
        )
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                service: gpuService,
                appSettings: appSettings,
                notificationService: notificationService
            )
        } label: {
            MenuBarStatusLabel(service: gpuService, appSettings: appSettings)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(
                service: gpuService,
                appSettings: appSettings,
                launchAtLoginService: launchAtLoginService,
                notificationService: notificationService
            )
        }
    }
}
