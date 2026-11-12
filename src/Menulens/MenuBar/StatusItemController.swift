import AppKit
import Combine
import MenulensCore

/// Owns the status item: renders the mark, unfolds it on hover and routes clicks.
final class StatusItemController: NSResponder {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let monitor: SystemMonitor
    private let settings: AppSettings
    private let moments: MomentsEngine
    private let popover: PopoverController
    var onOpenPreferences: (() -> Void)?

    private var bag = Set<AnyCancellable>()
    private var renderScheduled = false
    private var lastRenderKey: String?
    private var appearanceObservation: NSKeyValueObservation?

    // Hover / morph state
    private var isHovering = false
    private var expandProgress: CGFloat = 0
    private var expandTarget: CGFloat = 0
    private var morphTimer: Timer?
    private var collapseWork: DispatchWorkItem?
    private var hoverPopoverWork: DispatchWorkItem?
    private var hoveredKind: MetricKind?
    private var expandedLayout: ExpandedRenderer.Layout?
    private var trackingArea: NSTrackingArea?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    init(monitor: SystemMonitor, settings: AppSettings, moments: MomentsEngine) {
        self.monitor = monitor
        self.settings = settings
        self.moments = moments
        self.popover = PopoverController(monitor: monitor, settings: settings)
        super.init()
        popover.onOpenPreferences = { [weak self] in self?.onOpenPreferences?() }
        popover.onVisibilityChange = { [weak self] open in
            self?.monitor.isPopoverOpen = open
            if open { self?.collapseNow() }
            self?.statusItem.button?.highlight(open)
        }
        configureButton()
        installHoverMonitors()
        bind()
        render()
    }

    deinit {
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var button: NSStatusBarButton? { statusItem.button }

    private var isDarkMenuBar: Bool {
        button?.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func configureButton() {
        guard let button else { return }
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageOnly
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        button.addTrackingArea(area)
        trackingArea = area
        appearanceObservation = button.observe(\.effectiveAppearance) { [weak self] _, _ in
            DispatchQueue.main.async { self?.scheduleRender() }
        }
    }

    private func bind() {
        monitor.objectWillChange.sink { [weak self] in self?.scheduleRender() }.store(in: &bag)
        moments.$current.sink { [weak self] _ in self?.scheduleRender() }.store(in: &bag)
        settings.objectWillChange.sink { [weak self] in
            self?.scheduleRender()
            DispatchQueue.main.async { self?.syncSettings() }
        }.store(in: &bag)
        syncSettings()
    }

    private func syncSettings() {
        monitor.visibleMetrics = settings.mark.visibleMetrics
        moments.isEnabled = settings.liveMoments
    }

    // MARK: - Rendering

    private func scheduleRender() {
        guard !renderScheduled else { return }
        renderScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.renderScheduled = false
            self?.render()
        }
    }

    /// The mark's state from the current readings (or the active moment).
    func currentState() -> (MarkState, StatusBand) {
        MarkStateBuilder.state(config: settings.mark, monitor: monitor, moment: moments.current)
    }

    private func expandedItems() -> [ExpandedRenderer.Item] {
        var kinds = settings.mark.expandedMetrics
        if settings.flipsExpandedIcons { kinds.reverse() }
        return kinds.map { ExpandedRenderer.Item(kind: $0, reading: monitor.reading(for: $0)) }
    }

    private func render() {
        guard let button else { return }
        let (state, band) = currentState()
        let dark = isDarkMenuBar
        let config = settings.mark
        let mark = MarkRenderer.image(for: state, config: config, band: band, darkMenuBar: dark)

        if expandProgress <= 0.001 {
            let key = "\(state)|\(config)|\(dark)|\(band)"
            guard key != lastRenderKey else { return }
            lastRenderKey = key
            expandedLayout = nil
            statusItem.length = NSStatusItem.variableLength
            button.image = mark
        } else {
            lastRenderKey = nil
            let (expanded, layout) = ExpandedRenderer.image(expandedItems(), darkMenuBar: dark, hovered: hoveredKind)
            expandedLayout = layout
            button.image = morphImage(mark: mark, expanded: expanded, progress: expandProgress)
        }
        button.setAccessibilityLabel(accessibilityText())
    }

    /// Cross-fades the mark into the unfolded icons while the width grows.
    private func morphImage(mark: NSImage, expanded: NSImage, progress: CGFloat) -> NSImage {
        let p = progress * progress * (3 - 2 * progress) // smoothstep
        let w = mark.size.width + (expanded.size.width - mark.size.width) * p
        let h = max(mark.size.height, expanded.size.height)
        return NSImage(size: NSSize(width: w, height: h), flipped: false) { rect in
            if p < 1 {
                let x = (rect.width - mark.size.width) / 2
                mark.draw(in: NSRect(x: x, y: (h - mark.size.height) / 2, width: mark.size.width, height: mark.size.height),
                          from: .zero, operation: .sourceOver, fraction: 1 - p)
            }
            if p > 0 {
                let x = (rect.width - expanded.size.width) / 2
                expanded.draw(in: NSRect(x: x, y: (h - expanded.size.height) / 2,
                                         width: expanded.size.width, height: expanded.size.height),
                              from: .zero, operation: .sourceOver, fraction: p)
            }
            return true
        }
    }

    private func accessibilityText() -> String {
        if let m = moments.current { return "Menulens. \(m.accessibilityText)" }
        let c = settings.mark
        let parts = [c.ring, c.center, c.dots].map { "\($0.title) \(Format.percent(monitor.reading(for: $0).fraction))" }
        return L("Menulens. ") + parts.joined(separator: ", ")
    }

    // MARK: - Hover

    override func mouseEntered(with event: NSEvent) { hoverBegan() }
    override func mouseExited(with event: NSEvent) { hoverEnded() }

    private func hoverBegan() {
        guard !isHovering else { return }
        isHovering = true
        collapseWork?.cancel()
        guard !popover.isShown else { return }
        switch settings.hoverAction {
        case .expand:
            animateExpand(to: 1)
        case .popover:
            let work = DispatchWorkItem { [weak self] in
                guard let self, self.isHovering, !self.popover.isShown, let button = self.button else { return }
                self.popover.show(relativeTo: button, page: nil, viaHover: true)
            }
            hoverPopoverWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
        case .nothing:
            break
        }
    }

    private func hoverEnded() {
        guard isHovering else { return }
        isHovering = false
        hoveredKind = nil
        hoverPopoverWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.animateExpand(to: 0) }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    override func mouseMoved(with event: NSEvent) { pointerMoved() }

    /// Menu bar items are hosted out of process on recent macOS, so tracking areas may not fire;
    /// global and local mouse-moved monitors compare the pointer with the button's frame instead.
    private func installHoverMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            self?.pointerMoved()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.pointerMoved()
            return event
        }
    }

    private var buttonScreenFrame: NSRect? {
        guard let button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func pointerMoved() {
        guard let frame = buttonScreenFrame else { return }
        let p = NSEvent.mouseLocation
        // Include the very top pixel row of the screen (pointer pinned against the edge).
        let inside = frame.insetBy(dx: -1, dy: -2).contains(p)
        if inside { hoverBegan() } else { hoverEnded() }
        guard inside, expandProgress >= 1, let kind = kindUnderPointer() else { return }
        if kind != hoveredKind { hoveredKind = kind; scheduleRender() }
    }

    private func collapseNow() {
        collapseWork?.cancel()
        hoveredKind = nil
        animateExpand(to: 0)
    }

    private func animateExpand(to target: CGFloat) {
        expandTarget = target
        guard morphTimer == nil else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let step: CGFloat = reduceMotion ? 1 : 1 / (0.22 * 60)
        let t = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let delta = self.expandTarget - self.expandProgress
            if abs(delta) <= step {
                self.expandProgress = self.expandTarget
                timer.invalidate()
                self.morphTimer = nil
            } else {
                self.expandProgress += delta > 0 ? step : -step
            }
            self.render()
        }
        RunLoop.main.add(t, forMode: .common)
        morphTimer = t
    }

    /// The unfolded icon under the pointer, if any.
    private func kindUnderPointer() -> MetricKind? {
        guard let button, let window = button.window, let layout = expandedLayout else { return nil }
        let point = button.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        let offset = (button.bounds.width - layout.size.width) / 2
        let x = point.x - offset
        return layout.frames.first { x >= $0.frame.minX - 2 && x <= $0.frame.maxX + 2 }?.kind
    }

    // MARK: - Clicks

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let isRight = NSApp.currentEvent?.type == .rightMouseUp
            || NSApp.currentEvent?.modifierFlags.contains(.control) == true
        if isRight && !settings.rightClickOpensPopover {
            showContextMenu()
            return
        }
        let page: MetricKind? = (expandProgress >= 1 && !isRight) ? kindUnderPointer() : nil
        if popover.isShown && page == nil {
            popover.close()
        } else {
            popover.show(relativeTo: sender, page: page, viaHover: false)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: L("Menulens Settings…"), action: #selector(openPreferences), keyEquivalent: ",").target = self
        menu.addItem(withTitle: L("Make a Donation ❤️"), action: #selector(donate), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: L("Quit Menulens"), action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
        button?.performClick(nil)
        statusItem.menu = nil
    }

    /// Opens the popover programmatically (launch argument `--open-popover [page]`).
    func openPopover(page: MetricKind?) {
        guard let button else { return }
        popover.show(relativeTo: button, page: page, viaHover: false)
    }

    @objc private func openPreferences() { onOpenPreferences?() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func donate() { Donation.open() }
}
