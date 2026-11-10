import SwiftUI
import HaloCore

struct AppearanceTab: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: SystemMonitor

    var body: some View {
        Form {
            Section {
                MarkPreview()
                    .accessibilityLabel(L("Preview of the mark: now, at a low level, and at a high level"))
            }
            Section(L("Make it yours")) {
                ForEach(MarkSlot.allCases) { slot in
                    SlotPicker(slot: slot)
                }
            }
            Section(L("Color")) {
                PaletteGrid()
                Picker(L("Ring style"), selection: $settings.mark.ringStyle) {
                    ForEach(RingStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker(L("Thickness"), selection: $settings.mark.thickness) {
                    ForEach(RingThickness.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Text(L("Icon size"))
                    Slider(value: $settings.mark.iconScale, in: 0.8...1.25, step: 0.05) {
                        EmptyView()
                    } minimumValueLabel: {
                        Image(systemName: "circle").font(.system(size: 8))
                    } maximumValueLabel: {
                        Image(systemName: "circle").font(.system(size: 13))
                    }
                }
            }
            Section {
                Button(L("Reset to Default Mark")) { settings.mark = .default }
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: 560)
    }
}

/// Three large marks on a menu-bar-like background.
struct MarkPreview: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: SystemMonitor

    var body: some View {
        HStack(spacing: 28) {
            item(L("Now"), MarkStateBuilder.state(config: settings.mark, monitor: monitor, moment: nil))
            item(L("Low"), MarkStateBuilder.previewState(config: settings.mark, monitor: monitor, level: 0.12))
            item(L("High"), MarkStateBuilder.previewState(config: settings.mark, monitor: monitor, level: 0.92))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 12).fill(
            LinearGradient(colors: [Color(red: 0.07, green: 0.07, blue: 0.13), Color(red: 0.13, green: 0.12, blue: 0.3)],
                           startPoint: .top, endPoint: .bottom)))
    }

    private func item(_ label: String, _ s: (MarkState, StatusBand)) -> some View {
        VStack(spacing: 8) {
            Image(nsImage: MarkRenderer.image(for: s.0, config: settings.mark, band: s.1, darkMenuBar: true, scale: 4))
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.7))
        }
    }
}

/// Row of eight metric buttons for one slot.
struct SlotPicker: View {
    let slot: MarkSlot
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack {
            Text(slot.title).frame(width: 56, alignment: .leading)
            HStack(spacing: 6) {
                ForEach(MetricKind.allCases) { kind in
                    let selected = settings.mark.metric(for: slot) == kind
                    Button { settings.mark.set(kind, for: slot) } label: {
                        Group {
                            if kind == .bluetooth {
                                BluetoothRune().stroke(selected ? Color.white : Color.primary,
                                                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                                    .frame(width: 8, height: 14)
                            } else {
                                Image(systemName: kind.symbolName).font(.system(size: 13, weight: .semibold))
                            }
                        }
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .frame(width: 34, height: 30)
                        .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor : Color.primary.opacity(0.08)))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(kind.title)
                }
            }
        }
    }
}

/// Swatches for every palette, drawn as small marks.
struct PaletteGrid: View {
    @EnvironmentObject private var settings: AppSettings
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Palette.allCases) { palette in
                let selected = settings.mark.palette == palette
                Button { settings.mark.palette = palette } label: {
                    VStack(spacing: 4) {
                        Image(nsImage: swatch(palette))
                            .padding(6)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.1, green: 0.1, blue: 0.18)))
                            .overlay(RoundedRectangle(cornerRadius: 10)
                                .stroke(selected ? Color.accentColor : .clear, lineWidth: 2.5))
                        Text(palette.title).font(.system(size: 10, weight: selected ? .semibold : .regular))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func swatch(_ palette: Palette) -> NSImage {
        var config = settings.mark
        config.palette = palette
        let state = MarkState(ringFraction: 1, center: .symbol("wifi", variable: 1), litDots: 4)
        return MarkRenderer.image(for: state, config: config, band: .good, darkMenuBar: true, scale: 2)
    }
}
