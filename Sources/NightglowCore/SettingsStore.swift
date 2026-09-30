import Foundation

public enum SettingsStore {
    /// The shared settings domain. Inside the app bundle the suite *is* the
    /// main bundle's domain, which Foundation refuses as a suite name
    /// (returns nil), so fall back to .standard, which reads the same plist.
    public static func userDefaults(suiteName: String,
                                    mainBundleIdentifier: String? = Bundle.main.bundleIdentifier) -> UserDefaults {
        if suiteName == mainBundleIdentifier { return .standard }
        return UserDefaults(suiteName: suiteName) ?? .standard
    }
}
