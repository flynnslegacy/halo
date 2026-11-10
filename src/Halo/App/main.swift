import AppKit

if let i = CommandLine.arguments.firstIndex(of: "--export-iconset"), i + 1 < CommandLine.arguments.count {
    IconExporter.export(to: CommandLine.arguments[i + 1])
    exit(0)
}
if let i = CommandLine.arguments.firstIndex(of: "--export-preview"), i + 1 < CommandLine.arguments.count {
    PreviewExporter.export(to: CommandLine.arguments[i + 1])
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
