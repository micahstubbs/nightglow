import Foundation
import NightglowCore

/// UserDefaults keys shared by the controller and the SwiftUI settings view.
enum Key {
    static let enabled = "enabled"
    static let dayKelvin = "dayKelvin"
    static let nightKelvin = "nightKelvin"
    static let dayBrightness = "dayBrightness"
    static let nightBrightness = "nightBrightness"
    static let useManualLocation = "useManualLocation"
    static let manualLatitude = "manualLatitude"
    static let manualLongitude = "manualLongitude"
    static let useCurrentLocation = "useCurrentLocation"
    static let cachedLatitude = "cachedLatitude"
    static let cachedLongitude = "cachedLongitude"
    static let pausedUntil = "pausedUntil"
}

/// A fixed suite so the bundled app and the bare binary (CLI) share settings.
let defaults: UserDefaults = {
    let d = SettingsStore.userDefaults(suiteName: "fyi.micah.nightglow")
    d.register(defaults: [
        Key.enabled: true,
        Key.dayKelvin: 6500.0,
        Key.nightKelvin: 3400.0,
        Key.dayBrightness: 1.0,
        Key.nightBrightness: 1.0,
        Key.useManualLocation: false,
        Key.manualLatitude: 0.0,
        Key.manualLongitude: 0.0,
        Key.useCurrentLocation: true,
    ])
    return d
}()

enum Preferences {
    static var enabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    static var schedule: Schedule {
        Schedule(dayKelvin: defaults.double(forKey: Key.dayKelvin),
                 nightKelvin: defaults.double(forKey: Key.nightKelvin),
                 dayBrightness: defaults.double(forKey: Key.dayBrightness),
                 nightBrightness: defaults.double(forKey: Key.nightBrightness))
    }

    static var pausedUntil: Date? {
        get {
            guard let d = defaults.object(forKey: Key.pausedUntil) as? Date, d > Date() else { return nil }
            return d
        }
        set { defaults.set(newValue, forKey: Key.pausedUntil) }
    }

    static var cachedLocation: Coordinate? {
        get {
            guard defaults.object(forKey: Key.cachedLatitude) != nil else { return nil }
            return Coordinate(latitude: defaults.double(forKey: Key.cachedLatitude),
                              longitude: defaults.double(forKey: Key.cachedLongitude))
        }
        set {
            defaults.set(newValue?.latitude, forKey: Key.cachedLatitude)
            defaults.set(newValue?.longitude, forKey: Key.cachedLongitude)
        }
    }

    /// Manual coordinates win, then the last CoreLocation fix, then the
    /// time zone's reference city, then a longitude guessed from the UTC offset.
    static func resolvedLocation() -> (coordinate: Coordinate, source: String) {
        if defaults.bool(forKey: Key.useManualLocation) {
            return (Coordinate(latitude: defaults.double(forKey: Key.manualLatitude),
                               longitude: defaults.double(forKey: Key.manualLongitude)), "Manual")
        }
        if defaults.bool(forKey: Key.useCurrentLocation), let c = cachedLocation {
            return (c, "Current location")
        }
        let zone = TimeZone.current.identifier
        if let c = TimeZoneLocation.coordinate(for: zone) {
            return (c, "Time zone (\(zone))")
        }
        let longitude = Double(TimeZone.current.secondsFromGMT()) / 240
        return (Coordinate(latitude: 0, longitude: longitude), "UTC offset")
    }
}
