import Foundation

public struct VPNConnection: Identifiable, Equatable {
    public enum Status: Equatable {
        case connected, connecting, disconnecting, disconnected, other(String)

        public init(_ raw: String) {
            switch raw.lowercased() {
            case "connected": self = .connected
            case "connecting": self = .connecting
            case "disconnecting": self = .disconnecting
            case "disconnected": self = .disconnected
            default: self = .other(raw)
            }
        }

        public var isBusy: Bool { self == .connecting || self == .disconnecting }
    }

    public let id: String          // service UUID
    public let name: String
    public let provider: String    // e.g. "io.tailscale.ipn.macsys", "IPSec"
    public let status: Status
    public let isEnabled: Bool
    public var isConnected: Bool { status == .connected }

    public init(id: String, name: String, provider: String, status: Status, isEnabled: Bool) {
        self.id = id; self.name = name; self.provider = provider; self.status = status; self.isEnabled = isEnabled
    }

    /// Parses the output of `scutil --nc list`.
    public static func parse(_ output: String) -> [VPNConnection] {
        // * (Disconnected)   22222222-…-0001 VPN (io.tailscale.ipn.macsys) "Tailscale"   [VPN:io.tailscale.ipn.macsys]
        let pattern = #"^\s*(\*?)\s*\(([^)]+)\)\s+([0-9A-Fa-f-]{36})\s+\S+\s+(?:\(([^)]*)\)\s+)?"([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return [] }
        let ns = output as NSString
        return regex.matches(in: output, range: NSRange(location: 0, length: ns.length)).map { m in
            func group(_ i: Int) -> String {
                let r = m.range(at: i)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
            return VPNConnection(id: group(3), name: group(5), provider: group(4),
                                 status: .init(group(2)), isEnabled: group(1) == "*")
        }
    }

    public func with(status: Status) -> VPNConnection {
        VPNConnection(id: id, name: name, provider: provider, status: status, isEnabled: isEnabled)
    }

    public func with(name: String) -> VPNConnection {
        VPNConnection(id: id, name: name, provider: provider, status: status, isEnabled: isEnabled)
    }

    /// Status from a NetworkExtension session (`ne_session_status_t`).
    public static func status(neSession code: Int) -> Status {
        switch code {
        case 1: return .disconnected
        case 2, 4: return .connecting      // connecting, reasserting
        case 3: return .connected
        case 5: return .disconnecting
        default: return .other("–")
        }
    }

    /// Parses /Library/Preferences/com.apple.networkextension.plist (an NSKeyedArchiver archive).
    /// Lists full-tunnel VPN configurations, including the built-in IKEv2/IPSec ones that
    /// `scutil --nc` does not show. Statuses are left as `.disconnected`.
    public static func parseNetworkExtension(_ data: Data) -> [VPNConnection] {
        guard let root = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let objects = root["$objects"] as? [Any],
              let top = root["$top"] as? [String: Any] else { return [] }
        let archive = KeyedArchive(objects: objects)
        var result: [VPNConnection] = []
        for (key, ref) in top {
            guard let uuid = UUID(uuidString: key),
                  let config = archive.dictionary(ref),
                  let name = archive.value(config["Name"]) as? String,
                  let vpn = archive.dictionary(config["VPN"]) else { continue }
            // TunnelType 1 is a full VPN tunnel; 2 is an app proxy (e.g. split tunneling helpers).
            let tunnelType = archive.value(vpn["TunnelType"]) as? Int ?? 1
            guard tunnelType == 1 else { continue }
            let enabled = archive.value(vpn["Enabled"]) as? Bool ?? true
            let proto = archive.dictionary(vpn["Protocol"]) ?? [:]
            let provider: String
            if let plugin = archive.value(proto["PluginType"]) as? String {
                provider = plugin
            } else {
                switch archive.value(proto["Type"]) as? Int {
                case 5: provider = "IKEv2"
                case 1: provider = "IPSec"
                case 2: provider = "L2TP"
                case 3: provider = "PPTP"
                default: provider = ""
                }
            }
            result.append(VPNConnection(id: uuid.uuidString, name: name, provider: provider,
                                        status: .disconnected, isEnabled: enabled))
        }
        return result
    }

    /// Merges NetworkExtension and `scutil` lists by service ID, sorts by name and
    /// disambiguates duplicate names with the protocol ("ProtonVPN (IKEv2)").
    public static func merge(_ lists: [VPNConnection]...) -> [VPNConnection] {
        var byID: [String: VPNConnection] = [:]
        var order: [String] = []
        for list in lists {
            for c in list where byID[c.id] == nil {
                byID[c.id] = c
                order.append(c.id)
            }
        }
        var merged = order.compactMap { byID[$0] }
        let counts = Dictionary(grouping: merged, by: \.name).mapValues(\.count)
        merged = merged.map { c in
            guard counts[c.name, default: 0] > 1, ["IKEv2", "IPSec", "L2TP", "PPTP"].contains(c.provider) else { return c }
            return c.with(name: "\(c.name) (\(c.provider))")
        }
        return merged.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

/// Minimal reader for NSKeyedArchiver plists: resolves UID references into values and dictionaries.
struct KeyedArchive {
    let objects: [Any]

    private static let uidPattern = try! NSRegularExpression(pattern: #"value = (\d+)"#)

    /// Index of a CFKeyedArchiverUID, or nil if `ref` is not one.
    static func uidIndex(_ ref: Any) -> Int? {
        if let d = ref as? [String: Any], d.count == 1, let n = d["CF$UID"] as? Int { return n }
        let type = CFGetTypeID(ref as CFTypeRef)
        guard type != CFStringGetTypeID(), type != CFNumberGetTypeID(), type != CFBooleanGetTypeID(),
              type != CFDictionaryGetTypeID(), type != CFArrayGetTypeID(), type != CFDataGetTypeID() else { return nil }
        let text = String(describing: ref)
        guard text.contains("CFKeyedArchiverUID"),
              let m = uidPattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return Int(text[r])
    }

    /// Follows a reference to its object; "$null" becomes nil.
    func value(_ ref: Any?) -> Any? {
        guard var v = ref else { return nil }
        var hops = 0
        while let i = Self.uidIndex(v), hops < 8 {
            guard objects.indices.contains(i) else { return nil }
            v = objects[i]
            hops += 1
        }
        if let s = v as? String, s == "$null" { return nil }
        return v
    }

    /// Follows a reference to a dictionary, flattening NSDictionary's NS.keys / NS.objects form.
    func dictionary(_ ref: Any?) -> [String: Any]? {
        guard let d = value(ref) as? [String: Any] else { return nil }
        if let keys = d["NS.keys"] as? [Any], let vals = d["NS.objects"] as? [Any] {
            var out: [String: Any] = [:]
            for (k, v) in zip(keys, vals) {
                if let name = value(k) as? String { out[name] = v }
            }
            return out
        }
        return d
    }
}

