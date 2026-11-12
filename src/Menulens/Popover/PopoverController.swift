import AppKit
import SwiftUI
import MenulensCore

/// Which page of the popover is showing.
final class PopoverNavigation: ObservableObject {
    @Published var page: MetricKind?
}

/// Hosts the SwiftUI popover and handles click-to-open and hover-to-open.
final class PopoverController: NSObject, NSPopoverDelegate {
    private let popover = NSPopover()
    private let navigation = PopoverNavigation()
    private let monitor: SystemMonitor
    private let settings: AppSettings
    private var hoverTimer: Timer?
    private var outsideSince: Date?
    private weak var anchor: NSView?

    var onOpenPreferences: (() -> Void)?
    var onVisibilityChange: ((Bool) -> Void)?

    init(monitor: SystemMonitor, settings: AppSettings) {
        self.monitor = monitor
        self.settings = settings
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        let root = PopoverRootView(
            onOpenPreferences: { [weak self] in
                self?.close()
                self?.onOpenPreferences?()
            },
            onQuit: { NSApp.terminate(nil) },
            onOpenURL: { [weak self] url in
                self?.close()
                NSWorkspace.shared.open(url)
            },
            onOpenApp: { [weak self] bundleID in
                self?.close()
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                    NSWorkspace.shared.openApplication(at: url, configuration: .init())
                }
            })
            .environmentObject(monitor)
            .environmentObject(settings)
            .environmentObject(navigation)
        let host = NSHostingController(rootView: root)
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
    }

    var isShown: Bool { popover.isShown }

    func show(relativeTo view: NSView, page: MetricKind?, viaHover: Bool) {
        navigation.page = page
        anchor = view
        if !viaHover { NSApp.activate(ignoringOtherApps: true) }
        if !popover.isShown {
            popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        }
        popover.contentViewController?.view.window?.makeKey()
        // SwiftUI may not pick up a change made before the view is in a window; apply it again once shown.
        DispatchQueue.main.async { [weak self] in self?.navigation.page = page }
        if viaHover { startHoverTracking() }
    }

    func close() {
        popover.performClose(nil)
    }

    // MARK: - Hover-opened popovers close when the pointer leaves both the icon and the popover.

    private func startHoverTracking() {
        stopHoverTracking()
        let t = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in self?.checkPointer() }
        RunLoop.main.add(t, forMode: .common)
        hoverTimer = t
    }

    private func stopHoverTracking() {
        hoverTimer?.invalidate()
        hoverTimer = nil
        outsideSince = nil
    }

    private func checkPointer() {
        let p = NSEvent.mouseLocation
        var frames: [NSRect] = []
        if let w = popover.contentViewController?.view.window { frames.append(w.frame.insetBy(dx: -6, dy: -6)) }
        if let a = anchor, let w = a.window { frames.append(w.convertToScreen(a.convert(a.bounds, to: nil)).insetBy(dx: -2, dy: -4)) }
        if frames.contains(where: { $0.contains(p) }) {
            outsideSince = nil
        } else if let since = outsideSince {
            if Date().timeIntervalSince(since) > 0.35 { close() }
        } else {
            outsideSince = Date()
        }
    }

    // MARK: - NSPopoverDelegate

    func popoverWillShow(_ notification: Notification) {
        onVisibilityChange?(true)
    }

    func popoverDidClose(_ notification: Notification) {
        stopHoverTracking()
        onVisibilityChange?(false)
        navigation.page = nil
    }
}
