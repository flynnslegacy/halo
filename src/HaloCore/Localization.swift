import Foundation

/// Interface language. "Automatic" follows the Mac's preferred languages.
public enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case system, english, french
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .system: return L("Automatic")
        case .english: return "English"
        case .french: return "Français"
        }
    }
}

public enum Localizer {
    public static var language: AppLanguage = .system

    public static var isFrench: Bool {
        switch language {
        case .french: return true
        case .english: return false
        case .system: return Locale.preferredLanguages.first?.lowercased().hasPrefix("fr") ?? false
        }
    }
}

/// Translates an English UI string (the key) into the current language.
public func L(_ key: String) -> String {
    Localizer.isFrench ? (FrenchStrings.table[key] ?? key) : key
}

/// Translates a format string, then fills in its `%@` / `%d` arguments.
public func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), arguments: args)
}
