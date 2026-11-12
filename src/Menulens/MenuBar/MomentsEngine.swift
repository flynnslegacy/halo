import Foundation
import Combine
import MenulensCore

/// A short-lived state the mark shows after something happens, before stepping back.
struct Moment: Equatable {
    var center: MarkState.Center
    var ringFraction: Double?
    var ringColor: RGB?
    var badgeBolt = false
    var showsTrack = false
    var accessibilityText: String
    var duration: TimeInterval = 3
}

/// Watches transitions (plug in, low battery, AirPods, network, volume…) and emits moments.
final class MomentsEngine: ObservableObject {
    @Published private(set) var current: Moment?

    var isEnabled = true { didSet { if !isEnabled { clear() } } }

    private var bag = Set<AnyCancellable>()
    private var dismissWork: DispatchWorkItem?
    private var lastPercent: Double?
    private var lastPluggedIn: Bool?
    private var lastConnected: Bool?
    private var lastLowPower: Bool?
    private let startedAt = Date()

    private static let green = RGB(hex: 0x30D158)
    private static let yellow = RGB(hex: 0xFFD60A)

    func start(with monitor: SystemMonitor) {
        let battery = monitor.battery
        lastPercent = battery.percent
        lastPluggedIn = battery.isPluggedIn
        lastLowPower = battery.isLowPowerMode
        lastConnected = monitor.network.isConnected

        battery.$isPluggedIn.removeDuplicates().dropFirst().sink { [weak self, weak battery] plugged in
            guard let self, let battery, battery.hasBattery else { return }
            DispatchQueue.main.async { self.pluggedChanged(plugged, battery: battery) }
        }.store(in: &bag)

        battery.$percent.compactMap { $0 }.sink { [weak self, weak battery] percent in
            guard let self, let battery else { return }
            self.percentChanged(percent, discharging: !battery.isPluggedIn)
        }.store(in: &bag)

        battery.$isLowPowerMode.removeDuplicates().dropFirst().sink { [weak self, weak battery] on in
            let f = battery?.fraction
            self?.show(Moment(center: .symbol(on ? "tortoise.fill" : "hare.fill", variable: nil), ringFraction: f,
                              ringColor: on ? Self.yellow : nil,
                              accessibilityText: on ? L("Low Power Mode on.") : L("Low Power Mode off.")))
        }.store(in: &bag)

        monitor.network.$isConnected.removeDuplicates().dropFirst().sink { [weak self] connected in
            guard let self, Date().timeIntervalSince(self.startedAt) > 5 else { return }
            self.show(Moment(center: .symbol(connected ? "wifi" : "wifi.exclamationmark", variable: connected ? 1 : nil),
                             ringFraction: connected ? 1 : 0.02, ringColor: connected ? nil : Palette.critical,
                             accessibilityText: connected ? L("Network connected.") : L("Network disconnected.")))
        }.store(in: &bag)

        monitor.vpn.$connections.map { $0.contains(where: \.isConnected) }.removeDuplicates().dropFirst()
            .sink { [weak self, weak vpn = monitor.vpn] on in
                guard let self, vpn?.hasLoaded == true, Date().timeIntervalSince(self.startedAt) > 3 else { return }
                self.show(Moment(center: .symbol(on ? "lock.shield.fill" : "lock.open", variable: nil),
                                 ringFraction: on ? 1 : 0.02, ringColor: on ? Self.green : nil,
                                 accessibilityText: on ? L("VPN connected.") : L("VPN disconnected.")))
            }.store(in: &bag)

        monitor.audio.onVolumeChange = { [weak self, weak audio = monitor.audio] in
            guard let self, let audio, Date().timeIntervalSince(self.startedAt) > 2 else { return }
            let muted = audio.isMuted
            self.show(Moment(center: .symbol(audio.symbolName, variable: nil),
                             ringFraction: muted ? 0 : audio.volume, showsTrack: true,
                             accessibilityText: muted ? L("Sound muted.") : L("Sound on."), duration: 1.6))
        }

        monitor.bluetooth.onAudioDeviceConnected = { [weak self] device in
            let f = device.battery.map { Double($0) / 100 }
            self?.show(Moment(center: .symbol(device.kind.symbolName, variable: nil), ringFraction: f ?? 1,
                              accessibilityText: L("%@ connected.", device.name)))
        }
    }

    private func pluggedChanged(_ plugged: Bool, battery: BatteryService) {
        defer { lastPluggedIn = plugged }
        guard lastPluggedIn != nil, lastPluggedIn != plugged else { return }
        let f = battery.fraction
        let pct = battery.percent.map { "\(Int($0.rounded()))%" } ?? ""
        if plugged {
            show(Moment(center: .symbol("bolt.fill", variable: nil), ringFraction: f, ringColor: Self.green,
                        badgeBolt: true, accessibilityText: L("Charging, %@.", pct)))
        } else {
            show(Moment(center: .text(battery.percent.map { "\(Int($0.rounded()))" } ?? "–"), ringFraction: f,
                        accessibilityText: L("Unplugged, %@.", pct)))
        }
    }

    private func percentChanged(_ percent: Double, discharging: Bool) {
        defer { lastPercent = percent }
        guard discharging, let last = lastPercent else { return }
        for threshold in [10.0, 20.0] where last > threshold && percent <= threshold {
            show(Moment(center: .text("\(Int(threshold))"), ringFraction: percent / 100,
                        ringColor: threshold <= 10 ? Palette.critical : Palette.warning,
                        accessibilityText: L("Battery low, %d%%.", Int(percent)), duration: 5))
            return
        }
    }

    func show(_ moment: Moment) {
        guard isEnabled else { return }
        dismissWork?.cancel()
        current = moment
        let work = DispatchWorkItem { [weak self] in self?.current = nil }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + moment.duration, execute: work)
    }

    func clear() {
        dismissWork?.cancel()
        current = nil
    }
}
