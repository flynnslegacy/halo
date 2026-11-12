import Foundation

/// Pure geometry of the mark: a 240° ring open at the bottom, with four dots
/// sitting on the same circle inside the gap. Angles are in degrees, math
/// convention (0° = right, counter-clockwise positive, y pointing up).
public struct MarkGeometry: Equatable, Sendable {
    public static let ringStartAngle: Double = 210
    public static let ringSweep: Double = 240
    public static let dotAngles: [Double] = [232.5, 257.5, 282.5, 307.5]
    public static let segmentCount = 10
    /// Gap between segments, in degrees.
    public static let segmentGap: Double = 7

    public let side: Double
    public let strokeWidth: Double
    public let dotRadius: Double
    public let radius: Double
    /// Center of the circle, y measured from the top (y-down).
    public let centerX: Double
    public let centerYFromTop: Double

    public init(side: Double, thickness: RingThickness) {
        self.side = side
        let w = side * thickness.widthFactor
        let dr = max(side * 0.062, w * 0.52)
        let sinDot = sin(77.5 * .pi / 180)
        let rh = (side - w) / 2
        let rv = (side - w / 2 - dr) / (1 + sinDot)
        let r = min(rh, rv)
        strokeWidth = w
        dotRadius = dr
        radius = r
        centerX = side / 2
        let used = w / 2 + r + r * sinDot + dr
        centerYFromTop = (side - used) / 2 + w / 2 + r
    }

    /// End angle for a filled fraction (the ring runs clockwise from the start angle).
    public func fillEndAngle(fraction: Double) -> Double {
        MarkGeometry.ringStartAngle - MarkGeometry.ringSweep * min(max(fraction, 0), 1)
    }

    /// Dot centers in y-down coordinates, left to right.
    public var dotCenters: [(x: Double, y: Double)] {
        MarkGeometry.dotAngles.map { a in
            let rad = a * .pi / 180
            return (centerX + radius * cos(rad), centerYFromTop - radius * sin(rad))
        }
    }

    /// Segment arcs (start, end) in degrees, clockwise order.
    public static func segments() -> [(start: Double, end: Double)] {
        let n = Double(segmentCount)
        let each = (ringSweep - segmentGap * (n - 1)) / n
        return (0..<segmentCount).map { i in
            let s = ringStartAngle - Double(i) * (each + segmentGap)
            return (s, s - each)
        }
    }

    /// How many segments are lit for a fraction.
    public static func litSegments(for fraction: Double) -> Int {
        let f = min(max(fraction, 0), 1)
        if f <= 0 { return 0 }
        return max(1, Int((f * Double(segmentCount)).rounded()))
    }
}
