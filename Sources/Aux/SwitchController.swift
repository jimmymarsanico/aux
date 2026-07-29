import Foundation

/// The verbs behind the hotkeys and menu clicks.
final class SwitchController {
    private let manager: AudioDeviceManager
    private let prefs: Prefs

    init(manager: AudioDeviceManager, prefs: Prefs) {
        self.manager = manager
        self.prefs = prefs
    }

    // MARK: - Hotkey actions (with HUD feedback)

    func cycleOutput() {
        let cycle = manager.outputDevices.filter { !prefs.excludedOutputUIDs.contains($0.uid) }
        guard !cycle.isEmpty else {
            HUD.shared.show(symbol: "speaker.slash", text: "No output devices in cycle")
            return
        }
        let index = cycle.firstIndex { $0.id == manager.defaultOutputID } ?? -1
        let next = cycle[(index + 1) % cycle.count]
        switchOutput(to: next, showHUD: true)
    }

    func cycleInput() {
        let cycle = manager.inputDevices.filter { !prefs.excludedInputUIDs.contains($0.uid) }
        guard !cycle.isEmpty else {
            HUD.shared.show(symbol: "mic.slash", text: "No input devices in cycle")
            return
        }
        let index = cycle.firstIndex { $0.id == manager.defaultInputID } ?? -1
        let next = cycle[(index + 1) % cycle.count]
        switchInput(to: next, showHUD: true)
    }

    // MARK: - Direct switching (menu clicks)

    func switchOutput(to device: AudioDevice, showHUD: Bool = false) {
        let ok = manager.setDefaultOutput(device)
        if showHUD {
            HUD.shared.show(symbol: ok ? device.outputSymbolName : "exclamationmark.triangle",
                            text: ok ? device.name : "Couldn't switch output")
        }
    }

    func switchInput(to device: AudioDevice, showHUD: Bool = false) {
        let ok = manager.setDefaultInput(device)
        if showHUD {
            HUD.shared.show(symbol: ok ? device.inputSymbolName : "exclamationmark.triangle",
                            text: ok ? device.name : "Couldn't switch input")
        }
    }
}
