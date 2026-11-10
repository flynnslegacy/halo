import SwiftUI
import HaloCore

struct WiFiPage: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.popoverActions) private var actions
    @State private var passwordFor: String?
    @State private var password = ""

    var body: some View {
        let w = monitor.wifi
        PageScaffold(title: L("Wi-Fi"), trailing: AnyView(
            Toggle("", isOn: Binding(get: { w.isPoweredOn }, set: { w.setPower($0) }))
                .toggleStyle(.switch).labelsHidden().controlSize(.small))) {
            if !w.isAvailable {
                Text(L("No Wi-Fi interface found.")).foregroundStyle(.secondary)
            } else if !w.isPoweredOn {
                Text(L("Wi-Fi is off.")).foregroundStyle(.secondary)
            } else {
                if !w.hasLocationAccess { locationNotice(w) }
                if w.isAssociated {
                    Card {
                        HStack {
                            RowIcon(symbol: "wifi", active: true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(w.ssid ?? L("Connected")).font(.system(size: 13, weight: .semibold))
                                Text(w.signalText).font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if settings.allowsConnectionSwitching {
                                Button(L("Disconnect")) { w.disconnect() }.controlSize(.small)
                                    .help(L("Disconnects from this network"))
                            }
                        }
                        DetailRow(label: L("Signal"), value: "\(w.rssi) dBm")
                        DetailRow(label: L("Transmit Rate"), value: "\(Int(w.transmitRate)) Mbps")
                        if !w.band.isEmpty { DetailRow(label: L("Band"), value: w.band) }
                    }
                }
                if w.hasLocationAccess { networkList(w) }
            }
            if let error = w.joinError {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
            }
            SystemIconToggle(icon: .wifi)
            FooterLink(title: L("Wi-Fi Settings…")) { actions.openURL(SettingsURL.wifi) }
        }
        .onAppear { w.refresh(); w.scan() }
    }

    private func locationNotice(_ w: WiFiService) -> some View {
        Card {
            Text(L("macOS treats Wi-Fi network names as location data, so Halo needs Location access to show your network's name and the networks around you."))
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if w.locationStatus == .notDetermined {
                Button(L("Allow Location Access")) { w.requestLocationAccess() }.controlSize(.small)
            } else {
                Button(L("Open Privacy Settings")) { actions.openURL(SettingsURL.locationPrivacy) }.controlSize(.small)
            }
        }
    }

    @ViewBuilder private func networkList(_ w: WiFiService) -> some View {
        let others = w.networks.filter { $0.ssid != w.ssid }
        HStack {
            SectionCaption(text: L("Networks"))
            Spacer()
            if w.isScanning { ProgressView().controlSize(.mini) }
        }
        .padding(.horizontal, 4)
        if others.isEmpty && !w.isScanning {
            Text(L("No networks found.")).font(.system(size: 12)).foregroundStyle(.secondary).padding(.horizontal, 4)
        }
        ScrollView {
            VStack(spacing: 2) {
                ForEach(others) { n in
                    VStack(spacing: 4) {
                        MetricRow(symbol: "wifi", title: n.ssid,
                                  subtitle: [n.isKnown ? L("Known") : nil, n.band.isEmpty ? nil : n.band].compactMap { $0 }.joined(separator: " · "),
                                  value: w.joiningSSID == n.ssid ? L("Joining…") : nil, showsChevron: false) {
                            tap(n, w)
                        }
                        .overlay(alignment: .trailing) {
                            if n.isSecured && w.joiningSSID != n.ssid {
                                Image(systemName: "lock.fill").font(.system(size: 10)).foregroundStyle(.secondary).padding(.trailing, 10)
                            }
                        }
                        if passwordFor == n.ssid { passwordField(n, w) }
                    }
                }
            }
        }
        .frame(maxHeight: 220)
        if !settings.allowsConnectionSwitching {
            Text(L("Turn on “Switch Wi-Fi networks and Bluetooth devices” in Halo Settings to join networks from here."))
                .font(.system(size: 10)).foregroundStyle(.tertiary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tap(_ n: WiFiNetwork, _ w: WiFiService) {
        guard settings.allowsConnectionSwitching else { actions.openURL(SettingsURL.wifi); return }
        if n.isSecured && !n.isKnown {
            password = ""
            passwordFor = n.ssid
        } else {
            w.join(n.ssid, password: nil) { ok in
                if !ok && n.isSecured { passwordFor = n.ssid }
            }
        }
    }

    private func passwordField(_ n: WiFiNetwork, _ w: WiFiService) -> some View {
        HStack {
            SecureField(L("Password"), text: $password).textFieldStyle(.roundedBorder).controlSize(.small)
                .onSubmit { join(n, w) }
            Button(L("Join")) { join(n, w) }.controlSize(.small).disabled(password.isEmpty)
        }
        .padding(.horizontal, 8)
    }

    private func join(_ n: WiFiNetwork, _ w: WiFiService) {
        let pass = password
        w.join(n.ssid, password: pass) { ok in if ok { passwordFor = nil } }
    }
}

struct BluetoothPage: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.popoverActions) private var actions

    var body: some View {
        let b = monitor.bluetooth
        PageScaffold(title: L("Bluetooth")) {
            if !b.isPoweredOn {
                Text(L("Turn Bluetooth on in Bluetooth Settings to use your devices."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            } else if b.devices.isEmpty {
                Text(L("No devices are paired with this Mac.")).font(.system(size: 12)).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(b.devices) { d in deviceRow(d, b) }
                    }
                }
                .frame(maxHeight: 300)
            }
            SystemIconToggle(icon: .bluetooth)
            FooterLink(title: L("Bluetooth Settings…")) { actions.openURL(SettingsURL.bluetooth) }
        }
        .onAppear { b.refresh() }
    }

    private func deviceRow(_ d: BluetoothDeviceInfo, _ b: BluetoothService) -> some View {
        let pending = b.pendingIDs.contains(d.id)
        let status = pending ? (d.isConnected ? L("Disconnecting…") : L("Connecting…")) : (d.isConnected ? L("Connected") : L("Not Connected"))
        return MetricRow(symbol: d.kind.symbolName, active: d.isConnected, title: d.name,
                         subtitle: batteryText(d) ?? status, value: d.battery.map { "\($0)%" },
                         showsChevron: false) {
            if settings.allowsConnectionSwitching { b.toggleConnection(d.id) } else { actions.openURL(SettingsURL.bluetooth) }
        }
        .help(settings.allowsConnectionSwitching ? (d.isConnected ? L("Click to Disconnect") : L("Click to Connect")) : "")
    }

    private func batteryText(_ d: BluetoothDeviceInfo) -> String? {
        var parts: [String] = []
        if let l = d.batteryLeft { parts.append(L("L %d%%", l)) }
        if let r = d.batteryRight { parts.append(L("R %d%%", r)) }
        if let c = d.batteryCase { parts.append(L("Case %d%%", c)) }
        return parts.isEmpty ? nil : L("Connected") + " · " + parts.joined(separator: " · ")
    }
}

struct SoundPage: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @Environment(\.popoverActions) private var actions

    var body: some View {
        let a = monitor.audio
        PageScaffold(title: L("Sound")) {
            Card {
                HStack {
                    Button { a.setMuted(!a.isMuted) } label: { Image(systemName: a.symbolName).frame(width: 22) }
                        .buttonStyle(.plain)
                    if a.canSetVolume {
                        Slider(value: Binding(get: { a.isMuted ? 0 : a.volume }, set: { a.setVolume($0) }), in: 0...1)
                    } else {
                        Text(L("This device sets its own volume.")).font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                    }
                    Text(a.isMuted ? L("Muted") : Format.percent(a.volume)).monospacedDigit().frame(width: 46, alignment: .trailing)
                }
            }
            SectionCaption(text: L("Output")).padding(.horizontal, 4)
            VStack(spacing: 2) {
                ForEach(a.outputs) { o in
                    MetricRow(symbol: o.symbolName, active: o.id == a.currentOutputID, title: o.name,
                              value: nil, showsChevron: false) { a.selectOutput(o.id) }
                        .overlay(alignment: .trailing) {
                            if o.id == a.currentOutputID {
                                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).padding(.trailing, 10)
                            }
                        }
                }
            }
            SystemIconToggle(icon: .sound)
            FooterLink(title: L("Sound Settings…")) { actions.openURL(SettingsURL.sound) }
        }
    }
}
