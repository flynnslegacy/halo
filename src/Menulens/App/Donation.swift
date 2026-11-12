import AppKit

/// The developer's Buy Me a Coffee page, offered from the popover, the menu and the About tab.
enum Donation {
    static let url = URL(string: "https://buymeacoffee.com/davidmarkowicz")!

    static func open() { NSWorkspace.shared.open(url) }
}
