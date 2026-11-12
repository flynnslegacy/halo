import SwiftUI
import MenulensCore

struct ProfilesTab: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var newName = ""
    @State private var newSymbol = "desktopcomputer"

    var body: some View {
        Form {
            Section {
                Text(L("A profile saves what the ring, center and dots show, and the mark's colors. Switch between them from the top of the popover."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(L("Profiles")) {
                if settings.profiles.isEmpty {
                    Text(L("No profiles yet.")).foregroundStyle(.secondary)
                    Button(L("Add the three starters")) { settings.addStarters() }
                }
                ForEach(settings.profiles) { profile in
                    ProfileRow(profile: profile)
                }
                .onMove { settings.profiles.move(fromOffsets: $0, toOffset: $1) }
            }
            Section(L("Save what's showing now")) {
                HStack {
                    Picker("", selection: $newSymbol) {
                        ForEach(Profile.symbolChoices, id: \.self) { Image(systemName: $0).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 64)
                    TextField(L("Name"), text: $newName)
                        .onSubmit(save)
                    Button(L("Save"), action: save)
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !settings.profiles.isEmpty {
                    Button(L("Add the three starters")) { settings.addStarters() }
                        .disabled(Set(settings.profiles.map(\.name)).isSuperset(of: [L("Work"), L("Travel"), L("Minimal")]))
                }
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: 460)
    }

    private func save() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        settings.saveCurrentAsProfile(named: name, symbol: newSymbol)
        newName = ""
    }
}

private struct ProfileRow: View {
    let profile: Profile
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        let active = settings.activeProfileID == profile.id
        HStack(spacing: 10) {
            Image(systemName: profile.symbolName).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.name).fontWeight(active ? .semibold : .regular)
                let c = profile.configuration
                Text("\(c.ring.title) · \(c.center.title) · \(c.dots.title) — \(c.palette.title)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if active {
                Text(L("Active")).font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
            } else {
                Button(L("Use")) { settings.apply(profile) }.controlSize(.small)
            }
            Button {
                settings.deleteProfile(profile.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help(L("Delete profile"))
        }
    }
}
