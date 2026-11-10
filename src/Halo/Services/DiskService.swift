import AppKit

struct VolumeInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let total: Double
    let available: Double
    let isInternal: Bool
    let isRoot: Bool
    var used: Double { max(0, total - available) }
    var fraction: Double { total > 0 ? used / total : 0 }
}

/// Free space on every mounted volume. Refreshed on mount changes and while visible.
final class DiskService: ObservableObject {
    @Published private(set) var volumes: [VolumeInfo] = []
    private var observers: [NSObjectProtocol] = []

    init() {
        refresh()
        let nc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            observers.append(nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refresh()
            })
        }
    }

    deinit { observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) } }

    var root: VolumeInfo? { volumes.first(where: \.isRoot) ?? volumes.first }

    func refresh() {
        let keys: [URLResourceKey] = [
            .volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey, .volumeIsInternalKey, .volumeIsBrowsableKey
        ]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys,
                                                         options: [.skipHiddenVolumes]) ?? []
        var result: [VolumeInfo] = []
        for url in urls {
            guard let v = try? url.resourceValues(forKeys: Set(keys)),
                  v.volumeIsBrowsable ?? true,
                  let total = v.volumeTotalCapacity, total > 0 else { continue }
            let important = v.volumeAvailableCapacityForImportantUsage.map(Double.init)
            let available = important ?? Double(v.volumeAvailableCapacity ?? 0)
            result.append(VolumeInfo(id: url.path,
                                     name: v.volumeName ?? url.lastPathComponent,
                                     total: Double(total),
                                     available: available,
                                     isInternal: v.volumeIsInternal ?? false,
                                     isRoot: url.path == "/"))
        }
        result.sort { ($0.isRoot ? 0 : 1, $0.name) < ($1.isRoot ? 0 : 1, $1.name) }
        if result != volumes { volumes = result }
    }
}
