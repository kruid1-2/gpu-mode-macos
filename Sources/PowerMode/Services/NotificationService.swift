import AppKit
import Foundation
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var lastError: String?

    init() {
        Task {
            await refreshAuthorizationStatus()
        }
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func enableNotificationsIfPossible(appSettings: AppSettings) async {
        lastError = nil
        await refreshAuthorizationStatus()

        switch authorizationStatus {
        case .authorized, .provisional:
            appSettings.showNotifications = true
        case .denied:
            appSettings.showNotifications = false
            lastError = "通知权限已被拒绝。请在系统设置中允许 GPU Mode 发送通知。"
        case .notDetermined:
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                await refreshAuthorizationStatus()
                appSettings.showNotifications = granted
                if !granted {
                    lastError = "通知权限已被拒绝。请在系统设置中允许 GPU Mode 发送通知。"
                }
            } catch {
                appSettings.showNotifications = false
                lastError = "无法读取通知权限。请检查系统设置中的通知权限。"
            }
        @unknown default:
            appSettings.showNotifications = false
            lastError = "无法读取通知权限。请检查系统设置中的通知权限。"
        }
    }

    func sendSuccessNotification(for mode: GPUMode, appSettings: AppSettings) async {
        guard appSettings.showNotifications else {
            return
        }

        await refreshAuthorizationStatus()
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "GPU Mode"
        content.body = "已切换至\(mode.title)"
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "gpu-mode-switch-success-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
