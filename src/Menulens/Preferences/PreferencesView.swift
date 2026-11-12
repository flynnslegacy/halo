import SwiftUI
import MenulensCore

struct PreferencesView: View {
    @State private var tab = 0
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        TabView(selection: $tab) {
            AppearanceTab().tabItem { Label(L("Mark"), systemImage: "circle.dashed") }.tag(0)
            GeneralTab().tabItem { Label(L("General"), systemImage: "gearshape") }.tag(1)
            PopoverTab().tabItem { Label(L("Popover"), systemImage: "list.bullet.rectangle") }.tag(2)
            ProfilesTab().tabItem { Label(L("Profiles"), systemImage: "person.crop.rectangle.stack") }.tag(3)
            AboutTab().tabItem { Label(L("About"), systemImage: "info.circle") }.tag(4)
        }
        .frame(width: 520)
        .padding(.top, 4)
        .id(settings.language)
    }
}

struct GeneralTab: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var monitor: SystemMonitor

    var body: some View {
        Form {
            Section {
                Picker(L("Language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
                }
                Toggle(L("Launch Menulens at login"), isOn: Binding(get: { settings.launchAtLogin },
                                                             set: { settings.setLaunchAtLogin($0) }))
            }
            Section {
                Picker(L("When hovering over the Menulens icon"), selection: $settings.hoverAction) {
                    ForEach(HoverAction.allCases) { Text($0.title).tag($0) }
                }
                Group {
                    switch settings.hoverAction {
                    case .expand: Text(L("The icon unfolds into its metrics. Click one to open its page."))
                    case .popover: Text(L("The popover opens while the pointer rests on the icon, and closes when it leaves."))
                    case .nothing: Text(L("Menulens only responds to clicks."))
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
                Toggle(L("Flip unfolded icons horizontally"), isOn: $settings.flipsExpandedIcons)
                    .disabled(settings.hoverAction != .expand)
                Toggle(L("Right-click opens main popover"), isOn: $settings.rightClickOpensPopover)
            }
            Section {
                Toggle(L("Live moments"), isOn: $settings.liveMoments)
                Text(L("Briefly shows what just happened like plugging in, AirPods connecting, the battery getting low, the network dropping or a change in volume."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("macOS menu bar icons")) {
                Text(L("Menulens replaces these icons. Turn one on to show macOS's own icon next to Menulens."))
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(SystemIcon.allCases) { icon in
                    Toggle(icon.title, isOn: Binding(get: { monitor.systemIcons.isVisible(icon) },
                                                     set: { monitor.systemIcons.setVisible(icon, $0) }))
                }
            }
            Section {
                Toggle(L("Switch Wi-Fi networks and Bluetooth devices"), isOn: $settings.allowsConnectionSwitching)
                Text(L("Join networks and connect devices from the popover. This is experimental and may not always work. With this off, the popover still lists networks and devices and can turn Wi-Fi on and off."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: 460)
        .onAppear { monitor.systemIcons.refresh() }
    }
}

struct PopoverTab: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle(L("Show more details"), isOn: $settings.showDetailsInPopover)
                Text(L("Adds a second line to rows, like CPU's user and system split, free disk space and network speeds."))
                    .font(.caption).foregroundStyle(.secondary)
                Toggle(L("Show profiles at the top"), isOn: $settings.showsProfilesInPopover)
            }
            Section(L("Rows")) {
                Text(L("Choose what the popover lists, and drag to set their order. Hiding a row doesn't change the menu bar mark."))
                    .font(.caption).foregroundStyle(.secondary)
                List {
                    ForEach(settings.popoverRows) { kind in
                        HStack {
                            Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                            RowIcon(symbol: kind == .bluetooth ? "menulens.bluetooth" : kind.symbolName, size: 22)
                            Text(kind.rowTitle)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { !settings.hiddenPopoverRows.contains(kind) },
                                set: { on in
                                    if on { settings.hiddenPopoverRows.remove(kind) } else { settings.hiddenPopoverRows.insert(kind) }
                                }))
                                .labelsHidden()
                        }
                    }
                    .onMove { from, to in settings.popoverRows.move(fromOffsets: from, toOffset: to) }
                }
                .frame(height: 300)
                Button(L("Restore Default Order")) {
                    settings.popoverRows = AppSettings.defaultRowOrder
                    settings.hiddenPopoverRows = []
                }
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: 460)
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
            Text(L("Menulens")).font(.title.bold())
            Text(L("Your menu bar, in one icon.")).foregroundStyle(.secondary)
            Text(L("Version %@", Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"))
                .font(.caption).foregroundStyle(.secondary)
            Divider().padding(.horizontal, 60)
            VStack(alignment: .leading, spacing: 6) {
                Label(L("No analytics, no tracking, no network requests"), systemImage: "hand.raised.fill")
                Label(L("Everything is read on your Mac through Apple's APIs"), systemImage: "apple.logo")
                Label(L("Only the metrics you can see are sampled"), systemImage: "leaf.fill")
                Label(L("Every feature included, free"), systemImage: "gift.fill")
            }
            .font(.callout)
            Spacer()
            Button(L("Quit Menulens")) { NSApp.terminate(nil) }
        }
        .padding(24)
        .frame(minHeight: 460)
    }
}
