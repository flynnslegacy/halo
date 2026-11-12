import Foundation
import MenulensCore
import CoreAudio
import AudioToolbox

struct AudioOutputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let symbolName: String
}

/// Output volume, mute and output device selection through CoreAudio.
final class AudioService: ObservableObject {
    @Published private(set) var volume: Double = 0
    @Published private(set) var isMuted = false
    @Published private(set) var canSetVolume = true
    @Published private(set) var outputs: [AudioOutputDevice] = []
    @Published private(set) var currentOutputID: AudioDeviceID = 0
    /// Fires on a user-visible change (volume or mute), used by live moments.
    var onVolumeChange: (() -> Void)?

    private var observedDevice: AudioDeviceID = 0
    private let listenerQueue = DispatchQueue.main
    private lazy var deviceListener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        self?.readVolume(notify: true)
    }

    init() {
        var defaultAddr = Self.address(kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &defaultAddr, listenerQueue) { [weak self] _, _ in
            self?.attachToDefaultDevice()
        }
        var devicesAddr = Self.address(kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, listenerQueue) { [weak self] _, _ in
            self?.reloadOutputs()
        }
        attachToDefaultDevice()
        reloadOutputs()
    }

    var currentOutputName: String { outputs.first(where: { $0.id == currentOutputID })?.name ?? L("Output") }

    var symbolName: String {
        if isMuted || volume == 0 { return "speaker.slash.fill" }
        if volume < 0.34 { return "speaker.wave.1.fill" }
        if volume < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    // MARK: - Volume

    func setVolume(_ value: Double) {
        guard canSetVolume else { return }
        var v = Float32(min(max(value, 0), 1))
        var addr = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput)
        AudioObjectSetPropertyData(observedDevice, &addr, 0, nil, UInt32(MemoryLayout<Float32>.size), &v)
        if isMuted && value > 0 { setMuted(false) }
        volume = Double(v)
    }

    func setMuted(_ muted: Bool) {
        var m: UInt32 = muted ? 1 : 0
        var addr = Self.address(kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput)
        AudioObjectSetPropertyData(observedDevice, &addr, 0, nil, UInt32(MemoryLayout<UInt32>.size), &m)
        isMuted = muted
    }

    func selectOutput(_ id: AudioDeviceID) {
        var device = id
        for selector in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDefaultSystemOutputDevice] {
            var addr = Self.address(selector, kAudioObjectPropertyScopeGlobal)
            AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
                                       UInt32(MemoryLayout<AudioDeviceID>.size), &device)
        }
    }

    private func attachToDefaultDevice() {
        let newDevice = Self.defaultOutputDevice()
        if observedDevice != 0 {
            for sel in [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute] {
                var addr = Self.address(sel, kAudioDevicePropertyScopeOutput)
                AudioObjectRemovePropertyListenerBlock(observedDevice, &addr, listenerQueue, deviceListener)
            }
        }
        observedDevice = newDevice
        currentOutputID = newDevice
        for sel in [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute] {
            var addr = Self.address(sel, kAudioDevicePropertyScopeOutput)
            AudioObjectAddPropertyListenerBlock(newDevice, &addr, listenerQueue, deviceListener)
        }
        readVolume(notify: false)
    }

    private func readVolume(notify: Bool) {
        var addr = Self.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyScopeOutput)
        var settable: DarwinBoolean = false
        if AudioObjectHasProperty(observedDevice, &addr) {
            AudioObjectIsPropertySettable(observedDevice, &addr, &settable)
            var v: Float32 = 0
            var size = UInt32(MemoryLayout<Float32>.size)
            AudioObjectGetPropertyData(observedDevice, &addr, 0, nil, &size, &v)
            canSetVolume = settable.boolValue
            let changed = abs(Double(v) - volume) > 0.004
            volume = Double(v)
            if changed && notify { onVolumeChange?() }
        } else {
            canSetVolume = false
            volume = 1
        }
        var muteAddr = Self.address(kAudioDevicePropertyMute, kAudioDevicePropertyScopeOutput)
        if AudioObjectHasProperty(observedDevice, &muteAddr) {
            var m: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            AudioObjectGetPropertyData(observedDevice, &muteAddr, 0, nil, &size, &m)
            let muted = m != 0
            if muted != isMuted { isMuted = muted; if notify { onVolumeChange?() } }
        }
    }

    // MARK: - Devices

    private func reloadOutputs() {
        var addr = Self.address(kAudioHardwarePropertyDevices, kAudioObjectPropertyScopeGlobal)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr else { return }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids)
        outputs = ids.compactMap { id in
            guard Self.hasOutputStreams(id), let name = Self.name(of: id) else { return nil }
            return AudioOutputDevice(id: id, name: name, symbolName: Self.symbol(for: id, name: name))
        }
        currentOutputID = Self.defaultOutputDevice()
    }

    private static func defaultOutputDevice() -> AudioDeviceID {
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = address(kAudioHardwarePropertyDefaultOutputDevice, kAudioObjectPropertyScopeGlobal)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &id)
        return id
    }

    private static func hasOutputStreams(_ id: AudioDeviceID) -> Bool {
        var addr = address(kAudioDevicePropertyStreams, kAudioDevicePropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr && size > 0
    }

    private static func name(of id: AudioDeviceID) -> String? {
        var addr = address(kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &name) == noErr,
              let value = name?.takeRetainedValue() else { return nil }
        return value as String
    }

    private static func symbol(for id: AudioDeviceID, name: String) -> String {
        var addr = address(kAudioDevicePropertyTransportType, kAudioObjectPropertyScopeGlobal)
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &transport)
        let lower = name.lowercased()
        if lower.contains("airpods") { return "airpods" }
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn: return "laptopcomputer"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "headphones"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: return "tv"
        case kAudioDeviceTransportTypeAirPlay: return "airplayaudio"
        case kAudioDeviceTransportTypeUSB: return "cable.connector.horizontal"
        case kAudioDeviceTransportTypeVirtual, kAudioDeviceTransportTypeAggregate: return "waveform"
        default: return "hifispeaker"
        }
    }

    private static func address(_ selector: AudioObjectPropertySelector,
                                _ scope: AudioObjectPropertyScope) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
}
