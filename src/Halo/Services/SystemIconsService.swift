import Foundation
import HaloCore

/// macOS's own menu bar icons that Halo can replace.
enum SystemIcon: String, CaseIterable, Identifiable {
    case wifi = "WiFi", bluetooth = "Bluetooth", battery = "Battery", sound = "Sound", vpn = "VPN"

    var id: String { rawValue }

    var metric: MetricKind {
        switch self {
        case .wifi: return .wifi
        case .bluetooth: return .bluetooth
        case .battery: return .battery
        case .sound: return .volume
        case .vpn: return .vpn
        }
    }

    init?(metric: MetricKind) {
        guard let icon = SystemIcon.allCases.first(where: { $0.metric == metric }) else { return nil }
        self = icon
    }

    var title: String { metric == .volume ? L("Sound") : metric.title }
}

/// Shows or hides the native Control Center menu bar icons (Wi-Fi, Bluetooth, Battery, Sound, VPN),
/// plus the older SystemUIServer VPN icon.
/// macOS keeps these in com.apple.controlcenter: `NSStatusItem VisibleCC <Name>` on recent systems,
/// and a per-host value (18 = show, 24 = hide) on older ones. Control Center is restarted to apply.
final class SystemIconsService: ObservableObject {
    @Published private(set) var visible: [SystemIcon: Bool] = [:]

    private let domain = "com.apple.controlcenter" as CFString

    init() { refresh() }

    func isVisible(_ icon: SystemIcon) -> Bool { visible[icon] ?? false }

    func refresh() {
        var result: [SystemIcon: Bool] = [:]
        for icon in SystemIcon.allCases {
            let ccKey = "NSStatusItem VisibleCC \(icon.rawValue)" as CFString
            if let v = CFPreferencesCopyAppValue(ccKey, domain) as? Bool {
                result[icon] = v
            } else if let n = CFPreferencesCopyValue(icon.rawValue as CFString, domain,
                                                     kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) as? Int {
                result[icon] = n == 18 || n == 2
            } else {
                result[icon] = false
            }
        }
        // The VPN status icon can also be the older SystemUIServer menu extra (VPN.menu).
        if LegacyVPNMenu.isVisible { result[.vpn] = true }
        if result != visible { visible = result }
    }

    func setVisible(_ icon: SystemIcon, _ show: Bool) {
        let ccKey = "NSStatusItem VisibleCC \(icon.rawValue)" as CFString
        CFPreferencesSetAppValue(ccKey, show as CFBoolean, domain)
        CFPreferencesAppSynchronize(domain)
        CFPreferencesSetValue(icon.rawValue as CFString, (show ? 18 : 24) as CFNumber, domain,
                              kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost)
        visible[icon] = show
        if icon == .vpn { LegacyVPNMenu.setVisible(show) }
        restartControlCenter()
    }

    private func restartControlCenter() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            p.arguments = ["ControlCenter"]
            try? p.run()
            p.waitUntilExit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self?.refresh() }
        }
    }
}

/// The VPN icon drawn by SystemUIServer (System Settings › VPN › "Show VPN status in menu bar").
/// It lives in com.apple.systemuiserver's `menuExtras` list, separate from Control Center.
private enum LegacyVPNMenu {
    static let path = "/System/Library/CoreServices/Menu Extras/VPN.menu"
    private static let domain = "com.apple.systemuiserver" as CFString
    private static let visibleKey = "NSStatusItem VisibleCC com.apple.menuextra.vpn" as CFString

    private static var extras: [String] {
        CFPreferencesAppSynchronize(domain)
        return CFPreferencesCopyAppValue("menuExtras" as CFString, domain) as? [String] ?? []
    }

    static var isVisible: Bool {
        guard extras.contains(path) else { return false }
        return CFPreferencesCopyAppValue(visibleKey, domain) as? Bool ?? true
    }

    static func setVisible(_ show: Bool) {
        var list = extras.filter { $0 != path }
        if show { list.append(path) }
        CFPreferencesSetAppValue("menuExtras" as CFString, list as CFArray, domain)
        CFPreferencesSetAppValue(visibleKey, show as CFBoolean, domain)
        CFPreferencesAppSynchronize(domain)
        DispatchQueue.global(qos: .utility).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            p.arguments = ["SystemUIServer"]
            try? p.run()
            p.waitUntilExit()
            if show {
                // SystemUIServer relaunches on its own; opening the extra makes sure it is loaded.
                Thread.sleep(forTimeInterval: 1)
                let o = Process()
                o.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                o.arguments = [path]
                try? o.run()
            }
        }
    }
}
