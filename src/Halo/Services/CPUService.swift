import Foundation
import HaloCore
import Darwin

/// CPU usage from host tick counters; sampled only while visible.
final class CPUService: ObservableObject {
    static let historyLength = 60

    @Published private(set) var usage: Double = 0
    @Published private(set) var user: Double = 0
    @Published private(set) var system: Double = 0
    @Published private(set) var history: [Double] = []
    @Published private(set) var loadAverages: [Double] = [0, 0, 0]
    @Published private(set) var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    @Published private(set) var uptime: TimeInterval = ProcessInfo.processInfo.systemUptime

    private var previousTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

    var coreCount: Int { ProcessInfo.processInfo.activeProcessorCount }

    var thermalText: String {
        switch thermalState {
        case .nominal: return L("Normal")
        case .fair: return L("Fair")
        case .serious: return L("Serious")
        case .critical: return L("Critical")
        @unknown default: return L("Unknown")
        }
    }

    func sample() {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let ticks = (user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
        if let p = previousTicks {
            let du = Double(ticks.user &- p.user) + Double(ticks.nice &- p.nice)
            let ds = Double(ticks.system &- p.system)
            let di = Double(ticks.idle &- p.idle)
            let total = du + ds + di
            if total > 0 {
                user = du / total
                system = ds / total
                usage = (du + ds) / total
                history.append(usage)
                if history.count > Self.historyLength { history.removeFirst(history.count - Self.historyLength) }
            }
        }
        previousTicks = ticks

        var loads = [Double](repeating: 0, count: 3)
        if getloadavg(&loads, 3) == 3 { loadAverages = loads }
        thermalState = ProcessInfo.processInfo.thermalState
        uptime = ProcessInfo.processInfo.systemUptime
    }
}
