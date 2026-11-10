import SwiftUI
import HaloCore

struct VPNPage: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @Environment(\.popoverActions) private var actions

    var body: some View {
        let v = monitor.vpn
        PageScaffold(title: L("VPN")) {
            if v.hasLoaded && v.connections.isEmpty {
                Text(L("No VPN is set up on this Mac.")).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            VStack(spacing: 2) {
                ForEach(v.connections) { c in row(c, v) }
            }
            Text(L("Click a VPN to connect or disconnect it."))
                .font(.system(size: 10)).foregroundStyle(.tertiary)
            SystemIconToggle(icon: .vpn)
            FooterLink(title: L("VPN Settings…")) { actions.openURL(SettingsURL.vpn) }
        }
        .onAppear { v.refresh() }
    }

    private func row(_ c: VPNConnection, _ v: VPNService) -> some View {
        let pending = v.pendingIDs.contains(c.id) && !c.isConnected
        return MetricRow(symbol: c.isConnected ? "lock.shield.fill" : "lock.shield", active: c.isConnected,
                         title: c.name, subtitle: statusText(c, pending: pending),
                         value: nil, showsChevron: false) { v.toggle(c.id) }
            .overlay(alignment: .trailing) {
                Toggle("", isOn: Binding(get: { c.isConnected || c.status == .connecting },
                                         set: { _ in v.toggle(c.id) }))
                    .toggleStyle(.switch).labelsHidden().controlSize(.mini).padding(.trailing, 8)
            }
    }

    private func statusText(_ c: VPNConnection, pending: Bool) -> String {
        switch c.status {
        case .connected: return L("Connected")
        case .connecting: return L("Connecting…")
        case .disconnecting: return L("Disconnecting…")
        case .disconnected: return pending ? L("Connecting…") : L("Not Connected")
        case .other(let raw): return raw
        }
    }
}

/// "Show the macOS icon in the menu bar" switch, shown on the pages Halo can replace.
struct SystemIconToggle: View {
    let icon: SystemIcon
    @EnvironmentObject private var monitor: SystemMonitor

    var body: some View {
        let icons = monitor.systemIcons
        Toggle(isOn: Binding(get: { icons.isVisible(icon) }, set: { icons.setVisible(icon, $0) })) {
            Text(L("Show the macOS %@ icon in the menu bar", icon.title)).font(.system(size: 12))
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .padding(.horizontal, 8)
        .onAppear { icons.refresh() }
    }
}
