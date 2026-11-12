import AppKit
import MenulensCore

/// Draws the unfolded state: one classic menu bar icon per metric of the mark.
enum ExpandedRenderer {
    struct Item {
        let kind: MetricKind
        let reading: MetricReading
    }

    struct Layout {
        let size: NSSize
        let frames: [(kind: MetricKind, frame: NSRect)]
    }

    static let height: CGFloat = 22
    static let spacing: CGFloat = 4
    static let padding: CGFloat = 5

    private static var font: NSFont { .systemFont(ofSize: 13, weight: .semibold) }

    static func layout(_ items: [Item]) -> Layout {
        var x: CGFloat = 0
        var frames: [(MetricKind, NSRect)] = []
        for item in items {
            let w = width(of: item) + padding * 2
            frames.append((item.kind, NSRect(x: x, y: 0, width: w, height: height)))
            x += w + spacing
        }
        return Layout(size: NSSize(width: max(0, x - spacing), height: height), frames: frames)
    }

    static func image(_ items: [Item], darkMenuBar: Bool, hovered: MetricKind?) -> (NSImage, Layout) {
        let layout = layout(items)
        let fg = MarkRenderer.foreground(dark: darkMenuBar)
        let img = NSImage(size: layout.size, flipped: true) { _ in
            for (item, slot) in zip(items, layout.frames) {
                if slot.kind == hovered {
                    fg.withAlphaComponent(0.16).setFill()
                    NSBezierPath(roundedRect: slot.frame.insetBy(dx: 0, dy: 1), xRadius: 6, yRadius: 6).fill()
                }
                draw(item, in: slot.frame.insetBy(dx: padding, dy: 0), fg: fg)
            }
            return true
        }
        return (img, layout)
    }

    // MARK: - Items

    private static func label(for item: Item) -> String? {
        switch item.kind {
        case .memory, .cpu, .disk: return item.reading.isAvailable ? "\(item.reading.shortText)%" : "–"
        case .network: return item.reading.shortText
        case .bluetooth: return item.reading.fraction.flatMap { $0 > 0 && $0 < 1 ? "\(item.reading.shortText)%" : nil }
        default: return nil
        }
    }

    private static func iconWidth(_ kind: MetricKind) -> CGFloat { kind == .battery ? 30 : 18 }

    private static func width(of item: Item) -> CGFloat {
        var w = iconWidth(item.kind)
        if let text = label(for: item) {
            w += 4 + (text as NSString).size(withAttributes: [.font: font]).width
        }
        return ceil(w)
    }

    private static func draw(_ item: Item, in rect: NSRect, fg: NSColor) {
        let iconRect = NSRect(x: rect.minX, y: rect.midY - 8, width: iconWidth(item.kind), height: 16)
        switch item.kind {
        case .battery:
            drawBattery(item.reading, in: iconRect.insetBy(dx: 0, dy: 1.5), fg: fg)
        case .bluetooth:
            MarkRenderer.drawBluetoothRune(in: iconRect.insetBy(dx: 3, dy: 1), color: fg)
        case .wifi:
            MarkRenderer.drawSymbol(item.reading.symbolName, variable: item.reading.fraction,
                                    in: iconRect, color: fg)
        default:
            MarkRenderer.drawSymbol(item.reading.symbolName, variable: nil, in: iconRect, color: fg)
        }
        if let text = label(for: item) {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: fg]
            let s = NSAttributedString(string: text, attributes: attrs)
            s.draw(at: NSPoint(x: iconRect.maxX + 4, y: rect.midY - s.size().height / 2))
        }
    }

    /// Battery outline with the level filled and the number knocked out, like macOS.
    static func drawBattery(_ reading: MetricReading, in rect: NSRect, fg: NSColor) {
        let body = NSRect(x: rect.minX, y: rect.minY, width: rect.width - 3, height: rect.height)
        let outline = NSBezierPath(roundedRect: body.insetBy(dx: 0.75, dy: 0.75), xRadius: 3.5, yRadius: 3.5)
        outline.lineWidth = 1.5
        fg.withAlphaComponent(0.5).setStroke()
        outline.stroke()
        let cap = NSRect(x: body.maxX + 0.5, y: rect.midY - 2.5, width: 2, height: 5)
        fg.withAlphaComponent(0.5).setFill()
        NSBezierPath(roundedRect: cap, xRadius: 1, yRadius: 1).fill()

        let inner = body.insetBy(dx: 2, dy: 2)
        let f = reading.fraction ?? 0
        var fill = inner
        fill.size.width = max(3, inner.width * CGFloat(f))
        guard let ctx = NSGraphicsContext.current else { return }
        ctx.saveGraphicsState()
        defer { ctx.restoreGraphicsState() }
        fg.setFill()
        NSBezierPath(roundedRect: inner, xRadius: 2, yRadius: 2).addClip()
        NSBezierPath(roundedRect: fill, xRadius: 2, yRadius: 2).fill()

        ctx.saveGraphicsState()
        ctx.compositingOperation = .destinationOut
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: inner.height * 0.98, weight: .heavy),
                                                    .foregroundColor: NSColor.black]
        let s = NSAttributedString(string: reading.shortText, attributes: attrs)
        let sz = s.size()
        s.draw(at: NSPoint(x: inner.midX - sz.width / 2, y: inner.midY - sz.height / 2))
        ctx.restoreGraphicsState()
        if f < 0.5 {
            // On a low level the knocked-out digits would vanish; redraw them solid.
            let solid = NSAttributedString(string: reading.shortText,
                                           attributes: [.font: attrs[.font]!, .foregroundColor: fg])
            NSGraphicsContext.current?.saveGraphicsState()
            NSBezierPath(rect: NSRect(x: fill.maxX, y: inner.minY, width: inner.maxX - fill.maxX, height: inner.height)).addClip()
            solid.draw(at: NSPoint(x: inner.midX - sz.width / 2, y: inner.midY - sz.height / 2))
            NSGraphicsContext.current?.restoreGraphicsState()
        }
    }
}
