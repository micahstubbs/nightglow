import AppKit

if let code = CLI.run(Array(CommandLine.arguments.dropFirst())) {
    exit(code)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = Controller()
    private var menu: StatusMenu?
    private var settings: SettingsWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let id = Bundle.main.bundleIdentifier,
           NSRunningApplication.runningApplications(withBundleIdentifier: id).count > 1 {
            NSApp.terminate(nil)
            return
        }
        let settings = SettingsWindow(location: controller.location)
        self.settings = settings
        menu = StatusMenu(controller: controller) { settings.show() }
        controller.onChange = { [weak self] in self?.menu?.refreshIcon() }
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
