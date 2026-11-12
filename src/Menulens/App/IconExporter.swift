import AppKit
import MenulensCore

/// Renders the app icon into an .iconset folder (used by scripts/build-app.sh).
enum IconExporter {
    static func export(to directory: String) {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let sizes: [(String, Int)] = [
            ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64),
            ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512),
            ("512x512", 512), ("512x512@2x", 1024)
        ]
        for (name, px) in sizes {
            guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { continue }
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            draw(side: CGFloat(px))
            NSGraphicsContext.restoreGraphicsState()
            let url = URL(fileURLWithPath: directory).appendingPathComponent("icon_\(name).png")
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
    }

    private static func draw(side: CGFloat) {
        let inset = side * 0.1
        let tile = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
        let shape = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)
        NSGradient(colors: [NSColor(srgbRed: 0.18, green: 0.16, blue: 0.42, alpha: 1),
                            NSColor(srgbRed: 0.04, green: 0.04, blue: 0.09, alpha: 1)])?
            .draw(in: shape, angle: -90)

        let markSide = tile.width * 0.64
        let state = MarkState(ringFraction: 1, center: .symbol("wifi", variable: 1), litDots: 4)
        let config = MarkConfiguration(palette: .aurora, ringStyle: .gradient, thickness: .regular)
        let image = NSImage(size: NSSize(width: markSide, height: markSide), flipped: true) { rect in
            MarkRenderer.draw(state, config: config, band: .good, darkMenuBar: true, in: rect)
            return true
        }
        image.draw(in: NSRect(x: tile.midX - markSide / 2, y: tile.midY - markSide / 2 - tile.height * 0.02,
                              width: markSide, height: markSide))
    }
}

/// Renders sample marks to PNG files for visual checks (`Menulens --export-preview <dir>`).
enum PreviewExporter {
    static func export(to directory: String) {
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        // MENULENS_PREVIEW_SIDE sets the mark size in pixels; MENULENS_PREVIEW_CLEAR=1 drops the background.
        let env = ProcessInfo.processInfo.environment
        let side = CGFloat(Double(env["MENULENS_PREVIEW_SIDE"] ?? "") ?? 120)
        let clear = env["MENULENS_PREVIEW_CLEAR"] == "1"
        let samples: [(String, MarkState, MarkConfiguration, StatusBand)] = [
            ("default", MarkState(ringFraction: 1, center: .symbol("wifi", variable: 1), litDots: 3), .default, .good),
            ("cpu42", MarkState(ringFraction: 0.55, center: .text("42"), litDots: 2),
             MarkConfiguration(ring: .memory, center: .cpu, dots: .network, palette: .monochrome), .good),
            ("bt", MarkState(ringFraction: 0.3, center: .symbol("menulens.bluetooth", variable: nil), litDots: 3),
             MarkConfiguration(palette: .monochrome, ringStyle: .solid), .good),
            ("ocean-seg", MarkState(ringFraction: 1, center: .symbol("wifi", variable: 1), litDots: 4),
             MarkConfiguration(palette: .ocean, ringStyle: .segmented), .good),
            ("aurora-grad", MarkState(ringFraction: 1, center: .symbol("wifi", variable: 1), litDots: 4),
             MarkConfiguration(palette: .aurora, ringStyle: .gradient), .good),
            ("low10", MarkState(ringFraction: 0.1, ringColorOverride: Palette.critical, center: .text("10"), litDots: 3),
             .default, .critical),
            ("charging", MarkState(ringFraction: 0.6, center: .symbol("bolt.fill", variable: nil), litDots: 3, badgeBolt: true),
             .default, .good),
            ("light-bar", MarkState(ringFraction: 0.7, center: .symbol("wifi", variable: 0.6), litDots: 2), .default, .good)
        ]
        for (name, state, config, band) in samples {
            let dark = name != "light-bar"
            let img = MarkRenderer.image(for: state, config: config, band: band, darkMenuBar: dark, scale: side / 18)
            write(img, background: clear ? .clear : (dark ? .black : .white), to: "\(directory)/\(name).png")
        }
        let items: [ExpandedRenderer.Item] = [
            .init(kind: .memory, reading: MetricReading(fraction: 0.73, shortText: "73", symbolName: "memorychip", prefersText: true)),
            .init(kind: .wifi, reading: MetricReading(fraction: 0.9, shortText: "90", symbolName: "wifi")),
            .init(kind: .battery, reading: MetricReading(fraction: 0.8, shortText: "80", symbolName: "battery.75percent"))
        ]
        let (expanded, _) = ExpandedRenderer.image(items, darkMenuBar: true, hovered: .wifi)
        write(expanded, background: clear ? .clear : .black, to: "\(directory)/expanded.png", scale: 5 * side / 120)
    }

    private static func write(_ image: NSImage, background: NSColor, to path: String, scale: CGFloat = 1) {
        let size = NSSize(width: image.size.width * scale + 20, height: image.size.height * scale + 20)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        background.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.draw(in: NSRect(x: 10, y: 10, width: image.size.width * scale, height: image.size.height * scale))
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
