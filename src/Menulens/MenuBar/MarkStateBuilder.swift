import Foundation
import MenulensCore

/// Turns readings (or a live moment) into what the mark draws.
enum MarkStateBuilder {
    static func state(config: MarkConfiguration, monitor: SystemMonitor, moment: Moment?) -> (MarkState, StatusBand) {
        let ring = monitor.reading(for: config.ring)
        let center = monitor.reading(for: config.center)
        let dots = monitor.reading(for: config.dots)
        let band = ring.band(for: config.ring.levelSemantics)
        if let m = moment {
            return (MarkState(ringFraction: m.ringFraction, ringColorOverride: m.ringColor, center: m.center,
                              litDots: dots.litDots, badgeBolt: m.badgeBolt, showsTrack: m.showsTrack), band)
        }
        let badge = config.ring == .battery && monitor.battery.isCharging && config.center != .battery
        return (MarkState(ringFraction: ring.fraction, center: centerContent(center),
                          litDots: dots.litDots, badgeBolt: badge), band)
    }

    static func centerContent(_ reading: MetricReading) -> MarkState.Center {
        if reading.prefersText && reading.isAvailable { return .text(reading.shortText) }
        let variable: Double? = reading.symbolName == "wifi" ? reading.fraction : nil
        return .symbol(reading.symbolName, variable: variable)
    }

    /// A synthetic state for previews ("at a low level", "at a high level").
    static func previewState(config: MarkConfiguration, monitor: SystemMonitor, level: Double) -> (MarkState, StatusBand) {
        var center = monitor.reading(for: config.center)
        if center.prefersText { center.shortText = "\(Int(level * 100))" }
        if center.symbolName == "wifi" { center.fraction = level }
        let reading = MetricReading(fraction: level, shortText: "", symbolName: "")
        return (MarkState(ringFraction: level, center: centerContent(center),
                          litDots: MetricReading.litDots(for: level)),
                reading.band(for: config.ring.levelSemantics))
    }
}
