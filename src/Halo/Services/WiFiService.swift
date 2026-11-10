import Foundation
import HaloCore
import CoreWLAN
import CoreLocation

struct WiFiNetwork: Identifiable, Equatable {
    var id: String { ssid }
    let ssid: String
    let rssi: Int
    let isSecured: Bool
    let isKnown: Bool
    let band: String
    var signal: Double { WiFiService.signalFraction(rssi: rssi) }
}

/// Wi-Fi state via CoreWLAN. Network names need Location access (macOS treats SSIDs as location data).
final class WiFiService: NSObject, ObservableObject, CWEventDelegate, CLLocationManagerDelegate {
    @Published private(set) var isAvailable = false
    @Published private(set) var isPoweredOn = false
    @Published private(set) var isAssociated = false
    @Published private(set) var ssid: String?
    @Published private(set) var rssi: Int = 0
    @Published private(set) var transmitRate: Double = 0
    @Published private(set) var band: String = ""
    @Published private(set) var networks: [WiFiNetwork] = []
    @Published private(set) var isScanning = false
    @Published private(set) var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var joiningSSID: String?
    @Published var joinError: String?

    private let client = CWWiFiClient.shared()
    private let locationManager = CLLocationManager()
    private let queue = DispatchQueue(label: "halo.wifi")

    override init() {
        super.init()
        locationManager.delegate = self
        locationStatus = locationManager.authorizationStatus
        client.delegate = self
        for event in [CWEventType.powerDidChange, .ssidDidChange, .linkDidChange, .linkQualityDidChange] {
            do { try client.startMonitoringEvent(with: event) }
            catch { NSLog("Halo: Wi-Fi event monitoring unavailable: \(error)") }
        }
        refresh()
    }

    private var interface: CWInterface? { client.interface() }

    var hasLocationAccess: Bool { locationStatus == .authorizedAlways || locationStatus == .authorized }

    var fraction: Double? {
        guard isPoweredOn, isAssociated else { return isPoweredOn ? 0 : nil }
        return Self.signalFraction(rssi: rssi)
    }

    var signalText: String {
        let f = Self.signalFraction(rssi: rssi)
        if f > 0.75 { return L("Excellent signal") }
        if f > 0.5 { return L("Good signal") }
        if f > 0.25 { return L("Fair signal") }
        return L("Weak signal")
    }

    /// The name shown in the row ("Connected" when Location access is off).
    var displayName: String {
        if !isPoweredOn { return L("Off") }
        if !isAssociated { return L("Not Connected") }
        return ssid ?? L("Connected")
    }

    static func signalFraction(rssi: Int) -> Double {
        guard rssi < 0 else { return 0 }
        return min(1, max(0, Double(rssi + 90) / 40))
    }

    func refresh() {
        guard let iface = interface else { isAvailable = false; return }
        isAvailable = true
        isPoweredOn = iface.powerOn()
        ssid = iface.ssid()
        rssi = iface.rssiValue()
        transmitRate = iface.transmitRate()
        isAssociated = isPoweredOn && (iface.wlanChannel() != nil) && rssi != 0
        band = Self.bandName(iface.wlanChannel()?.channelBand)
    }

    func requestLocationAccess() {
        locationManager.requestWhenInUseAuthorization()
    }

    func setPower(_ on: Bool) {
        try? interface?.setPower(on)
        refresh()
        if on { scan() } else { networks = [] }
    }

    func scan() {
        guard let iface = interface, iface.powerOn(), !isScanning else { return }
        isScanning = true
        let known = Set(iface.configuration()?.networkProfiles.array
            .compactMap { ($0 as? CWNetworkProfile)?.ssid } ?? [])
        queue.async { [weak self] in
            let found = (try? iface.scanForNetworks(withSSID: nil)) ?? []
            var best: [String: CWNetwork] = [:]
            for n in found {
                guard let name = n.ssid, !name.isEmpty else { continue }
                if let cur = best[name], cur.rssiValue >= n.rssiValue { continue }
                best[name] = n
            }
            let list = best.values.map { n in
                WiFiNetwork(ssid: n.ssid ?? "", rssi: n.rssiValue,
                            isSecured: !n.supportsSecurity(.none),
                            isKnown: known.contains(n.ssid ?? ""),
                            band: Self.bandName(n.wlanChannel?.channelBand))
            }.sorted { ($0.isKnown ? 0 : 1, -$0.rssi) < ($1.isKnown ? 0 : 1, -$1.rssi) }
            DispatchQueue.main.async {
                self?.networks = list
                self?.isScanning = false
            }
        }
    }

    /// Joins a network. Known networks try the saved password first.
    func join(_ ssid: String, password: String?, completion: @escaping (Bool) -> Void) {
        guard let iface = interface else { completion(false); return }
        joiningSSID = ssid
        joinError = nil
        queue.async { [weak self] in
            var ok = false
            var message: String?
            do {
                let matches = try iface.scanForNetworks(withSSID: ssid.data(using: .utf8))
                if let network = matches.max(by: { $0.rssiValue < $1.rssiValue }) {
                    try iface.associate(to: network, password: password)
                    ok = true
                } else {
                    message = L("That network is no longer in range.")
                }
            } catch {
                message = password == nil ? L("Couldn't join this network.") : L("Couldn't join. Check the password and try again.")
            }
            DispatchQueue.main.async {
                self?.joiningSSID = nil
                self?.joinError = message
                self?.refresh()
                completion(ok)
            }
        }
    }

    func disconnect() {
        interface?.disassociate()
        refresh()
    }

    private static func bandName(_ band: CWChannelBand?) -> String {
        switch band {
        case .band2GHz: return "2.4 GHz"
        case .band5GHz: return "5 GHz"
        case .band6GHz: return "6 GHz"
        default: return ""
        }
    }

    // MARK: - CWEventDelegate

    func powerStateDidChangeForWiFiInterface(withName interfaceName: String) { onMain { self.refresh() } }
    func ssidDidChangeForWiFiInterface(withName interfaceName: String) { onMain { self.refresh() } }
    func linkDidChangeForWiFiInterface(withName interfaceName: String) { onMain { self.refresh() } }
    func linkQualityDidChangeForWiFiInterface(withName interfaceName: String, rssi: Int, transmitRate: Double) {
        onMain {
            self.rssi = rssi
            self.transmitRate = transmitRate
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onMain {
            self.locationStatus = manager.authorizationStatus
            self.refresh()
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }
}
