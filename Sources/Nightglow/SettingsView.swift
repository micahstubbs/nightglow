import AppKit
import ServiceManagement
import SwiftUI
import NightglowCore

private let presets: [(String, Double)] = [
    ("Candle", 1900), ("Tungsten", 2700), ("Halogen", 3400), ("Fluorescent", 4200), ("Daylight", 6500),
]

struct SettingsView: View {
    let location: LocationProvider

    @AppStorage(Key.dayKelvin, store: defaults) private var dayKelvin = 6500.0
    @AppStorage(Key.nightKelvin, store: defaults) private var nightKelvin = 3400.0
    @AppStorage(Key.dayBrightness, store: defaults) private var dayBrightness = 1.0
    @AppStorage(Key.nightBrightness, store: defaults) private var nightBrightness = 1.0
    @AppStorage(Key.useManualLocation, store: defaults) private var useManual = false
    @AppStorage(Key.manualLatitude, store: defaults) private var latitude = 0.0
    @AppStorage(Key.manualLongitude, store: defaults) private var longitude = 0.0
    @AppStorage(Key.useCurrentLocation, store: defaults) private var useCurrentLocation = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var refresh = 0

    var body: some View {
        let status = Controller.status()
        Form {
            Section("Color temperature") {
                kelvinRow("Daytime", $dayKelvin, range: 4000...6500, id: "day-kelvin")
                kelvinRow("Night", $nightKelvin, range: ColorTemperature.minKelvin...6500, id: "night-kelvin")
            }
            Section("Brightness") {
                percentRow("Daytime", $dayBrightness, id: "day-brightness")
                percentRow("Night", $nightBrightness, id: "night-brightness")
            }
            Section("Location") {
                Picker("Source", selection: $useManual) {
                    Text("Automatic").tag(false)
                    Text("Manual").tag(true)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("nightglow-settings-location-source")
                if useManual {
                    TextField("Latitude", value: $latitude, format: .number.precision(.fractionLength(4)))
                        .accessibilityIdentifier("nightglow-settings-latitude")
                    TextField("Longitude", value: $longitude, format: .number.precision(.fractionLength(4)))
                        .accessibilityIdentifier("nightglow-settings-longitude")
                } else {
                    Toggle("Use Location Services (falls back to time zone)", isOn: $useCurrentLocation)
                        .accessibilityIdentifier("nightglow-settings-use-location")
                    if useCurrentLocation {
                        HStack {
                            Text("Permission: \(location.authorizationDescription)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Locate Now") { location.request(); refresh += 1 }
                                .accessibilityIdentifier("nightglow-settings-locate")
                        }
                    }
                }
                LabeledContent("Using", value: String(format: "%@ (%.3f, %.3f)", status.source,
                                                      status.coordinate.latitude, status.coordinate.longitude))
                LabeledContent("Today", value: sunText(status))
            }
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { on in setLaunchAtLogin(on) }
                    .accessibilityIdentifier("nightglow-settings-launch-at-login")
                if let loginError { Text(loginError).foregroundStyle(.red).font(.caption) }
            }
        }
        .formStyle(.grouped)
        // A grouped Form scrolls, so it has no ideal height; without this the
        // hosting window collapsed to its title bar.
        .frame(width: 460, height: 740)
        .id(refresh)
    }

    private func kelvinRow(_ label: String, _ value: Binding<Double>, range: ClosedRange<Double>, id: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Menu("\(Int(value.wrappedValue)) K") {
                    ForEach(presets.filter { range.contains($0.1) }, id: \.1) { p in
                        Button("\(p.0) (\(Int(p.1)) K)") { value.wrappedValue = p.1 }
                    }
                }
                .fixedSize()
                .accessibilityIdentifier("nightglow-settings-\(id)-presets")
            }
            Slider(value: value, in: range, step: 100)
                .accessibilityIdentifier("nightglow-settings-\(id)")
        }
    }

    private func percentRow(_ label: String, _ value: Binding<Double>, id: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%").monospacedDigit()
            }
            Slider(value: value, in: DisplaySetting.minBrightness...1, step: 0.05)
                .accessibilityIdentifier("nightglow-settings-\(id)")
        }
    }

    private func sunText(_ s: Controller.Status) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        switch (s.sunrise, s.sunset) {
        case let (r?, t?): return "Sunrise \(f.string(from: r)) · Sunset \(f.string(from: t))"
        case (nil, nil): return s.elevation > 0 ? "Midnight sun" : "Polar night"
        case let (r, t): return [r.map { "Sunrise \(f.string(from: $0))" }, t.map { "Sunset \(f.string(from: $0))" }]
            .compactMap { $0 }.joined(separator: " · ")
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Launch at login needs the installed app bundle: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

final class SettingsWindow {
    private var window: NSWindow?
    private let location: LocationProvider

    init(location: LocationProvider) { self.location = location }

    func show() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(location: location)))
            w.title = "Nightglow Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.identifier = NSUserInterfaceItemIdentifier("nightglow-settings-window")
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
