import CoreAudio
import Foundation

/// A playback or capture device as CoreAudio sees it.
struct AudioDevice: Equatable, Identifiable {
    let id: AudioDeviceID
    let uid: String
    let name: String
    let transport: UInt32
    let hasOutput: Bool
    let hasInput: Bool

    /// SF Symbol representing this device as an output.
    var outputSymbolName: String {
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn:
            return "speaker.wave.2.fill"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return name.localizedCaseInsensitiveContains("airpods") ? "airpods" : "headphones"
        case kAudioDeviceTransportTypeUSB, kAudioDeviceTransportTypeThunderbolt:
            return "cable.connector"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return "tv"
        default:
            return "waveform"
        }
    }

    /// SF Symbol representing this device as an input.
    var inputSymbolName: String {
        transport == kAudioDeviceTransportTypeBuiltIn ? "mic.fill" : "mic"
    }

    var transportName: String {
        switch transport {
        case kAudioDeviceTransportTypeBuiltIn: return "built-in"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "bluetooth"
        case kAudioDeviceTransportTypeUSB: return "usb"
        case kAudioDeviceTransportTypeThunderbolt: return "thunderbolt"
        case kAudioDeviceTransportTypeAirPlay: return "airplay"
        case kAudioDeviceTransportTypeHDMI: return "hdmi"
        case kAudioDeviceTransportTypeDisplayPort: return "displayport"
        case kAudioDeviceTransportTypeAggregate: return "aggregate"
        case kAudioDeviceTransportTypeVirtual: return "virtual"
        default: return "other"
        }
    }
}

/// Talks to CoreAudio directly: enumerates devices, reads and sets the
/// defaults, and refreshes itself whenever the hardware landscape changes —
/// so the menu and hotkeys can never go stale.
final class AudioDeviceManager: ObservableObject {
    @Published private(set) var outputDevices: [AudioDevice] = []
    @Published private(set) var inputDevices: [AudioDevice] = []
    @Published private(set) var defaultOutputID: AudioDeviceID?
    @Published private(set) var defaultInputID: AudioDeviceID?

    /// Called on the main thread after every refresh.
    var onChange: (() -> Void)?

    private var refreshWork: DispatchWorkItem?

    init() {
        refresh()
        installListeners()
    }

    var currentOutput: AudioDevice? { outputDevices.first { $0.id == defaultOutputID } }
    var currentInput: AudioDevice? { inputDevices.first { $0.id == defaultInputID } }

    /// Sets the default output device — and the sound-effects device with it,
    /// matching what System Settings does when you pick an output.
    @discardableResult
    func setDefaultOutput(_ device: AudioDevice) -> Bool {
        let ok = Self.setDefaultDevice(device.id, selector: kAudioHardwarePropertyDefaultOutputDevice)
        _ = Self.setDefaultDevice(device.id, selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
        if ok { refresh() }
        return ok
    }

    @discardableResult
    func setDefaultInput(_ device: AudioDevice) -> Bool {
        let ok = Self.setDefaultDevice(device.id, selector: kAudioHardwarePropertyDefaultInputDevice)
        if ok { refresh() }
        return ok
    }

    func refresh() {
        let all = Self.allDeviceIDs().compactMap(Self.describe)
        outputDevices = all.filter(\.hasOutput)
        inputDevices = all.filter(\.hasInput)
        defaultOutputID = Self.defaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice)
        defaultInputID = Self.defaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice)
        onChange?()
    }

    // MARK: - Change listeners

    private func installListeners() {
        let selectors: [AudioObjectPropertySelector] = [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultInputDevice
        ]
        for selector in selectors {
            var address = Self.address(selector)
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject),
                                                &address,
                                                DispatchQueue.main) { [weak self] _, _ in
                self?.scheduleRefresh()
            }
        }
    }

    /// Device arrivals fire several property changes back to back; coalesce.
    private func scheduleRefresh() {
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    // MARK: - CoreAudio plumbing

    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func allDeviceIDs() -> [AudioDeviceID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr,
              size > 0 else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr else {
            return []
        }
        return ids
    }

    private static func describe(_ id: AudioDeviceID) -> AudioDevice? {
        guard let uid = string(id, kAudioDevicePropertyDeviceUID),
              let name = string(id, kAudioObjectPropertyName) else { return nil }
        // Transient aggregates macOS creates internally are not user-facing.
        guard !uid.hasPrefix("CADefaultDeviceAggregate") else { return nil }
        let hasOutput = streamCount(id, scope: kAudioObjectPropertyScopeOutput) > 0
        let hasInput = streamCount(id, scope: kAudioObjectPropertyScopeInput) > 0
        guard hasOutput || hasInput else { return nil }
        return AudioDevice(id: id, uid: uid, name: name, transport: transportType(id),
                           hasOutput: hasOutput, hasInput: hasInput)
    }

    private static func string(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        guard AudioObjectHasProperty(id, &addr) else { return nil }
        var value: CFString?
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(id, &addr, 0, nil, &size, $0)
        }
        guard status == noErr, let value else { return nil }
        return value as String
    }

    private static func streamCount(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        var addr = address(kAudioDevicePropertyStreams, scope: scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &addr, 0, nil, &size) == noErr else { return 0 }
        return Int(size) / MemoryLayout<AudioStreamID>.size
    }

    private static func transportType(_ id: AudioObjectID) -> UInt32 {
        var addr = address(kAudioDevicePropertyTransportType)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &size, &value) == noErr else { return 0 }
        return value
    }

    private static func defaultDevice(selector: AudioObjectPropertySelector) -> AudioDeviceID? {
        var addr = address(selector)
        var value = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &value) == noErr,
              value != kAudioObjectUnknown else { return nil }
        return value
    }

    private static func setDefaultDevice(_ id: AudioDeviceID, selector: AudioObjectPropertySelector) -> Bool {
        var addr = address(selector)
        var value = id
        return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil,
                                          UInt32(MemoryLayout<AudioDeviceID>.size), &value) == noErr
    }
}
