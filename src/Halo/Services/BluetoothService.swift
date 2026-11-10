import Foundation
import HaloCore
import IOBluetooth
import IOKit

struct BluetoothDeviceInfo: Identifiable, Equatable {
    let id: String          // normalized address
    let name: String
    let isConnected: Bool
    let kind: Kind
    let battery: Int?       // 0...100, single or lowest bud
    let batteryLeft: Int?
    let batteryRight: Int?
    let batteryCase: Int?

    enum Kind: Equatable {
        case airpods, headphones, speaker, keyboard, mouse, trackpad, gamepad, phone, computer, other

        var symbolName: String {
            switch self {
            case .airpods: return "airpods"
            case .headphones: return "headphones"
            case .speaker: return "hifispeaker"
            case .keyboard: return "keyboard"
            case .mouse: return "computermouse"
            case .trackpad: return "rectangle.and.hand.point.up.left"
            case .gamepad: return "gamecontroller"
            case .phone: return "iphone"
            case .computer: return "laptopcomputer"
            case .other: return "dot.radiowaves.left.and.right"
            }
        }

        var isAudio: Bool { self == .airpods || self == .headphones || self == .speaker }
    }
}

/// Paired Bluetooth devices, their connection state and battery levels.
final class BluetoothService: NSObject, ObservableObject {
    @Published private(set) var isPoweredOn = false
    @Published private(set) var devices: [BluetoothDeviceInfo] = []
    @Published private(set) var pendingIDs: Set<String> = []
    /// Fires when an audio device (AirPods, headphones…) connects.
    var onAudioDeviceConnected: ((BluetoothDeviceInfo) -> Void)?

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private let queue = DispatchQueue(label: "halo.bluetooth")

    /// IOBluetooth is only touched once its first, possibly blocking, setup has finished.
    private var isReady = false

    override init() {
        super.init()
        // The first IOBluetooth call can wait for the Bluetooth permission prompt; never do it on the main thread.
        queue.async { [weak self] in
            _ = IOBluetoothHostController.default()?.powerState
            _ = IOBluetoothDevice.pairedDevices()
            DispatchQueue.main.async {
                guard let self else { return }
                self.isReady = true
                self.connectNotification = IOBluetoothDevice.register(forConnectNotifications: self,
                                                                      selector: #selector(self.deviceConnected(_:device:)))
                self.refresh()
            }
        }
    }

    var connected: [BluetoothDeviceInfo] { devices.filter(\.isConnected) }

    /// The device shown in the popover row and on the mark.
    var primary: BluetoothDeviceInfo? {
        connected.first(where: { $0.battery != nil }) ?? connected.first
    }

    var fraction: Double? {
        guard isPoweredOn else { return nil }
        if let b = primary?.battery { return Double(b) / 100 }
        return connected.isEmpty ? 0 : 1
    }

    func refresh() {
        guard isReady else { return }
        isPoweredOn = IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON
        let hidBatteries = Self.readHIDBatteries()
        let paired = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice]) ?? []
        var list: [BluetoothDeviceInfo] = []
        for d in paired {
            let address = Self.normalize(d.addressString ?? UUID().uuidString)
            let connected = d.isConnected()
            if connected, disconnectNotifications[address] == nil {
                disconnectNotifications[address] = d.register(forDisconnectNotification: self,
                                                              selector: #selector(deviceDisconnected(_:device:)))
            }
            let left = Self.intValue(d, "batteryPercentLeft")
            let right = Self.intValue(d, "batteryPercentRight")
            let single = Self.intValue(d, "batteryPercentSingle") ?? Self.intValue(d, "batteryPercentCombined")
            let buds = [left, right].compactMap { $0 }.min()
            let battery = connected ? (single ?? buds ?? hidBatteries[address]) : nil
            list.append(BluetoothDeviceInfo(id: address,
                                            name: d.name ?? d.nameOrAddress ?? L("Device"),
                                            isConnected: connected,
                                            kind: Self.kind(of: d),
                                            battery: battery,
                                            batteryLeft: connected ? left : nil,
                                            batteryRight: connected ? right : nil,
                                            batteryCase: connected ? Self.intValue(d, "batteryPercentCase") : nil))
        }
        list.sort { ($0.isConnected ? 0 : 1, $0.name) < ($1.isConnected ? 0 : 1, $1.name) }
        if list != devices { devices = list }
    }

    /// Connects or disconnects a paired device (experimental, like the original).
    func toggleConnection(_ id: String) {
        guard isReady, let device = (IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice])?
            .first(where: { Self.normalize($0.addressString ?? "") == id }) else { return }
        pendingIDs.insert(id)
        let wasConnected = device.isConnected()
        queue.async { [weak self] in
            if wasConnected { device.closeConnection() } else { device.openConnection() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.pendingIDs.remove(id)
                self?.refresh()
            }
        }
    }

    @objc private func deviceConnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self else { return }
            self.refresh()
            let id = Self.normalize(device.addressString ?? "")
            if let info = self.devices.first(where: { $0.id == id }), info.kind.isAudio {
                self.onAudioDeviceConnected?(info)
            }
        }
    }

    @objc private func deviceDisconnected(_ note: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        let id = Self.normalize(device.addressString ?? "")
        note.unregister()
        DispatchQueue.main.async { [weak self] in
            self?.disconnectNotifications[id] = nil
            self?.refresh()
        }
    }

    // MARK: - Helpers

    static func normalize(_ address: String) -> String {
        address.lowercased().replacingOccurrences(of: "-", with: ":")
    }

    /// Battery levels exposed by private IOBluetoothDevice properties (AirPods, Beats…).
    private static func intValue(_ device: IOBluetoothDevice, _ key: String) -> Int? {
        guard device.responds(to: NSSelectorFromString(key)) else { return nil }
        let v = (device.value(forKey: key) as? NSNumber)?.intValue ?? 0
        return v > 0 ? v : nil
    }

    /// Battery levels of HID devices (Magic Mouse, keyboards, MX Master…) from the IORegistry.
    private static func readHIDBatteries() -> [String: Int] {
        var result: [String: Int] = [:]
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
                                           IOServiceMatching("AppleDeviceManagementHIDEventService"),
                                           &iterator) == KERN_SUCCESS else { return result }
        defer { IOObjectRelease(iterator) }
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            func prop(_ key: String) -> Any? {
                IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
            }
            if let percent = prop("BatteryPercent") as? Int, let address = prop("DeviceAddress") as? String {
                result[normalize(address)] = percent
            }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
        return result
    }

    private static func kind(of d: IOBluetoothDevice) -> BluetoothDeviceInfo.Kind {
        let name = (d.name ?? "").lowercased()
        if name.contains("airpods") { return .airpods }
        switch d.deviceClassMajor {
        case 0x04: // audio / video
            return d.deviceClassMinor == 0x05 || d.deviceClassMinor == 0x0A ? .speaker : .headphones
        case 0x05: // peripheral
            if name.contains("trackpad") { return .trackpad }
            let minor = d.deviceClassMinor
            if minor & 0x10 != 0 { return .keyboard }
            if minor & 0x20 != 0 { return .mouse }
            if minor & 0x0F == 0x01 || minor & 0x0F == 0x02 { return .gamepad }
            return .other
        case 0x02: return .phone
        case 0x01: return .computer
        default: return .other
        }
    }
}
