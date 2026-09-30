import CoreGraphics
import Foundation
import NightglowCore

/// Headless commands, mainly for scripting and verification.
enum CLI {
    static let usage = """
    Usage: Nightglow [--status | --gamma | --probe [KELVIN] [BRIGHTNESS] | --help]
      (no arguments)  run the menu bar app
      --status        location, sun position, today's sunrise/sunset and the target setting
      --gamma         print the top of each display's live gamma table (1 1 1 = untinted)
      --probe         apply KELVIN (default 3400) and BRIGHTNESS (default 0.8) to every
                      display for 2 s, read the gamma tables back, restore, report PASS/FAIL
    """

    /// nil means "not a CLI invocation, start the app". Finder passes
    /// single-dash arguments such as -psn_…, which are ignored.
    static func run(_ args: [String]) -> Int32? {
        guard let command = args.first(where: { $0.hasPrefix("--") }) else { return nil }
        let rest = Array(args.drop { $0 != command }.dropFirst())
        switch command {
        case "--status": return status()
        case "--gamma": return gamma()
        case "--probe":
            let kelvin = rest.first.flatMap(Double.init) ?? 3400
            let brightness = rest.dropFirst().first.flatMap(Double.init) ?? 0.8
            return probe(DisplaySetting(kelvin: kelvin, brightness: brightness))
        case "--help", "-h":
            print(usage)
            return 0
        default:
            FileHandle.standardError.write(Data("Unknown option \(command)\n\(usage)\n".utf8))
            return 2
        }
    }

    static func status() -> Int32 {
        let s = Controller.status()
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        let fmt = { (d: Date?) in d.map { f.string(from: $0) } ?? "none" }
        print(String(format: "location:   %.4f, %.4f (%@)", s.coordinate.latitude, s.coordinate.longitude, s.source))
        print(String(format: "sun:        %.2f° (%@)", s.elevation, s.phase))
        print("sunrise:    \(fmt(s.sunrise))")
        print("sunset:     \(fmt(s.sunset))")
        if let n = s.next { print("next:       \(n.kind.rawValue) at \(fmt(n.date))") }
        print(String(format: "target:     %.0f K, %.0f%% brightness", s.target.kelvin, s.target.brightness * 100))
        print("enabled:    \(Preferences.enabled)\(Preferences.pausedUntil.map { " (paused until \(fmt($0)))" } ?? "")")
        print("displays:   \(GammaEngine.onlineDisplays().count)")
        return 0
    }

    static func gamma() -> Int32 {
        for id in GammaEngine.onlineDisplays() {
            guard let r = GammaEngine.readRamp(id) else { continue }
            let top = r.red.count - 1
            print(String(format: "display %u: r=%.3f g=%.3f b=%.3f", id, r.red[top], r.green[top], r.blue[top]))
        }
        return 0
    }

    static func probe(_ setting: DisplaySetting) -> Int32 {
        let engine = GammaEngine()
        engine.recapture()
        let displays = GammaEngine.onlineDisplays()
        guard !displays.isEmpty else {
            print("FAIL: no online displays")
            return 1
        }
        let applied = engine.apply(setting)
        print(String(format: "applied %.0f K at %.0f%% to %d/%d display(s); holding 2 s",
                     setting.kelvin, setting.brightness * 100, applied, displays.count))
        Thread.sleep(forTimeInterval: 2)

        var ok = applied == displays.count
        for id in displays {
            guard let original = engine.original(for: id), let now = GammaEngine.readRamp(id) else {
                print("  display \(id): could not read gamma table")
                ok = false
                continue
            }
            let expected = original.applying(setting)
            let err = maxError(now, expected)
            let top = now.red.count - 1
            print(String(format: "  display %u: ramp top r=%.3f g=%.3f b=%.3f, max error %.4f",
                         id, now.red[top], now.green[top], now.blue[top], err))
            // Hardware tables are quantised, so allow about one 8-bit step.
            if err > 0.005 { ok = false }
        }

        engine.restore()
        for id in displays {
            if let original = engine.original(for: id), let now = GammaEngine.readRamp(id),
               maxError(now, original) > 0.005 {
                print("  display \(id): NOT restored")
                ok = false
            }
        }
        print(ok ? "PASS: tables applied and restored" : "FAIL")
        return ok ? 0 : 1
    }

    private static func maxError(_ a: GammaRamp, _ b: GammaRamp) -> Float {
        guard a.red.count == b.red.count else { return .infinity }
        return zip([a.red, a.green, a.blue], [b.red, b.green, b.blue])
            .flatMap { zip($0, $1).map { abs($0 - $1) } }
            .max() ?? 0
    }
}
