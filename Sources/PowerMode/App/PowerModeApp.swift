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
    @StateObject private var gpuService: GPUService

    init() {
        let runner = ProcessRunner()
        let hardwareInfoService = HardwareInfoService(processRunner: runner)
        let privilegedCommandService = PrivilegedCommandService(processRunner: runner)
        _gpuService = StateObject(
            wrappedValue: GPUService(
                processRunner: runner,
                hardwareInfoService: hardwareInfoService,
                privilegedCommandService: privilegedCommandService
            )
        )
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(service: gpuService)
        } label: {
            Label(gpuService.menuBarTitle, systemImage: gpuService.menuBarSymbolName)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(service: gpuService)
        }
    }
}
