import AppKit
import HaloCore

/// What the mark should draw right now (a normal state or a live moment).
struct MarkState: Equatable {
    var ringFraction: Double?
    var ringColorOverride: RGB?
    var center: Center
    var litDots: Int
    var badgeBolt = false
    /// Draws the full ring dimmed under the value (used by some moments).
    var showsTrack = false

    enum Center: Equatable {
        case symbol(String, variable: Double?)
        case text(String)
    }
}

/// Draws the mark: a 240° ring, a center glyph or number, and four dots.
enum MarkRenderer {
    static let baseSide: CGFloat = 18

    static func image(for state: MarkState, config: MarkConfiguration, band: StatusBand,
                      darkMenuBar: Bool, scale: Double? = nil) -> NSImage {
        let side = baseSide * CGFloat(scale ?? config.iconScale)
        let image = NSImage(size: NSSize(width: side, height: side), flipped: true) { rect in
            draw(state, config: config, band: band, darkMenuBar: darkMenuBar, in: rect)
            return true
        }
        image.isTemplate = false
        return image
    }

    static func foreground(dark: Bool) -> NSColor { dark ? .white : NSColor(white: 0.08, alpha: 1) }

    static func nsColor(_ c: RGB, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: alpha)
    }

    /// Draws into a flipped (y-down) rect.
    static func draw(_ state: MarkState, config: MarkConfiguration, band: StatusBand, darkMenuBar: Bool, in rect: NSRect) {
        let g = MarkGeometry(side: Double(rect.width), thickness: config.thickness)
        let fg = foreground(dark: darkMenuBar)
        let center = NSPoint(x: rect.minX + g.centerX, y: rect.minY + g.centerYFromTop)

        if state.showsTrack {
            strokeArc(center: center, radius: g.radius, from: MarkGeometry.ringStartAngle,
                      to: MarkGeometry.ringStartAngle - MarkGeometry.ringSweep, width: g.strokeWidth,
                      color: fg.withAlphaComponent(0.22))
        }
        if let f = state.ringFraction, f > 0 {
            drawRing(fraction: f, geometry: g, center: center, config: config, band: band,
                     override: state.ringColorOverride, fg: fg)
        }
        drawCenter(state.center, geometry: g, center: center, fg: fg)
        drawDots(lit: state.litDots, geometry: g, origin: rect.origin, fg: fg)
        if state.badgeBolt { drawBolt(rect: rect, fg: fg) }
    }

    // MARK: - Ring

    private static func drawRing(fraction: Double, geometry g: MarkGeometry, center: NSPoint,
                                 config: MarkConfiguration, band: StatusBand, override: RGB?, fg: NSColor) {
        let palette = config.palette
        func color(at t: Double) -> NSColor {
            if let o = override { return nsColor(o) }
            if palette.followsMenuBar {
                let alpha = config.ringStyle == .gradient ? 0.35 + 0.65 * t : 1
                return fg.withAlphaComponent(alpha)
            }
            if palette.showsStatusColors && band != .good && band != .neutral {
                return nsColor(palette.solid(for: band))
            }
            return config.ringStyle == .gradient ? nsColor(palette.color(at: t)) : nsColor(palette.solid)
        }

        switch config.ringStyle {
        case .segmented:
            let lit = MarkGeometry.litSegments(for: fraction)
            for (i, seg) in MarkGeometry.segments().enumerated() where i < lit {
                strokeArc(center: center, radius: g.radius, from: seg.start, to: seg.end,
                          width: g.strokeWidth, color: color(at: Double(i) / Double(MarkGeometry.segmentCount - 1)),
                          cap: .butt)
            }
        case .gradient where override == nil:
            // Approximate a conic gradient with short overlapping slices.
            let end = g.fillEndAngle(fraction: fraction)
            let steps = max(8, Int(fraction * 48))
            let span = (MarkGeometry.ringStartAngle - end) / Double(steps)
            for i in 0..<steps {
                let a0 = MarkGeometry.ringStartAngle - Double(i) * span
                let a1 = i == steps - 1 ? end : a0 - span * 1.15
                let t = (MarkGeometry.ringStartAngle - a0) / MarkGeometry.ringSweep
                let cap: NSBezierPath.LineCapStyle = (i == 0 || i == steps - 1) ? .round : .butt
                strokeArc(center: center, radius: g.radius, from: a0, to: a1, width: g.strokeWidth,
                          color: color(at: t), cap: cap)
            }
        default:
            strokeArc(center: center, radius: g.radius, from: MarkGeometry.ringStartAngle,
                      to: g.fillEndAngle(fraction: fraction), width: g.strokeWidth, color: color(at: 0))
        }
    }

    /// Angles in math convention; converted for the flipped context.
    static func strokeArc(center: NSPoint, radius: Double, from: Double, to: Double, width: Double,
                          color: NSColor, cap: NSBezierPath.LineCapStyle = .round) {
        let path = NSBezierPath()
        // In a flipped context, a math angle a maps to -a; clockwise in math = counter-clockwise flipped.
        path.appendArc(withCenter: center, radius: radius, startAngle: -from, endAngle: -to, clockwise: false)
        path.lineWidth = width
        path.lineCapStyle = cap
        color.setStroke()
        path.stroke()
    }

    // MARK: - Center

    private static func drawCenter(_ content: MarkState.Center, geometry g: MarkGeometry, center: NSPoint, fg: NSColor) {
        let box = g.radius * 1.38
        switch content {
        case .symbol(let name, let variable):
            let rect = NSRect(x: center.x - box / 2, y: center.y - box / 2, width: box, height: box)
            if name == "halo.bluetooth" {
                drawBluetoothRune(in: rect.insetBy(dx: box * 0.12, dy: box * 0.02), color: fg)
            } else {
                drawSymbol(name, variable: variable, in: rect, color: fg, weight: .bold)
            }
        case .text(let text):
            let size = text.count >= 3 ? g.radius * 0.72 : g.radius * 0.98
            let font = NSFont.systemFont(ofSize: size, weight: .heavy)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fg]
            let s = NSAttributedString(string: text, attributes: attrs)
            let sz = s.size()
            s.draw(at: NSPoint(x: center.x - sz.width / 2, y: center.y - sz.height / 2 + size * 0.02))
        }
    }

    static func drawSymbol(_ name: String, variable: Double?, in rect: NSRect, color: NSColor,
                           weight: NSFont.Weight = .semibold) {
        let config = NSImage.SymbolConfiguration(pointSize: rect.height * 0.8, weight: weight)
            .applying(.init(paletteColors: [color]))
        let base = variable.flatMap { NSImage(systemSymbolName: name, variableValue: $0, accessibilityDescription: nil) }
            ?? NSImage(systemSymbolName: name, accessibilityDescription: nil)
        guard let img = base?.withSymbolConfiguration(config) else { return }
        let s = img.size
        let ratio = min(rect.width / s.width, rect.height / s.height)
        let w = s.width * ratio, h = s.height * ratio
        img.draw(in: NSRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h))
    }

    /// The Bluetooth rune isn't an SF Symbol, so it is drawn by hand.
    static func drawBluetoothRune(in rect: NSRect, color: NSColor) {
        let h = rect.height, w = h * 0.55
        let x0 = rect.midX - w / 2, y0 = rect.minY
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x0 + x * w, y: y0 + y * h) }
        let path = NSBezierPath()
        path.move(to: p(0.05, 0.27))
        path.line(to: p(0.95, 0.73))
        path.line(to: p(0.5, 0.97))
        path.line(to: p(0.5, 0.03))
        path.line(to: p(0.95, 0.27))
        path.line(to: p(0.05, 0.73))
        path.lineWidth = max(1, h * 0.13)
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        color.setStroke()
        path.stroke()
    }

    // MARK: - Dots & badge

    private static func drawDots(lit: Int, geometry g: MarkGeometry, origin: NSPoint, fg: NSColor) {
        for (i, d) in g.dotCenters.enumerated() {
            let r = g.dotRadius * (i < lit ? 1 : 0.85)
            let rect = NSRect(x: origin.x + d.x - r, y: origin.y + d.y - r, width: r * 2, height: r * 2)
            (i < lit ? fg : fg.withAlphaComponent(0.38)).setFill()
            NSBezierPath(ovalIn: rect).fill()
        }
    }

    private static func drawBolt(rect: NSRect, fg: NSColor) {
        let s = rect.width * 0.36
        drawSymbol("bolt.fill", variable: nil,
                   in: NSRect(x: rect.maxX - s * 0.85, y: rect.minY - s * 0.05, width: s, height: s), color: fg)
    }
}
