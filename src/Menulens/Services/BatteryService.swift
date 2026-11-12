import Foundation
import MenulensCore
import IOKit
import IOKit.ps

/// Battery state, push-driven by IOKit power source notifications.
final class BatteryService: ObservableObject {
    @Published private(set) var hasBattery = false
    @Published private(set) var percent: Double?
    @Published private(set) var isCharging = false
    @Published private(set) var isPluggedIn = false
    @Published private(set) var isFullyCharged = false
    @Published private(set) var minutesToFull: Int?
    @Published private(set) var minutesToEmpty: Int?
    @Published private(set) var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @Published private(set) var maximumCapacity: Double?
    @Published private(set) var cycleCount: Int?
    @Published private(set) var condition: String?

    private var runLoopSource: CFRunLoopSource?
    private var powerStateObserver: NSObjectProtocol?

    init() {
        refresh()
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async { service.refresh() }
        }, context)?.takeRetainedValue() {
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        }
        powerStateObserver = NotificationCenter.default.addObserver(
            forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    deinit {
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .defaultMode) }
        if let o = powerStateObserver { NotificationCenter.default.removeObserver(o) }
    }

    var fraction: Double? { percent.map { $0 / 100 } }

    var statusText: String {
        guard hasBattery else { return L("No battery") }
        if isFullyCharged { return L("Fully charged") }
        if isCharging { return L("Charging") }
        if isPluggedIn { return L("Not charging") }
        return L("On battery")
    }

    var powerSourceText: String { isPluggedIn ? L("Power Adapter") : L("Battery") }

    func refresh() {
        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let list = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        var found = false
        for ps in list {
            guard let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any],
                  (desc[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            found = true
            let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            percent = max > 0 ? Double(current) * 100 / Double(max) : nil
            isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            isPluggedIn = (desc[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            isFullyCharged = desc[kIOPSIsChargedKey] as? Bool ?? false
            let toFull = desc[kIOPSTimeToFullChargeKey] as? Int ?? -1
            let toEmpty = desc[kIOPSTimeToEmptyKey] as? Int ?? -1
            minutesToFull = toFull > 0 ? toFull : nil
            minutesToEmpty = toEmpty > 0 ? toEmpty : nil
            condition = desc[kIOPSBatteryHealthKey] as? String
        }
        hasBattery = found
        if !found { percent = nil; isCharging = false; isPluggedIn = true }
        readSmartBattery()
    }

    private func readSmartBattery() {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }
        func int(_ key: String) -> Int? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int
        }
        // Recent macOS versions keep the raw capacities inside "BatteryData".
        let data = IORegistryEntryCreateCFProperty(service, "BatteryData" as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? [String: Any] ?? [:]
        func value(_ key: String) -> Int? { int(key) ?? data[key] as? Int }
        cycleCount = value("CycleCount")
        if let raw = value("NominalChargeCapacity") ?? value("AppleRawMaxCapacity"),
           let design = value("DesignCapacity"), design > 0 {
            maximumCapacity = min(100, Double(raw) * 100 / Double(design))
        }
    }
}
