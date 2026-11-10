import Foundation

/// What the ring, center and dots show, and how the mark looks.
public struct MarkConfiguration: Codable, Equatable, Sendable {
    public var ring: MetricKind
    public var center: MetricKind
    public var dots: MetricKind
    public var palette: Palette
    public var ringStyle: RingStyle
    public var thickness: RingThickness
    /// Icon scale relative to the default size (0.8...1.25).
    public var iconScale: Double

    public init(ring: MetricKind = .battery, center: MetricKind = .wifi, dots: MetricKind = .memory,
                palette: Palette = .automatic, ringStyle: RingStyle = .solid,
                thickness: RingThickness = .regular, iconScale: Double = 1.0) {
        self.ring = ring
        self.center = center
        self.dots = dots
        self.palette = palette
        self.ringStyle = ringStyle
        self.thickness = thickness
        self.iconScale = iconScale
    }

    public static let `default` = MarkConfiguration()

    public func metric(for slot: MarkSlot) -> MetricKind {
        switch slot {
        case .ring: return ring
        case .center: return center
        case .dots: return dots
        }
    }

    public mutating func set(_ metric: MetricKind, for slot: MarkSlot) {
        switch slot {
        case .ring: ring = metric
        case .center: center = metric
        case .dots: dots = metric
        }
    }

    /// The metrics currently visible on the mark (only those are sampled).
    public var visibleMetrics: Set<MetricKind> { [ring, center, dots] }

    /// Metrics shown when the icon unfolds on hover, in display order.
    public var expandedMetrics: [MetricKind] {
        var seen = Set<MetricKind>()
        return [dots, center, ring].filter { seen.insert($0).inserted }
    }
}

/// A saved setup the user can switch to from the popover.
public struct Profile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var symbolName: String
    public var configuration: MarkConfiguration

    public init(id: UUID = UUID(), name: String, symbolName: String, configuration: MarkConfiguration) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.configuration = configuration
    }

    /// The three starter profiles.
    public static func starters(basedOn base: MarkConfiguration) -> [Profile] {
        var work = base
        work.ring = .cpu; work.center = .wifi; work.dots = .memory
        var travel = base
        travel.ring = .battery; travel.center = .wifi; travel.dots = .disk
        var minimal = base
        minimal.ring = .battery; minimal.center = .battery; minimal.dots = .memory
        return [
            Profile(name: L("Work"), symbolName: "desktopcomputer", configuration: work),
            Profile(name: L("Travel"), symbolName: "airplane", configuration: travel),
            Profile(name: L("Minimal"), symbolName: "circle", configuration: minimal)
        ]
    }

    public static let symbolChoices = [
        "desktopcomputer", "laptopcomputer", "airplane", "circle", "house", "briefcase",
        "gamecontroller", "moon", "bolt", "leaf", "music.note", "cup.and.saucer"
    ]
}
