import CoreLocation
import NightglowCore

/// One-shot CoreLocation fixes, cached in preferences so the app works
/// offline and after permission is revoked. City-level accuracy is plenty.
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var onUpdate: (() -> Void)?
    private(set) var lastError: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var authorizationDescription: String {
        switch manager.authorizationStatus {
        case .notDetermined: return "Not requested"
        case .restricted: return "Restricted"
        case .denied: return "Denied (System Settings > Privacy & Security > Location Services)"
        case .authorizedAlways, .authorizedWhenInUse: return "Allowed"
        @unknown default: return "Unknown"
        }
    }

    func request() {
        guard defaults.bool(forKey: Key.useCurrentLocation),
              !defaults.bool(forKey: Key.useManualLocation) else { return }
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: manager.requestLocation()
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        lastError = nil
        Preferences.cachedLocation = Coordinate(latitude: loc.coordinate.latitude,
                                                longitude: loc.coordinate.longitude)
        onUpdate?()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
        onUpdate?()
    }
}
