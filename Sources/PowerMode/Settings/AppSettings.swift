import Foundation

enum SettingsKey {
    static let refreshOnLaunch = "refreshOnLaunch"
    static let showNotifications = "showNotifications"
    static let confirmDiscreteMode = "confirmDiscreteMode"
    static let menuBarDisplayStyle = "menuBarDisplayStyle"
    static let menuBarIconStyle = "menuBarIconStyle"
    static let showHardwareStatus = "showHardwareStatus"
    static let showExternalDisplayWarning = "showExternalDisplayWarning"
}

enum MenuBarDisplayStyle: String, CaseIterable, Identifiable {
    case iconOnly
    case iconAndMode
    case modeOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .iconOnly:
            "仅图标"
        case .iconAndMode:
            "图标和模式"
        case .modeOnly:
            "仅模式"
        }
    }
}

enum MenuBarIconStyle: String, CaseIterable, Identifiable {
    case automatic
    case gauge
    case display
    case bolt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            "自动"
        case .gauge:
            "仪表盘"
        case .display:
            "显示器"
        case .bolt:
            "闪电"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var refreshOnLaunch: Bool {
        didSet { defaults.set(refreshOnLaunch, forKey: SettingsKey.refreshOnLaunch) }
    }
    @Published var showNotifications: Bool {
        didSet { defaults.set(showNotifications, forKey: SettingsKey.showNotifications) }
    }
    @Published var confirmDiscreteMode: Bool {
        didSet { defaults.set(confirmDiscreteMode, forKey: SettingsKey.confirmDiscreteMode) }
    }
    @Published var menuBarDisplayStyle: MenuBarDisplayStyle {
        didSet { defaults.set(menuBarDisplayStyle.rawValue, forKey: SettingsKey.menuBarDisplayStyle) }
    }
    @Published var menuBarIconStyle: MenuBarIconStyle {
        didSet { defaults.set(menuBarIconStyle.rawValue, forKey: SettingsKey.menuBarIconStyle) }
    }
    @Published var showHardwareStatus: Bool {
        didSet { defaults.set(showHardwareStatus, forKey: SettingsKey.showHardwareStatus) }
    }
    @Published var showExternalDisplayWarning: Bool {
        didSet { defaults.set(showExternalDisplayWarning, forKey: SettingsKey.showExternalDisplayWarning) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.registerDefaults(in: defaults)

        refreshOnLaunch = defaults.bool(forKey: SettingsKey.refreshOnLaunch)
        showNotifications = defaults.bool(forKey: SettingsKey.showNotifications)
        confirmDiscreteMode = defaults.bool(forKey: SettingsKey.confirmDiscreteMode)
        showHardwareStatus = defaults.bool(forKey: SettingsKey.showHardwareStatus)
        showExternalDisplayWarning = defaults.bool(forKey: SettingsKey.showExternalDisplayWarning)

        let displayRawValue = defaults.string(forKey: SettingsKey.menuBarDisplayStyle) ?? MenuBarDisplayStyle.iconOnly.rawValue
        menuBarDisplayStyle = MenuBarDisplayStyle(rawValue: displayRawValue) ?? .iconOnly

        let iconRawValue = defaults.string(forKey: SettingsKey.menuBarIconStyle) ?? MenuBarIconStyle.automatic.rawValue
        menuBarIconStyle = MenuBarIconStyle(rawValue: iconRawValue) ?? .automatic
    }

    static func registerDefaults(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            SettingsKey.refreshOnLaunch: true,
            SettingsKey.showNotifications: true,
            SettingsKey.confirmDiscreteMode: false,
            SettingsKey.menuBarDisplayStyle: MenuBarDisplayStyle.iconOnly.rawValue,
            SettingsKey.menuBarIconStyle: MenuBarIconStyle.automatic.rawValue,
            SettingsKey.showHardwareStatus: true,
            SettingsKey.showExternalDisplayWarning: true
        ])
    }

    func resetBehaviorPreferences() {
        refreshOnLaunch = true
        showNotifications = true
        confirmDiscreteMode = false
        menuBarDisplayStyle = .iconOnly
        menuBarIconStyle = .automatic
        showHardwareStatus = true
        showExternalDisplayWarning = true
    }
}
