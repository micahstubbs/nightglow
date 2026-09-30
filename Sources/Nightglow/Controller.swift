import AppKit
import NightglowCore

/// Decides the current setting from the sun and preferences and keeps the
/// displays on it.
final class Controller {
    let engine = GammaEngine()
    let location = LocationProvider()
    private(set) var current = DisplaySetting.neutral
    private(set) var isPreviewing = false
    var onChange: (() -> Void)?

    private var tick: Timer?
    private var fade: Timer?
    private var preview: Timer?
    private var ignoringDefaults = false

    struct Status {
        var coordinate: Coordinate
        var source: String
        var elevation: Double
        var target: DisplaySetting
        var phase: String
        var next: Solar.Transition?
        var sunrise: Date?
        var sunset: Date?
    }

    static func status(at date: Date = Date()) -> Status {
        let (c, source) = Preferences.resolvedLocation()
        let elevation = Solar.elevation(at: date, latitude: c.latitude, longitude: c.longitude)
        let schedule = Preferences.schedule
        let fraction = schedule.dayFraction(elevation: elevation)
        let phase = fraction >= 1 ? "Day" : fraction <= 0 ? "Night" : "Twilight"
        let events = Solar.events(on: date, latitude: c.latitude, longitude: c.longitude)
        return Status(coordinate: c, source: source, elevation: elevation,
                      target: schedule.setting(elevation: elevation), phase: phase,
                      next: Solar.nextTransition(after: date, latitude: c.latitude, longitude: c.longitude),
                      sunrise: events.sunrise, sunset: events.sunset)
    }

    var isActive: Bool { Preferences.enabled && Preferences.pausedUntil == nil }

    func start() {
        engine.recapture()
        location.onUpdate = { [weak self] in self?.update(animated: true) }
        location.request()

        // Re-applying every 30 s also repairs tables that macOS or another
        // app reset behind our back.
        tick = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.update(animated: false)
        }
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                       queue: .main) { [weak self] _ in self?.displaysChanged() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self?.displaysChanged() }
            self?.location.request()
        }
        nc.addObserver(forName: UserDefaults.didChangeNotification, object: nil,
                       queue: .main) { [weak self] _ in
            guard let self, !self.ignoringDefaults else { return }
            self.update(animated: false)
        }
        update(animated: true)
    }

    func stop() {
        tick?.invalidate()
        fade?.invalidate()
        preview?.invalidate()
        engine.restore()
    }

    func target(at date: Date = Date()) -> DisplaySetting {
        isActive ? Self.status(at: date).target : .neutral
    }

    func update(animated: Bool) {
        guard !isPreviewing else { return }
        let t = target()
        if animated { fade(to: t) } else if fade == nil { set(t) }
    }

    // MARK: menu actions

    func setEnabled(_ on: Bool) {
        changePreferences { Preferences.enabled = on; if on { Preferences.pausedUntil = nil } }
    }

    func pause(for seconds: TimeInterval) {
        changePreferences { Preferences.pausedUntil = Date().addingTimeInterval(seconds) }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds + 1) { [weak self] in
            self?.update(animated: true)
        }
    }

    func resume() { changePreferences { Preferences.pausedUntil = nil } }

    /// Sweep through the next 24 hours of the schedule in 12 seconds.
    func runPreview(duration: TimeInterval = 12) {
        fade?.invalidate()
        fade = nil
        preview?.invalidate()
        isPreviewing = true
        let start = Date()
        preview = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] timer in
            guard let self else { return timer.invalidate() }
            let f = Date().timeIntervalSince(start) / duration
            if f >= 1 {
                timer.invalidate()
                self.preview = nil
                self.isPreviewing = false
                self.update(animated: true)
                return
            }
            self.set(Self.status(at: start.addingTimeInterval(f * 86_400)).target)
        }
    }

    // MARK: internals

    private func changePreferences(_ body: () -> Void) {
        ignoringDefaults = true
        body()
        ignoringDefaults = false
        update(animated: true)
    }

    private func displaysChanged() {
        engine.recapture()
        engine.apply(current)
    }

    private func set(_ s: DisplaySetting) {
        current = s
        engine.apply(s)
        onChange?()
    }

    private func fade(to target: DisplaySetting, duration: TimeInterval = 1.5) {
        fade?.invalidate()
        let from = current
        if abs(from.kelvin - target.kelvin) < 10 && abs(from.brightness - target.brightness) < 0.01 {
            fade = nil
            return set(target)
        }
        let start = Date()
        fade = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] timer in
            guard let self else { return timer.invalidate() }
            let f = min(1, Date().timeIntervalSince(start) / duration)
            let eased = f * f * (3 - 2 * f)
            self.set(DisplaySetting(kelvin: from.kelvin + (target.kelvin - from.kelvin) * eased,
                                    brightness: from.brightness + (target.brightness - from.brightness) * eased))
            if f >= 1 {
                timer.invalidate()
                self.fade = nil
            }
        }
    }
}
