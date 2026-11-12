import Foundation
import Darwin

/// Memory split like Activity Monitor: App, Wired, Compressed and Cached.
final class MemoryService: ObservableObject {
    @Published private(set) var total: Double = Double(ProcessInfo.processInfo.physicalMemory)
    @Published private(set) var app: Double = 0
    @Published private(set) var wired: Double = 0
    @Published private(set) var compressed: Double = 0
    @Published private(set) var cached: Double = 0
    @Published private(set) var swapUsed: Double = 0
    @Published private(set) var history: [Double] = []

    /// "Memory Used" in Activity Monitor.
    var used: Double { app + wired + compressed }
    var fraction: Double { total > 0 ? min(1, used / total) : 0 }

    func sample() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }
        let page = Double(vm_kernel_page_size)
        let internalPages = Double(stats.internal_page_count)
        let purgeable = Double(stats.purgeable_count)
        app = max(0, internalPages - purgeable) * page
        wired = Double(stats.wire_count) * page
        compressed = Double(stats.compressor_page_count) * page
        cached = (Double(stats.external_page_count) + purgeable) * page

        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 {
            swapUsed = Double(swap.xsu_used)
        }
        history.append(fraction)
        if history.count > CPUService.historyLength { history.removeFirst(history.count - CPUService.historyLength) }
    }
}
