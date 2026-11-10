import AppKit
import SwiftUI
import Combine
import HaloCore

/// The Settings window (an agent app has no Settings scene, so it is hosted by hand).
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private var languageObserver: AnyCancellable?

    convenience init(monitor: SystemMonitor, settings: AppSettings) {
        let root = PreferencesView()
            .environmentObject(monitor)
            .environmentObject(settings)
        let host = NSHostingController(rootView: root)
        host.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: host)
        window.title = L("Halo Settings")
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
        window.delegate = self
        languageObserver = settings.$language.dropFirst().receive(on: RunLoop.main).sink { [weak window] _ in
            window?.title = L("Halo Settings")
        }
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible != true { window?.center() }
        window?.makeKeyAndOrderFront(nil)
    }
}
