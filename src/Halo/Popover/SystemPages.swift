import SwiftUI
import HaloCore

struct BatteryPage: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @Environment(\.popoverActions) private var actions

    var body: some View {
        let b = monitor.battery
        PageScaffold(title: L("Battery")) {
            if b.hasBattery {
                HStack(alignment: .firstTextBaseline) {
                    Text(Format.percent(b.fraction)).font(.system(size: 30, weight: .bold)).monospacedDigit()
                    Text(b.statusText).foregroundStyle(.secondary)
                    Spacer()
                    if b.isCharging { Image(systemName: "bolt.fill").foregroundStyle(.green) }
                }
                StackedBar(parts: [(b.fraction ?? 0, (b.fraction ?? 0) <= 0.2 ? .red : .green)])
                Card {
                    if b.isCharging || (b.isPluggedIn && !b.isFullyCharged) {
                        DetailRow(label: L("Time to Full Charge"),
                                  value: b.minutesToFull.map { Format.duration(minutes: $0) } ?? L("Estimating time remaining"))
                    } else if !b.isPluggedIn {
                        DetailRow(label: L("Time Remaining"),
                                  value: b.minutesToEmpty.map { Format.duration(minutes: $0) } ?? L("Estimating time remaining"))
                    }
                    DetailRow(label: L("Power Source"), value: b.powerSourceText)
                    DetailRow(label: L("Low Power Mode"), value: b.isLowPowerMode ? "On" : L("Off"))
                }
                Card {
                    DetailRow(label: L("Maximum Capacity"), value: b.maximumCapacity.map { "\(Int($0.rounded()))%" } ?? "–")
                    DetailRow(label: L("Cycle Count"), value: b.cycleCount.map(String.init) ?? "–")
                    if let condition = b.condition { DetailRow(label: L("Condition"), value: condition) }
                }
            } else {
                Text(L("This Mac has no battery.")).foregroundStyle(.secondary)
                Card { DetailRow(label: L("Power Source"), value: L("Power Adapter")) }
            }
            SystemIconToggle(icon: .battery)
            FooterLink(title: L("Battery Settings…")) { actions.openURL(SettingsURL.battery) }
        }
    }
}

struct NetworkPage: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @Environment(\.popoverActions) private var actions

    var body: some View {
        let n = monitor.network
        let top = max(n.downHistory.max() ?? 0, n.upHistory.max() ?? 0, 10_000)
        PageScaffold(title: L("Network Activity")) {
            HStack(spacing: 16) {
                rate(symbol: "arrow.down", label: L("Download"), value: n.downRate, color: .blue)
                rate(symbol: "arrow.up", label: L("Upload"), value: n.upRate, color: .orange)
            }
            Card {
                SectionCaption(text: L("Last minute"))
                ZStack {
                    HistoryGraph(values: n.downHistory, maxValue: top, color: .blue)
                    HistoryGraph(values: n.upHistory, maxValue: top, color: .orange)
                }
                .frame(height: 70)
                HStack {
                    Text(L("Peak %@", Format.rate(top))).font(.system(size: 10)).foregroundStyle(.secondary)
                    Spacer()
                }
            }
            Card {
                DetailRow(label: L("Connection"), value: n.linkText)
                DetailRow(label: L("Received since startup"), value: Format.bytes(n.totalReceived))
                DetailRow(label: L("Sent since startup"), value: Format.bytes(n.totalSent))
            }
            FooterLink(title: L("Network Settings…")) { actions.openURL(SettingsURL.network) }
        }
    }

    private func rate(symbol: String, label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
                Text(Format.rate(value)).font(.system(size: 15, weight: .semibold)).monospacedDigit()
            }
        }
    }
}

struct CPUPage: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @Environment(\.popoverActions) private var actions

    var body: some View {
        let c = monitor.cpu
        PageScaffold(title: L("CPU Usage")) {
            HStack(alignment: .firstTextBaseline) {
                Text(Format.percent(c.usage)).font(.system(size: 30, weight: .bold)).monospacedDigit()
                Text(L("%@ user · %@ system", Format.percent(c.user), Format.percent(c.system))).foregroundStyle(.secondary)
            }
            Card {
                SectionCaption(text: L("Last minute"))
                HistoryGraph(values: c.history, maxValue: 1, color: .accentColor).frame(height: 60)
            }
            Card {
                DetailRow(label: L("Load Averages"), value: c.loadAverages.map { String(format: "%.2f", $0) }.joined(separator: "  "))
                DetailRow(label: L("Cores"), value: "\(c.coreCount)")
                DetailRow(label: L("Thermal State"), value: c.thermalText)
                DetailRow(label: L("Uptime"), value: Format.uptime(seconds: c.uptime))
            }
            FooterLink(title: L("Activity Monitor…")) { actions.openApp("com.apple.ActivityMonitor") }
        }
    }
}

struct MemoryPage: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @Environment(\.popoverActions) private var actions

    var body: some View {
        let m = monitor.memory
        let t = max(m.total, 1)
        PageScaffold(title: L("Memory")) {
            HStack(alignment: .firstTextBaseline) {
                Text(Format.percent(m.fraction)).font(.system(size: 30, weight: .bold)).monospacedDigit()
                Text(L("%@ of %@", Format.memory(m.used), Format.memory(m.total))).foregroundStyle(.secondary)
            }
            StackedBar(parts: [(m.app / t, .blue), (m.wired / t, .orange), (m.compressed / t, .purple), (m.cached / t, .gray.opacity(0.5))])
            Card {
                legend(L("App Memory"), m.app, .blue)
                legend(L("Wired Memory"), m.wired, .orange)
                legend(L("Compressed"), m.compressed, .purple)
                legend(L("Cached Files"), m.cached, .gray.opacity(0.5))
                Divider()
                DetailRow(label: L("Swap Used"), value: Format.memory(m.swapUsed))
            }
            Card {
                SectionCaption(text: L("Last minute"))
                HistoryGraph(values: m.history, maxValue: 1, color: .blue).frame(height: 44)
            }
            FooterLink(title: L("Activity Monitor…")) { actions.openApp("com.apple.ActivityMonitor") }
        }
    }

    private func legend(_ label: String, _ value: Double, _ color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            DetailRow(label: label, value: Format.memory(value))
        }
    }
}

struct DiskPage: View {
    @EnvironmentObject private var monitor: SystemMonitor
    @Environment(\.popoverActions) private var actions

    var body: some View {
        PageScaffold(title: L("Disk")) {
            if monitor.disk.volumes.isEmpty {
                Text(L("Storage information isn't available.")).foregroundStyle(.secondary)
            }
            ForEach(monitor.disk.volumes) { v in
                Card {
                    HStack {
                        Image(systemName: v.isInternal ? "internaldrive" : "externaldrive.fill")
                        Text(v.name).font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text(Format.percent(v.fraction)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                    }
                    StackedBar(parts: [(v.fraction, v.fraction > 0.9 ? .red : .accentColor)])
                    Text(L("%@ free of %@", Format.bytes(v.available), Format.bytes(v.total)))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            FooterLink(title: L("Storage Settings…")) { actions.openURL(SettingsURL.storage) }
        }
        .onAppear { monitor.disk.refresh() }
    }
}
