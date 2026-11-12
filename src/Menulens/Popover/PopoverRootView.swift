import SwiftUI
import MenulensCore

/// Actions the popover asks its host to perform.
struct PopoverActions {
    let openURL: (URL) -> Void
    let openApp: (String) -> Void
}

private struct PopoverActionsKey: EnvironmentKey {
    static let defaultValue = PopoverActions(openURL: { NSWorkspace.shared.open($0) }, openApp: { _ in })
}

extension EnvironmentValues {
    var popoverActions: PopoverActions {
        get { self[PopoverActionsKey.self] }
        set { self[PopoverActionsKey.self] = newValue }
    }
}

struct PopoverRootView: View {
    let onOpenPreferences: () -> Void
    let onQuit: () -> Void
    let onOpenURL: (URL) -> Void
    let onOpenApp: (String) -> Void

    @EnvironmentObject private var navigation: PopoverNavigation
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Group {
            if let page = navigation.page {
                pageView(page)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                MainPage(onOpenPreferences: onOpenPreferences, onQuit: onQuit)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .padding(12)
        .frame(width: 320)
        .id(settings.language)
        .environment(\.popoverActions, PopoverActions(openURL: onOpenURL, openApp: onOpenApp))
    }

    @ViewBuilder private func pageView(_ page: MetricKind) -> some View {
        switch page {
        case .wifi: WiFiPage()
        case .bluetooth: BluetoothPage()
        case .battery: BatteryPage()
        case .network: NetworkPage()
        case .memory: MemoryPage()
        case .cpu: CPUPage()
        case .disk: DiskPage()
        case .volume: SoundPage()
        case .vpn: VPNPage()
        }
    }
}

/// The list of readings, profiles on top and settings at the bottom.
struct MainPage: View {
    let onOpenPreferences: () -> Void
    let onQuit: () -> Void

    @EnvironmentObject private var monitor: SystemMonitor
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var navigation: PopoverNavigation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if settings.showsProfilesInPopover && !settings.profiles.isEmpty {
                ProfilePicker()
                Divider().padding(.horizontal, 2)
            }
            VStack(spacing: 2) {
                ForEach(settings.visibleRows) { kind in
                    row(for: kind)
                }
            }
            Divider().padding(.horizontal, 2)
            HStack {
                FooterLink(title: L("Menulens Settings…"), action: onOpenPreferences)
                Button(action: Donation.open) {
                    Image(systemName: "heart.fill").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.pink)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L("Make a Donation ❤️"))
                Button(action: onQuit) {
                    Image(systemName: "power").font(.system(size: 12, weight: .semibold))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(L("Quit Menulens"))
            }
        }
    }

    private func open(_ kind: MetricKind) {
        withAnimation(.easeInOut(duration: 0.18)) { navigation.page = kind }
    }

    private var details: Bool { settings.showDetailsInPopover }

    @ViewBuilder private func row(for kind: MetricKind) -> some View {
        switch kind {
        case .wifi:
            let w = monitor.wifi
            MetricRow(symbol: w.isPoweredOn ? "wifi" : "wifi.slash", active: w.isPoweredOn && w.isAssociated,
                      title: L("Wi-Fi"), subtitle: details ? w.displayName : nil,
                      value: details ? nil : (w.isPoweredOn ? nil : L("Off"))) { open(.wifi) }
        case .bluetooth:
            let b = monitor.bluetooth
            let primary = b.primary
            MetricRow(symbol: "menulens.bluetooth", active: false, title: L("Bluetooth"),
                      subtitle: details ? (b.isPoweredOn ? (primary?.name ?? L("No devices connected")) : L("Off")) : nil,
                      value: primary != nil ? (primary?.battery.map { "\($0)%" } ?? L("Connected")) : nil) { open(.bluetooth) }
        case .battery:
            let bat = monitor.battery
            MetricRow(symbol: SystemMonitor.batterySymbol(bat.percent ?? 0), title: L("Battery"),
                      subtitle: details ? bat.statusText : nil,
                      value: bat.hasBattery ? Format.percent(bat.fraction) : nil) { open(.battery) }
        case .network:
            let n = monitor.network
            MetricRow(symbol: "arrow.up.arrow.down", title: L("Network Activity"),
                      subtitle: details ? "↓ \(Format.rate(n.downRate)) · ↑ \(Format.rate(n.upRate))" : nil,
                      value: n.isConnected ? Format.rate(n.downRate + n.upRate) : L("Offline")) { open(.network) }
        case .memory:
            let m = monitor.memory
            MetricRow(symbol: "memorychip", title: L("Memory"),
                      subtitle: details ? L("%@ of %@", Format.memory(m.used), Format.memory(m.total)) : nil,
                      value: Format.percent(m.fraction)) { open(.memory) }
        case .cpu:
            let c = monitor.cpu
            MetricRow(symbol: "cpu", title: L("CPU Usage"),
                      subtitle: details ? L("%@ user · %@ system", Format.percent(c.user), Format.percent(c.system)) : nil,
                      value: Format.percent(c.usage)) { open(.cpu) }
        case .disk:
            let root = monitor.disk.root
            MetricRow(symbol: "internaldrive", title: L("Disk"),
                      subtitle: details ? root.map { L("%@ free", Format.bytes($0.available)) } : nil,
                      value: root.map { Format.percent($0.fraction) }) { open(.disk) }
        case .volume:
            VolumeRow(onOpen: { open(.volume) })
        case .vpn:
            let v = monitor.vpn
            MetricRow(symbol: v.isConnected ? "lock.shield.fill" : "lock.shield", active: v.isConnected, title: L("VPN"),
                      subtitle: details ? (v.active?.name ?? (v.connections.isEmpty ? L("Not set up") : L("Not Connected"))) : nil,
                      value: v.isConnected ? L("Connected") : nil) { open(.vpn) }
        }
    }
}

/// The volume row has a live slider instead of a value.
struct VolumeRow: View {
    let onOpen: () -> Void
    @EnvironmentObject private var monitor: SystemMonitor

    var body: some View {
        let audio = monitor.audio
        HStack(alignment: .center, spacing: 10) {
            Button(action: { audio.setMuted(!audio.isMuted) }) {
                RowIcon(symbol: audio.symbolName)
            }
            .buttonStyle(.plain)
            .help(audio.isMuted ? L("Unmute") : L("Mute"))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Button(action: onOpen) {
                        HStack(spacing: 4) {
                            Text(L("Volume")).font(.system(size: 13, weight: .semibold))
                            Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(audio.isMuted ? L("Muted") : Format.percent(audio.volume))
                        .font(.system(size: 13, weight: .semibold)).monospacedDigit()
                }
                if audio.canSetVolume {
                    Slider(value: Binding(get: { audio.isMuted ? 0 : audio.volume },
                                          set: { audio.setVolume($0) }), in: 0...1)
                        .controlSize(.small)
                } else {
                    Text(L("This device sets its own volume.")).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}

/// Segmented buttons to switch profile.
struct ProfilePicker: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionCaption(text: L("Profile")).padding(.horizontal, 4)
            HStack(spacing: 6) {
                ForEach(settings.profiles) { profile in
                    let selected = settings.activeProfileID == profile.id
                    Button { settings.apply(profile) } label: {
                        VStack(spacing: 3) {
                            Image(systemName: profile.symbolName).font(.system(size: 13, weight: .semibold))
                            Text(profile.name).font(.system(size: 11, weight: .semibold)).lineLimit(1)
                        }
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(selected ? Color.accentColor : Color.primary.opacity(0.08)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
