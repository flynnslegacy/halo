import Foundation

/// A color expressed as sRGB components, so the core stays UI-framework free.
public struct RGB: Equatable, Codable, Sendable {
    public var r: Double, g: Double, b: Double
    public init(_ r: Double, _ g: Double, _ b: Double) { self.r = r; self.g = g; self.b = b }
    public init(hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    public func mixed(with other: RGB, _ t: Double) -> RGB {
        let t = min(max(t, 0), 1)
        return RGB(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t)
    }
}

public enum RingStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case solid, gradient, segmented
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .solid: return L("Solid")
        case .gradient: return L("Gradient")
        case .segmented: return L("Segmented")
        }
    }
}

public enum RingThickness: String, CaseIterable, Codable, Identifiable, Sendable {
    case thin, regular, bold
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .thin: return L("Thin")
        case .regular: return L("Regular")
        case .bold: return L("Bold")
        }
    }
    /// Stroke width as a fraction of the mark's side.
    public var widthFactor: Double {
        switch self {
        case .thin: return 0.085
        case .regular: return 0.115
        case .bold: return 0.15
        }
    }
}

/// The colors of the ring.
public enum Palette: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic, monochrome, ocean, indigo, violet, rose, sunset, grass, aurora, mint, gold, crimson

    public var id: String { rawValue }

    public var title: String { L(rawValue.capitalized) }

    /// Colors along the ring (start → end) for the gradient style.
    /// The first stop is also the solid color.
    public var stops: [RGB] {
        switch self {
        case .automatic: return [RGB(hex: 0x30D158), RGB(hex: 0x30D158)]
        case .monochrome: return [RGB(hex: 0x8E8E93), RGB(hex: 0xFFFFFF)]
        case .ocean: return [RGB(hex: 0x0A84FF), RGB(hex: 0x40C8FF)]
        case .indigo: return [RGB(hex: 0x7D7AFF), RGB(hex: 0x9FA8FF)]
        case .violet: return [RGB(hex: 0xBF5AF2), RGB(hex: 0xDA8FFF)]
        case .rose: return [RGB(hex: 0x9E3B6E), RGB(hex: 0xFF6FB5)]
        case .sunset: return [RGB(hex: 0xFF9F0A), RGB(hex: 0xFF6B3D)]
        case .grass: return [RGB(hex: 0x32D74B), RGB(hex: 0x7DEB5C)]
        case .aurora: return [RGB(hex: 0x2EE6C7), RGB(hex: 0x6E9BFF), RGB(hex: 0xFF8AD8)]
        case .mint: return [RGB(hex: 0x00C7BE), RGB(hex: 0x66E6DA)]
        case .gold: return [RGB(hex: 0xFFD60A), RGB(hex: 0xFFB340)]
        case .crimson: return [RGB(hex: 0xFF375F), RGB(hex: 0xFF6961)]
        }
    }

    public var solid: RGB {
        switch self {
        case .monochrome: return RGB(hex: 0xFFFFFF)
        case .rose: return RGB(hex: 0xFF6FB5)
        default: return stops[0]
        }
    }

    /// Whether the palette follows the menu bar's foreground color.
    public var followsMenuBar: Bool { self == .monochrome }

    /// Whether the color changes with the reading's health (green / orange / red).
    public var showsStatusColors: Bool { self == .automatic }

    public static let warning = RGB(hex: 0xFF9F0A)
    public static let critical = RGB(hex: 0xFF453A)

    /// Color sampled at position `t` (0...1) along the ring.
    public func color(at t: Double) -> RGB {
        let s = stops
        guard s.count > 1 else { return s.first ?? RGB(1, 1, 1) }
        let scaled = min(max(t, 0), 1) * Double(s.count - 1)
        let i = min(Int(scaled), s.count - 2)
        return s[i].mixed(with: s[i + 1], scaled - Double(i))
    }

    /// Solid color for a given health band (Automatic only changes color).
    public func solid(for band: StatusBand) -> RGB {
        guard showsStatusColors else { return solid }
        switch band {
        case .critical: return Palette.critical
        case .warning: return Palette.warning
        default: return solid
        }
    }
}
