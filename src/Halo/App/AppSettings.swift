import Foundation
import ServiceManagement
import HaloCore

enum HoverAction: String, CaseIterable, Identifiable, Codable {
    case nothing, expand, popover
    var id: String { rawValue }
    var title: String {
        switch self {
        case .nothing: return L("Do Nothing")
        case .expand: return L("Expand into Icons")
        case .popover: return L("Open Popover")
        }
    }
}

/// All user preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    @Published var mark: MarkConfiguration { didSet { save(mark, "mark"); syncActiveProfile() } }
    @Published var hoverAction: HoverAction { didSet { defaults.set(hoverAction.rawValue, forKey: "hoverAction") } }
    @Published var flipsExpandedIcons: Bool { didSet { defaults.set(flipsExpandedIcons, forKey: "flipsExpandedIcons") } }
    @Published var rightClickOpensPopover: Bool { didSet { defaults.set(rightClickOpensPopover, forKey: "rightClickOpensPopover") } }
    @Published var liveMoments: Bool { didSet { defaults.set(liveMoments, forKey: "liveMoments") } }
    @Published var allowsConnectionSwitching: Bool { didSet { defaults.set(allowsConnectionSwitching, forKey: "allowsConnectionSwitching") } }
    @Published var showDetailsInPopover: Bool { didSet { defaults.set(showDetailsInPopover, forKey: "showDetailsInPopover") } }
    @Published var showsProfilesInPopover: Bool { didSet { defaults.set(showsProfilesInPopover, forKey: "showsProfilesInPopover") } }
    @Published var popoverRows: [MetricKind] { didSet { save(popoverRows, "popoverRows") } }
    @Published var hiddenPopoverRows: Set<MetricKind> { didSet { save(hiddenPopoverRows, "hiddenPopoverRows") } }
    @Published var profiles: [Profile] { didSet { save(profiles, "profiles") } }
    @Published var activeProfileID: UUID? { didSet { defaults.set(activeProfileID?.uuidString, forKey: "activeProfileID") } }
    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: "language")
            Localizer.language = language
        }
    }
    @Published private(set) var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    private var isApplyingProfile = false

    private init() {
        let lang = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .system
        Localizer.language = lang
        language = lang
        mark = Self.load("mark", from: defaults) ?? .default
        hoverAction = HoverAction(rawValue: defaults.string(forKey: "hoverAction") ?? "") ?? .expand
        flipsExpandedIcons = defaults.object(forKey: "flipsExpandedIcons") as? Bool ?? false
        rightClickOpensPopover = defaults.object(forKey: "rightClickOpensPopover") as? Bool ?? true
        liveMoments = defaults.object(forKey: "liveMoments") as? Bool ?? true
        allowsConnectionSwitching = defaults.object(forKey: "allowsConnectionSwitching") as? Bool ?? false
        showDetailsInPopover = defaults.object(forKey: "showDetailsInPopover") as? Bool ?? true
        showsProfilesInPopover = defaults.object(forKey: "showsProfilesInPopover") as? Bool ?? true
        let rows: [MetricKind] = Self.load("popoverRows", from: defaults) ?? []
        popoverRows = Self.completeRows(rows)
        hiddenPopoverRows = Self.load("hiddenPopoverRows", from: defaults) ?? []
        profiles = Self.load("profiles", from: defaults) ?? []
        activeProfileID = defaults.string(forKey: "activeProfileID").flatMap(UUID.init)
    }

    /// Default order of the popover, as in the original.
    static let defaultRowOrder: [MetricKind] = [.wifi, .bluetooth, .vpn, .battery, .network, .memory, .cpu, .disk, .volume]

    private static func completeRows(_ rows: [MetricKind]) -> [MetricKind] {
        var result = rows.filter { defaultRowOrder.contains($0) }
        for k in defaultRowOrder where !result.contains(k) { result.append(k) }
        return result
    }

    var visibleRows: [MetricKind] { popoverRows.filter { !hiddenPopoverRows.contains($0) } }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Halo: launch-at-login change failed: \(error)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Profiles

    var activeProfile: Profile? { profiles.first { $0.id == activeProfileID } }

    func apply(_ profile: Profile) {
        isApplyingProfile = true
        activeProfileID = profile.id
        mark = profile.configuration
        isApplyingProfile = false
    }

    func saveCurrentAsProfile(named name: String, symbol: String) {
        let p = Profile(name: name, symbolName: symbol, configuration: mark)
        profiles.append(p)
        activeProfileID = p.id
    }

    func addStarters() {
        let existing = Set(profiles.map(\.name))
        profiles += Profile.starters(basedOn: mark).filter { !existing.contains($0.name) }
    }

    func deleteProfile(_ id: UUID) {
        profiles.removeAll { $0.id == id }
        if activeProfileID == id { activeProfileID = nil }
    }

    /// Editing the mark while a profile is active updates that profile.
    private func syncActiveProfile() {
        guard !isApplyingProfile, let id = activeProfileID,
              let i = profiles.firstIndex(where: { $0.id == id }),
              profiles[i].configuration != mark else { return }
        profiles[i].configuration = mark
    }

    // MARK: - Persistence

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    private static func load<T: Decodable>(_ key: String, from defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
