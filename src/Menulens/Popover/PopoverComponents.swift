import SwiftUI
import MenulensCore

/// Circle icon used at the start of every row.
struct RowIcon: View {
    let symbol: String
    var active = false
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            Circle().fill(active ? Color.accentColor : Color.primary.opacity(0.1))
            if symbol == "menulens.bluetooth" {
                BluetoothRune().stroke(active ? .white : .primary,
                                       style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                    .frame(width: size * 0.3, height: size * 0.5)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(active ? Color.white : Color.primary)
            }
        }
        .frame(width: size, height: size)
    }
}

/// The Bluetooth rune as a SwiftUI shape.
struct BluetoothRune: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
        p.move(to: pt(0.05, 0.27))
        p.addLine(to: pt(0.95, 0.73))
        p.addLine(to: pt(0.5, 0.97))
        p.addLine(to: pt(0.5, 0.03))
        p.addLine(to: pt(0.95, 0.27))
        p.addLine(to: pt(0.05, 0.73))
        return p
    }
}

/// A clickable row of the main page.
struct MetricRow: View {
    let symbol: String
    var active = false
    let title: String
    var subtitle: String?
    var value: String?
    var showsChevron = true
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                RowIcon(symbol: symbol, active: active)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    if let subtitle {
                        Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if let value {
                    Text(value).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                }
                if showsChevron {
                    Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(RoundedRectangle(cornerRadius: 8).fill(hovering ? Color.primary.opacity(0.07) : .clear))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Page layout with a back button.
struct PageScaffold<Content: View>: View {
    let title: String
    let trailing: AnyView?
    @EnvironmentObject private var navigation: PopoverNavigation
    // Content is built eagerly: a stored closure capturing the same objects would make SwiftUI skip updates.
    let content: Content

    init(title: String, trailing: AnyView? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { navigation.page = nil }
                } label: {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                Text(title).font(.system(size: 15, weight: .bold))
                Spacer()
                if let trailing { trailing }
            }
            content
        }
    }
}

/// "Label ............ value" line.
struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium).monospacedDigit()
        }
        .font(.system(size: 12))
        .padding(.vertical, 1)
    }
}

/// Grouped rounded box.
struct Card<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
    }
}

struct SectionCaption: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
    }
}

/// A filled line chart of recent values.
struct HistoryGraph: View {
    let values: [Double]
    var maxValue: Double? = nil
    var color: Color = .accentColor
    var capacity = CPUService.historyLength

    var body: some View {
        GeometryReader { geo in
            let top = max(maxValue ?? (values.max() ?? 1), 0.0001)
            let step = geo.size.width / CGFloat(max(capacity - 1, 1))
            let start = CGFloat(capacity - values.count) * step
            let points = values.enumerated().map { i, v in
                CGPoint(x: start + CGFloat(i) * step, y: geo.size.height * (1 - CGFloat(min(v / top, 1))))
            }
            ZStack {
                if let first = points.first, let last = points.last {
                    Path { p in
                        p.move(to: CGPoint(x: first.x, y: geo.size.height))
                        points.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: last.x, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [color.opacity(0.35), color.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                    Path { p in
                        p.move(to: first)
                        points.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
            }
        }
    }
}

/// Horizontal stacked bar (memory breakdown, disk usage).
struct StackedBar: View {
    let parts: [(Double, Color)]
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1.5) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    Rectangle().fill(part.1).frame(width: max(0, geo.size.width * CGFloat(part.0)))
                }
                Spacer(minLength: 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.1)))
        }
        .frame(height: 8)
    }
}

/// Link-style button at the bottom of pages ("Battery Settings…").
struct FooterLink: View {
    let title: String
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Text(title).font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .contentShape(Rectangle())
                .background(RoundedRectangle(cornerRadius: 6).fill(hovering ? Color.primary.opacity(0.07) : .clear))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

enum SettingsURL {
    static let battery = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension")!
    static let wifi = URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension")!
    static let bluetooth = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings")!
    static let sound = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!
    static let network = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension")!
    static let vpn = URL(string: "x-apple.systempreferences:com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension")!
    static let storage = URL(string: "x-apple.systempreferences:com.apple.settings.Storage")!
    static let locationPrivacy = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!
}
