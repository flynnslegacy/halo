import AppKit
import MenulensCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var monitor: SystemMonitor!
    private var moments: MomentsEngine!
    private var statusController: StatusItemController!
    private var preferences: PreferencesWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let settings = AppSettings.shared
        monitor = SystemMonitor()
        moments = MomentsEngine()
        moments.start(with: monitor)
        preferences = PreferencesWindowController(monitor: monitor, settings: settings)
        statusController = StatusItemController(monitor: monitor, settings: settings, moments: moments)
        statusController.onOpenPreferences = { [weak self] in self?.preferences.show() }

        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--open-popover") {
            let page = i + 1 < args.count ? MetricKind(rawValue: args[i + 1]) : nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.statusController.openPopover(page: page)
            }
        }
    }

    /// Re-opening the app from Finder or Spotlight opens Settings, since there is no Dock icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        preferences.show()
        return true
    }
}
