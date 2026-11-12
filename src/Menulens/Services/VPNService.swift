import Foundation
import MenulensCore

/// VPN services known to macOS (System Settings › VPN): app VPNs like ProtonVPN or Tailscale and
/// built-in IKEv2/IPSec configurations. The list merges the NetworkExtension store (which holds the
/// IKEv2 ones `scutil` can't see) with `scutil --nc list`; status and connect/disconnect go through
/// NetworkExtension sessions, with `scutil --nc` as a fallback.
final class VPNService: ObservableObject {
    @Published private(set) var connections: [VPNConnection] = []
    @Published private(set) var pendingIDs: Set<String> = []
    @Published private(set) var hasLoaded = false

    private let queue = DispatchQueue(label: "menulens.vpn")
    private var isRefreshing = false
    private static let storePath = "/Library/Preferences/com.apple.networkextension.plist"

    init() { refresh() }

    var active: VPNConnection? { connections.first(where: \.isConnected) }
    var isConnected: Bool { active != nil }
    var isBusy: Bool { connections.contains { $0.status.isBusy } || !pendingIDs.isEmpty }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        queue.async { [weak self] in
            let list = Self.load()
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshing = false
                self.hasLoaded = true
                if list != self.connections { self.connections = list }
            }
        }
    }

    /// Connects or disconnects a VPN service.
    func toggle(_ id: String) {
        guard let c = connections.first(where: { $0.id == id }) else { return }
        // Only one VPN at a time: stop the active one before starting another.
        let toStop = connections.filter { $0.isConnected && $0.id != id }.map(\.id)
        let start = !(c.isConnected || c.status == .connecting)
        pendingIDs.insert(id)
        queue.async { [weak self] in
            if start { toStop.forEach { Self.control($0, start: false) } }
            Self.control(id, start: start)
            for delay in [0.8, 2.0, 4.0, 7.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self?.refresh() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 7.5) { self?.pendingIDs.remove(id) }
        }
    }

    // MARK: - Loading

    private static func load() -> [VPNConnection] {
        let fromStore = (FileManager.default.contents(atPath: storePath)).map(VPNConnection.parseNetworkExtension) ?? []
        let fromScutil = VPNConnection.parse(runScutil(["--nc", "list"]) ?? "")
        return VPNConnection.merge(fromStore, fromScutil).map { c in
            if let code = NESession.status(c.id) { return c.with(status: VPNConnection.status(neSession: code)) }
            // No NetworkExtension session: keep scutil's status if it knows the service.
            return fromScutil.first(where: { $0.id == c.id }).map { c.with(status: $0.status) } ?? c
        }
    }

    private static func control(_ id: String, start: Bool) {
        if !NESession.control(id, start: start) {
            _ = runScutil(["--nc", start ? "start" : "stop", id])
        }
    }

    private static func runScutil(_ args: [String]) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}

/// NetworkExtension sessions (`ne_session_*` in libSystem), the API behind the VPN menu.
/// Looked up at runtime; every call returns nil/false when it is unavailable.
private enum NESession {
    private typealias Create = @convention(c) (UnsafePointer<UInt8>, Int32) -> OpaquePointer?
    private typealias Handler = @convention(block) (Int32) -> Void
    private typealias GetStatus = @convention(c) (OpaquePointer, DispatchQueue, Handler) -> Void
    private typealias Action = @convention(c) (OpaquePointer) -> Void

    private static let vpnType: Int32 = 1
    private static let lib = dlopen("/usr/lib/libSystem.B.dylib", RTLD_NOW)

    private static func sym<T>(_ name: String, _ type: T.Type) -> T? {
        guard let lib, let p = dlsym(lib, name) else { return nil }
        return unsafeBitCast(p, to: type)
    }

    private static let create = sym("ne_session_create", Create.self)
    private static let getStatus = sym("ne_session_get_status", GetStatus.self)
    private static let start = sym("ne_session_start", Action.self)
    private static let stop = sym("ne_session_stop", Action.self)
    private static let release = sym("ne_session_release", Action.self)

    private static func withSession<R>(_ id: String, _ body: (OpaquePointer) -> R?) -> R? {
        guard let create, let uuid = UUID(uuidString: id) else { return nil }
        var raw = uuid.uuid
        let session = withUnsafeBytes(of: &raw) { buf in
            create(buf.bindMemory(to: UInt8.self).baseAddress!, vpnType)
        }
        guard let session else { return nil }
        defer { release?(session) }
        return body(session)
    }

    /// `ne_session_status_t` (1 disconnected … 5 disconnecting), or nil if unknown. Blocks up to 2 s.
    static func status(_ id: String) -> Int? {
        withSession(id) { session -> Int? in
            guard let getStatus else { return nil }
            let done = DispatchSemaphore(value: 0)
            var result: Int32 = 0
            let handler: Handler = { status in result = status; done.signal() }
            getStatus(session, DispatchQueue.global(qos: .utility), handler)
            guard done.wait(timeout: .now() + 2) == .success, result > 0 else { return nil }
            return Int(result)
        }
    }

    static func control(_ id: String, start begin: Bool) -> Bool {
        withSession(id) { session -> Bool? in
            guard let action = begin ? start : stop else { return nil }
            action(session)
            return true
        } ?? false
    }
}
