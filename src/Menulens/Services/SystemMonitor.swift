import Foundation
import Combine
import MenulensCore

/// Owns every service, decides what to sample, and turns state into mark readings.
final class SystemMonitor: ObservableObject {
    let battery = BatteryService()
    let cpu = CPUService()
    let memory = MemoryService()
    let disk = DiskService()
    let network = NetworkService()
    let wifi = WiFiService()
    let bluetooth = BluetoothService()
    let audio = AudioService()
    let vpn = VPNService()
    let systemIcons = SystemIconsService()

    /// Metrics on the mark (only those are sampled while the popover is closed).
    var visibleMetrics: Set<MetricKind> = [] { didSet { reschedule() } }
    var isPopoverOpen = false { didSet { reschedule(); if isPopoverOpen { sampleNow(all: true) } } }

    private var timer: Timer?
    private var tick = 0
    private var bag = Set<AnyCancellable>()

    init() {
        let publishers: [ObservableObjectPublisher] = [
            battery.objectWillChange, cpu.objectWillChange, memory.objectWillChange, disk.objectWillChange,
            network.objectWillChange, wifi.objectWillChange, bluetooth.objectWillChange, audio.objectWillChange,
            vpn.objectWillChange, systemIcons.objectWillChange
        ]
        Publishers.MergeMany(publishers)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &bag)
    }

    private var needsContinuousSampling: Bool {
        isPopoverOpen || !visibleMetrics.isDisjoint(with: [.cpu, .network, .memory, .disk, .bluetooth, .vpn])
    }

    private func reschedule() {
        if needsContinuousSampling {
            guard timer == nil else { return }
            sampleNow(all: isPopoverOpen)
            let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.timerFired() }
            t.tolerance = 0.2
            RunLoop.main.add(t, forMode: .common)
            timer = t
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    private func timerFired() {
        tick += 1
        sampleNow(all: isPopoverOpen)
    }

    func sampleNow(all: Bool) {
        let wanted = all ? Set(MetricKind.allCases) : visibleMetrics
        if wanted.contains(.cpu) || all { cpu.sample() }
        if wanted.contains(.network) || all { network.sample() }
        if wanted.contains(.memory) || all { memory.sample() }
        if wanted.contains(.disk) && tick % (all ? 5 : 30) == 0 { disk.refresh() }
        if wanted.contains(.bluetooth) && (all || tick % 10 == 0) { bluetooth.refresh() }
        if all && tick % 5 == 0 { wifi.refresh() }
        if (wanted.contains(.vpn) || all) && (vpn.isBusy || tick % (all ? 3 : 5) == 0) { vpn.refresh() }
    }

    // MARK: - Readings

    func reading(for kind: MetricKind) -> MetricReading {
        switch kind {
        case .battery:
            guard battery.hasBattery, let p = battery.percent else { return .unavailable(.battery) }
            return MetricReading(fraction: p / 100, shortText: "\(Int(p.rounded()))",
                                 symbolName: battery.isCharging ? "bolt.fill" : Self.batterySymbol(p),
                                 prefersText: true)
        case .wifi:
            if !wifi.isAvailable { return .unavailable(.wifi) }
            if !wifi.isPoweredOn { return MetricReading(fraction: 0, shortText: L("Off"), symbolName: "wifi.slash") }
            if !wifi.isAssociated {
                let symbol = network.link == .wired ? "cable.connector.horizontal" : "wifi.exclamationmark"
                return MetricReading(fraction: network.isConnected ? 1 : 0, shortText: "–", symbolName: symbol)
            }
            let f = WiFiService.signalFraction(rssi: wifi.rssi)
            return MetricReading(fraction: f, shortText: "\(Int(f * 100))", symbolName: "wifi")
        case .bluetooth:
            guard bluetooth.isPoweredOn else { return MetricReading(fraction: 0, shortText: L("Off"), symbolName: "menulens.bluetooth") }
            let primary = bluetooth.primary
            let text = primary?.battery.map(String.init) ?? "\(bluetooth.connected.count)"
            return MetricReading(fraction: bluetooth.fraction, shortText: text, symbolName: "menulens.bluetooth")
        case .volume:
            let v = audio.isMuted ? 0 : audio.volume
            return MetricReading(fraction: v, shortText: "\(Int((v * 100).rounded()))", symbolName: audio.symbolName)
        case .network:
            let rate = network.downRate + network.upRate
            let symbol = network.isConnected ? "arrow.up.arrow.down" : "wifi.exclamationmark"
            return MetricReading(fraction: network.fraction, shortText: Self.compactRate(rate), symbolName: symbol)
        case .memory:
            let f = memory.fraction
            return MetricReading(fraction: f, shortText: "\(Int((f * 100).rounded()))", symbolName: "memorychip", prefersText: true)
        case .cpu:
            let f = cpu.usage
            return MetricReading(fraction: f, shortText: "\(Int((f * 100).rounded()))", symbolName: "cpu", prefersText: true)
        case .vpn:
            if vpn.isConnected {
                return MetricReading(fraction: 1, shortText: L("VPN"), symbolName: "lock.shield.fill")
            }
            let busy = vpn.isBusy
            return MetricReading(fraction: busy ? 0.5 : 0, shortText: busy ? "…" : L("Off"),
                                 symbolName: busy ? "lock.rotation" : "lock.open")
        case .disk:
            guard let root = disk.root else { return .unavailable(.disk) }
            return MetricReading(fraction: root.fraction, shortText: "\(Int((root.fraction * 100).rounded()))",
                                 symbolName: "internaldrive", prefersText: true)
        }
    }

    static func batterySymbol(_ percent: Double) -> String {
        switch percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }

    /// "12K", "3M" — fits in the center of the mark.
    static func compactRate(_ bytesPerSecond: Double) -> String {
        let kb = bytesPerSecond / 1000
        if kb < 1 { return "0" }
        if kb < 1000 { return "\(Int(kb))K" }
        let mb = kb / 1000
        return mb < 10 ? String(format: "%.1fM", mb) : "\(Int(mb))M"
    }
}

