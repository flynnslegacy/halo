import XCTest
@testable import HaloCore

final class MetricReadingTests: XCTestCase {
    func testLitDotsQuarters() {
        XCTAssertEqual(MetricReading.litDots(for: nil), 0)
        XCTAssertEqual(MetricReading.litDots(for: 0), 0)
        XCTAssertEqual(MetricReading.litDots(for: 0.05), 1)
        XCTAssertEqual(MetricReading.litDots(for: 0.25), 1)
        XCTAssertEqual(MetricReading.litDots(for: 0.26), 2)
        XCTAssertEqual(MetricReading.litDots(for: 0.73), 3)
        XCTAssertEqual(MetricReading.litDots(for: 1), 4)
    }

    func testFractionIsClamped() {
        XCTAssertEqual(MetricReading(fraction: 1.7, shortText: "", symbolName: "").fraction, 1)
        XCTAssertEqual(MetricReading(fraction: -1, shortText: "", symbolName: "").fraction, 0)
    }

    func testBands() {
        let low = MetricReading(fraction: 0.08, shortText: "8", symbolName: "")
        XCTAssertEqual(low.band(for: .higherIsBetter), .critical)
        XCTAssertEqual(MetricReading(fraction: 0.18, shortText: "", symbolName: "").band(for: .higherIsBetter), .warning)
        XCTAssertEqual(MetricReading(fraction: 0.95, shortText: "", symbolName: "").band(for: .higherIsWorse), .critical)
        XCTAssertEqual(MetricReading(fraction: 0.5, shortText: "", symbolName: "").band(for: .higherIsWorse), .good)
    }
}

final class PaletteTests: XCTestCase {
    func testAutomaticChangesWithBand() {
        XCTAssertEqual(Palette.automatic.solid(for: .critical), Palette.critical)
        XCTAssertEqual(Palette.ocean.solid(for: .critical), Palette.ocean.solid)
    }

    func testGradientEndpoints() {
        let p = Palette.aurora
        XCTAssertEqual(p.color(at: 0), p.stops.first)
        XCTAssertEqual(p.color(at: 1), p.stops.last)
    }
}

final class GeometryTests: XCTestCase {
    func testMarkFitsInside() {
        for t in RingThickness.allCases {
            let g = MarkGeometry(side: 18, thickness: t)
            XCTAssertLessThanOrEqual(g.centerX + g.radius + g.strokeWidth / 2, 18.0001)
            XCTAssertGreaterThanOrEqual(g.centerYFromTop - g.radius - g.strokeWidth / 2, -0.0001)
            for d in g.dotCenters {
                XCTAssertLessThanOrEqual(d.y + g.dotRadius, 18.0001)
            }
        }
    }

    func testDotsAreLeftToRightBelowCenter() {
        let g = MarkGeometry(side: 100, thickness: .regular)
        let xs = g.dotCenters.map(\.x)
        XCTAssertEqual(xs, xs.sorted())
        XCTAssertTrue(g.dotCenters.allSatisfy { $0.y > g.centerYFromTop })
    }

    func testFillAndSegments() {
        let g = MarkGeometry(side: 18, thickness: .thin)
        XCTAssertEqual(g.fillEndAngle(fraction: 0), 210)
        XCTAssertEqual(g.fillEndAngle(fraction: 1), -30)
        XCTAssertEqual(MarkGeometry.segments().count, MarkGeometry.segmentCount)
        XCTAssertEqual(MarkGeometry.litSegments(for: 0.5), 5)
        XCTAssertEqual(MarkGeometry.litSegments(for: 0.01), 1)
    }
}

final class ConfigurationTests: XCTestCase {
    func testDefaultIsBatteryWiFiMemory() {
        let c = MarkConfiguration.default
        XCTAssertEqual(c.ring, .battery)
        XCTAssertEqual(c.center, .wifi)
        XCTAssertEqual(c.dots, .memory)
        XCTAssertEqual(c.expandedMetrics, [.memory, .wifi, .battery])
    }

    func testExpandedMetricsDeduplicates() {
        let c = MarkConfiguration(ring: .battery, center: .battery, dots: .memory)
        XCTAssertEqual(c.expandedMetrics, [.memory, .battery])
    }

    func testProfilesRoundTrip() throws {
        let starters = Profile.starters(basedOn: .default)
        Localizer.language = .english
        XCTAssertEqual(Profile.starters(basedOn: .default).map(\.name), ["Work", "Travel", "Minimal"])
        Localizer.language = .system
        let data = try JSONEncoder().encode(starters)
        XCTAssertEqual(try JSONDecoder().decode([Profile].self, from: data), starters)
    }
}

final class FormatTests: XCTestCase {
    func testRates() {
        Localizer.language = .english
        defer { Localizer.language = .system }
        XCTAssertEqual(Format.rate(0), "0 KB/s")
        XCTAssertEqual(Format.rate(1_200), "1 KB/s")
        XCTAssertEqual(Format.rate(88_800_000), "88.8 MB/s")
    }

    func testBytesAndDurations() {
        Localizer.language = .english
        defer { Localizer.language = .system }
        XCTAssertEqual(Format.bytes(113_800_000_000), "114 GB")
        XCTAssertEqual(Format.memory(16 * 1_073_741_824), "16.0 GB")
        XCTAssertEqual(Format.duration(minutes: 135), "2 h 15 min")
        XCTAssertEqual(Format.percent(0.734), "73%")
    }
}

final class VPNParserTests: XCTestCase {
    func testParsesScutilList() {
        let out = """
        Available network connection services in the current set (*=enabled):
        * (Disconnected)   22222222-0000-4000-8000-000000000001 VPN (io.tailscale.ipn.macsys) "Tailscale"                      [VPN:io.tailscale.ipn.macsys]
        * (Connected)      22222222-0000-4000-8000-000000000002 VPN (ch.protonvpn.mac) "ProtonVPN"                      [VPN:ch.protonvpn.mac]
          (Disconnected)   11111111-2222-3333-4444-555555555555 IPSec              "Bureau"                       [IPSec]
        """
        let list = VPNConnection.parse(out)
        XCTAssertEqual(list.map(\.name), ["Tailscale", "ProtonVPN", "Bureau"])
        XCTAssertEqual(list[1].status, .connected)
        XCTAssertEqual(list[0].provider, "io.tailscale.ipn.macsys")
        XCTAssertFalse(list[2].isEnabled)
        XCTAssertEqual(list[2].provider, "")
    }

    func testParsesNetworkExtensionStore() throws {
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        func config(_ name: String, tunnel: Int, proto: [String: Any]) -> NSDictionary {
            ["Name": name, "VPN": ["Enabled": true, "TunnelType": tunnel, "Protocol": proto] as NSDictionary] as NSDictionary
        }
        archiver.encode(config("Home VPN", tunnel: 1, proto: ["Type": 5]), forKey: "11111111-0000-4000-8000-000000000001")
        archiver.encode(config("ProtonVPN", tunnel: 1, proto: ["Type": 5]), forKey: "11111111-0000-4000-8000-000000000002")
        archiver.encode(config("Proton VPN Split tunneling", tunnel: 2, proto: ["Type": 4, "PluginType": "ch.protonvpn.mac"]),
                        forKey: "11111111-0000-4000-8000-000000000003")
        archiver.encode(["Name": "Filter"] as NSDictionary, forKey: "11111111-0000-4000-8000-000000000004")
        archiver.encode(1733, forKey: "Generation")
        archiver.finishEncoding()

        let ne = VPNConnection.parseNetworkExtension(archiver.encodedData)
        XCTAssertEqual(Set(ne.map(\.name)), ["Home VPN", "ProtonVPN"])
        XCTAssertEqual(ne.first { $0.name == "Home VPN" }?.provider, "IKEv2")

        let sc = [VPNConnection(id: "22222222-0000-4000-8000-000000000002", name: "ProtonVPN",
                                provider: "ch.protonvpn.mac", status: .disconnected, isEnabled: true)]
        let merged = VPNConnection.merge(ne, sc)
        XCTAssertEqual(merged.map(\.name), ["Home VPN", "ProtonVPN", "ProtonVPN (IKEv2)"])
    }

    func testNESessionStatus() {
        XCTAssertEqual(VPNConnection.status(neSession: 3), .connected)
        XCTAssertEqual(VPNConnection.status(neSession: 4), .connecting)
        XCTAssertEqual(VPNConnection.status(neSession: 1), .disconnected)
    }
}

final class LocalizationTests: XCTestCase {
    /// Every string passed to L(...) in the sources has a French translation with the same placeholders.
    func testEveryKeyIsTranslated() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let src = root.appendingPathComponent("src")
        let regex = try NSRegularExpression(pattern: #"L\("((?:\\.|[^"\\])*)""#)
        var keys = Set<String>()
        for case let url as URL in FileManager.default.enumerator(at: src, includingPropertiesForKeys: nil)! where url.pathExtension == "swift" {
            let text = try String(contentsOf: url, encoding: .utf8)
            for m in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                keys.insert(String(text[Range(m.range(at: 1), in: text)!]))
            }
        }
        XCTAssertGreaterThan(keys.count, 150)
        let missing = keys.filter { FrenchStrings.table[$0] == nil }.sorted()
        XCTAssertEqual(missing, [], "Missing French strings")
        let spec = try NSRegularExpression(pattern: "%[@d]")
        func specs(_ s: String) -> [String] {
            spec.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { String(s[Range($0.range, in: s)!]) }
        }
        for (k, v) in FrenchStrings.table { XCTAssertEqual(specs(k), specs(v), "Placeholders differ for \(k)") }
    }

    func testLanguageSwitch() {
        Localizer.language = .french
        XCTAssertEqual(L("Battery"), "Batterie")
        XCTAssertEqual(L("%@ free", "12 GB"), "12 GB libres")
        Localizer.language = .english
        XCTAssertEqual(L("Battery"), "Battery")
        Localizer.language = .system
    }
}
