import XCTest
@testable import NightglowCore

/// bd-2kl regression: UserDefaults(suiteName:) returns nil when the suite
/// equals the main bundle identifier, so the bundled app crashed at launch
/// force-unwrapping it while the bare binary worked.
final class SettingsStoreTests: XCTestCase {
    func testSuiteMatchingMainBundleUsesStandardDefaults() {
        XCTAssertNil(UserDefaults(suiteName: Bundle.main.bundleIdentifier ?? ""),
                     "precondition: Foundation refuses the app's own id as a suite")
        let d = SettingsStore.userDefaults(suiteName: "fyi.micah.nightglow",
                                           mainBundleIdentifier: "fyi.micah.nightglow")
        XCTAssertTrue(d === UserDefaults.standard)
    }

    func testOtherProcessesUseTheSharedSuite() {
        let d = SettingsStore.userDefaults(suiteName: "fyi.micah.nightglow.tests", mainBundleIdentifier: nil)
        XCTAssertFalse(d === UserDefaults.standard)
    }
}
