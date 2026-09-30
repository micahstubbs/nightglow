import AppKit
import NightglowCore

/// The menu bar item. The menu is rebuilt each time it opens so the
/// numbers are always current.
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let controller: Controller
    private let openSettings: () -> Void

    init(controller: Controller, openSettings: @escaping () -> Void) {
        self.controller = controller
        self.openSettings = openSettings
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        item.button?.setAccessibilityIdentifier("nightglow-status-item")
        refreshIcon()
    }

    func refreshIcon() {
        let symbol: String
        if !controller.isActive {
            symbol = "circle.slash"
        } else {
            switch Controller.status().phase {
            case "Day": symbol = "sun.max"
            case "Night": symbol = "moon.stars"
            default: symbol = "sunset"
            }
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Nightglow")
        image?.isTemplate = true
        item.button?.image = image
        item.button?.toolTip = "Nightglow \(Int(controller.current.kelvin)) K"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let s = Controller.status()
        let now = controller.current
        let time = DateFormatter()
        time.timeStyle = .short
        time.dateStyle = .none

        func info(_ title: String, _ id: String) {
            let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            i.isEnabled = false
            i.identifier = NSUserInterfaceItemIdentifier(id)
            menu.addItem(i)
        }

        info("\(Int(now.kelvin.rounded())) K · \(Int((now.brightness * 100).rounded()))% · \(controller.isActive ? s.phase : "Off")",
             "nightglow-menu-current")
        var sun = String(format: "Sun %.1f°", s.elevation)
        if let next = s.next { sun += " · \(next.kind == .sunset ? "Sunset" : "Sunrise") \(time.string(from: next.date))" }
        info(sun, "nightglow-menu-sun")
        info(String(format: "%@ · %.2f, %.2f", s.source, s.coordinate.latitude, s.coordinate.longitude),
             "nightglow-menu-location")
        if let paused = Preferences.pausedUntil, Preferences.enabled {
            info("Paused until \(time.string(from: paused))", "nightglow-menu-paused")
        }
        menu.addItem(.separator())

        let enabled = add(menu, "Enabled", #selector(toggleEnabled), "e", "nightglow-menu-enabled")
        enabled.state = Preferences.enabled ? .on : .off
        if Preferences.pausedUntil != nil {
            add(menu, "Resume Now", #selector(resume), "", "nightglow-menu-resume")
        } else if Preferences.enabled {
            add(menu, "Disable for an Hour", #selector(pauseHour), "", "nightglow-menu-pause")
        }
        add(menu, "Preview 24 Hours", #selector(preview), "p", "nightglow-menu-preview")
        menu.addItem(.separator())
        add(menu, "Settings…", #selector(settings), ",", "nightglow-menu-settings")
        let quit = NSMenuItem(title: "Quit Nightglow", action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        quit.identifier = NSUserInterfaceItemIdentifier("nightglow-menu-quit")
        menu.addItem(quit)
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String, _ id: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        i.identifier = NSUserInterfaceItemIdentifier(id)
        menu.addItem(i)
        return i
    }

    @objc private func toggleEnabled() { controller.setEnabled(!Preferences.enabled) }
    @objc private func pauseHour() { controller.pause(for: 3600) }
    @objc private func resume() { controller.resume() }
    @objc private func preview() { controller.runPreview() }
    @objc private func settings() { openSettings() }
}
