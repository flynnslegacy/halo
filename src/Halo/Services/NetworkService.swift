import Foundation
import HaloCore
import Network
import Darwin

/// Throughput from interface byte counters plus connectivity from NWPathMonitor.
final class NetworkService: ObservableObject {
    enum Link: Equatable { case wifi, wired, cellular, other, none }

    @Published private(set) var downRate: Double = 0
    @Published private(set) var upRate: Double = 0
    @Published private(set) var downHistory: [Double] = []
    @Published private(set) var upHistory: [Double] = []
    @Published private(set) var isConnected = true
    @Published private(set) var link: Link = .other
    @Published private(set) var totalReceived: Double = 0
    @Published private(set) var totalSent: Double = 0

    private var previous: (rx: UInt64, tx: UInt64, time: TimeInterval)?
    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.update(path) }
        }
        monitor.start(queue: DispatchQueue(label: "halo.network.path"))
    }

    deinit { monitor.cancel() }

    var linkText: String {
        switch link {
        case .wifi: return L("Wi-Fi")
        case .wired: return L("Wired connection")
        case .cellular: return L("Cellular")
        case .other: return L("Connected")
        case .none: return L("Network disconnected")
        }
    }

    /// Level for the mark: log scale where ~100 MB/s fills the ring.
    var fraction: Double {
        let kb = (downRate + upRate) / 1000
        return min(1, log10(1 + kb) / 5)
    }

    private func update(_ path: NWPath) {
        isConnected = path.status == .satisfied
        if !isConnected { link = .none }
        else if path.usesInterfaceType(.wifi) { link = .wifi }
        else if path.usesInterfaceType(.wiredEthernet) { link = .wired }
        else if path.usesInterfaceType(.cellular) { link = .cellular }
        else { link = .other }
    }

    func sample() {
        let (rx, tx) = Self.readCounters()
        let now = ProcessInfo.processInfo.systemUptime
        if let p = previous, now > p.time {
            let dt = now - p.time
            downRate = rx >= p.rx ? Double(rx - p.rx) / dt : 0
            upRate = tx >= p.tx ? Double(tx - p.tx) / dt : 0
            append(downRate, to: &downHistory)
            append(upRate, to: &upHistory)
        }
        previous = (rx, tx, now)
        totalReceived = Double(rx)
        totalSent = Double(tx)
    }

    private func append(_ v: Double, to history: inout [Double]) {
        history.append(v)
        if history.count > CPUService.historyLength { history.removeFirst(history.count - CPUService.historyLength) }
    }

    /// Sums bytes over physical interfaces (en*, pdp_ip*), skipping loopback and tunnels.
    static func readCounters() -> (UInt64, UInt64) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return (0, 0) }
        defer { freeifaddrs(ifaddr) }
        var rx: UInt64 = 0, tx: UInt64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            let ifa = p.pointee
            if let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_LINK), let data = ifa.ifa_data {
                let name = String(cString: ifa.ifa_name)
                if name.hasPrefix("en") || name.hasPrefix("pdp_ip") {
                    let d = data.assumingMemoryBound(to: if_data.self).pointee
                    rx += UInt64(d.ifi_ibytes)
                    tx += UInt64(d.ifi_obytes)
                }
            }
            ptr = ifa.ifa_next
        }
        return (rx, tx)
    }
}
