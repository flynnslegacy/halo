import Foundation

/// The eight readings the mark and the popover can show.
public enum MetricKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case battery, wifi, bluetooth, volume, network, memory, cpu, disk, vpn

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .battery: return L("Battery")
        case .wifi: return "Wi-Fi"
        case .bluetooth: return "Bluetooth"
        case .volume: return L("Volume")
        case .network: return L("Network")
        case .memory: return L("Memory")
        case .cpu: return "CPU"
        case .disk: return L("Disk")
        case .vpn: return "VPN"
        }
    }

    /// Title used for the popover rows.
    public var rowTitle: String {
        switch self {
        case .network: return L("Network Activity")
        case .cpu: return L("CPU Usage")
        default: return title
        }
    }

    /// SF Symbol used in pickers, rows and the center of the mark.
    public var symbolName: String {
        switch self {
        case .battery: return "battery.75percent"
        case .wifi: return "wifi"
        case .bluetooth: return "dot.radiowaves.left.and.right"
        case .volume: return "speaker.wave.2.fill"
        case .network: return "arrow.up.arrow.down"
        case .memory: return "memorychip"
        case .cpu: return "cpu"
        case .disk: return "internaldrive"
        case .vpn: return "lock.shield"
        }
    }

    /// Metrics with a natural 0...1 level can drive the ring.
    public var isSuitableForRing: Bool { true }

    /// Every metric can sit in the center (as a glyph or a number).
    public var isSuitableForCenter: Bool { true }

    /// Dots read a level in quarters.
    public var isSuitableForDots: Bool { true }

    /// For memory, CPU and disk a high level is bad; for battery a high level is good.
    public var levelSemantics: LevelSemantics {
        switch self {
        case .battery, .wifi, .volume, .bluetooth: return .higherIsBetter
        case .memory, .cpu, .disk: return .higherIsWorse
        case .network, .vpn: return .neutral
        }
    }
}

public enum LevelSemantics: Sendable {
    case higherIsBetter, higherIsWorse, neutral
}

/// Where a metric is placed on the mark.
public enum MarkSlot: String, CaseIterable, Codable, Identifiable, Sendable {
    case ring, center, dots
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .ring: return L("Ring")
        case .center: return L("Center")
        case .dots: return L("Dots")
        }
    }
}

/// A health band, used by the Automatic palette.
public enum StatusBand: Sendable, Equatable {
    case good, warning, critical, neutral
}

/// One normalized value for the mark.
public struct MetricReading: Equatable, Sendable {
    /// Level in 0...1 (nil when unavailable).
    public var fraction: Double?
    /// Short number for the center ("42", "80").
    public var shortText: String
    /// SF Symbol for the center glyph.
    public var symbolName: String
    /// Whether the center should show the number rather than the glyph.
    public var prefersText: Bool
    public var isAvailable: Bool

    public init(fraction: Double?, shortText: String, symbolName: String,
                prefersText: Bool = false, isAvailable: Bool = true) {
        self.fraction = fraction.map { min(max($0, 0), 1) }
        self.shortText = shortText
        self.symbolName = symbolName
        self.prefersText = prefersText
        self.isAvailable = isAvailable
    }

    public static func unavailable(_ kind: MetricKind) -> MetricReading {
        MetricReading(fraction: nil, shortText: "–", symbolName: kind.symbolName, isAvailable: false)
    }

    /// Number of lit dots (0...4) for this reading.
    public var litDots: Int { MetricReading.litDots(for: fraction) }

    public static func litDots(for fraction: Double?) -> Int {
        guard let f = fraction else { return 0 }
        if f <= 0 { return 0 }
        return min(4, max(1, Int((f * 4).rounded(.up))))
    }

    /// Health band for a given metric semantics.
    public func band(for semantics: LevelSemantics) -> StatusBand {
        guard let f = fraction else { return .neutral }
        switch semantics {
        case .higherIsBetter:
            if f <= 0.10 { return .critical }
            if f <= 0.20 { return .warning }
            return .good
        case .higherIsWorse:
            if f >= 0.90 { return .critical }
            if f >= 0.75 { return .warning }
            return .good
        case .neutral:
            return .good
        }
    }
}
