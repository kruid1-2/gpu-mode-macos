import XCTest
@testable import PowerMode

@MainActor
final class AppSettingsTests: XCTestCase {
    func testDefaults() {
        let defaults = UserDefaults(suiteName: "AppSettingsTests.defaults.\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults)

        XCTAssertTrue(settings.refreshOnLaunch)
        XCTAssertTrue(settings.showNotifications)
        XCTAssertFalse(settings.confirmDiscreteMode)
        XCTAssertEqual(settings.menuBarDisplayStyle, .iconOnly)
        XCTAssertEqual(settings.menuBarIconStyle, .automatic)
        XCTAssertTrue(settings.showHardwareStatus)
        XCTAssertTrue(settings.showExternalDisplayWarning)
    }

    func testResetBehaviorPreferencesDoesNotTouchUnrelatedKeys() {
        let defaults = UserDefaults(suiteName: "AppSettingsTests.reset.\(UUID().uuidString)")!
        defaults.set("keep", forKey: "unrelated")
        let settings = AppSettings(defaults: defaults)

        settings.refreshOnLaunch = false
        settings.showNotifications = false
        settings.confirmDiscreteMode = true
        settings.menuBarDisplayStyle = .modeOnly
        settings.menuBarIconStyle = .bolt
        settings.showHardwareStatus = false
        settings.showExternalDisplayWarning = false

        settings.resetBehaviorPreferences()

        XCTAssertTrue(settings.refreshOnLaunch)
        XCTAssertTrue(settings.showNotifications)
        XCTAssertFalse(settings.confirmDiscreteMode)
        XCTAssertEqual(settings.menuBarDisplayStyle, .iconOnly)
        XCTAssertEqual(settings.menuBarIconStyle, .automatic)
        XCTAssertTrue(settings.showHardwareStatus)
        XCTAssertTrue(settings.showExternalDisplayWarning)
        XCTAssertEqual(defaults.string(forKey: "unrelated"), "keep")
    }
}
