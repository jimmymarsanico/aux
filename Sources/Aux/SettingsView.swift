import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var manager: AudioDeviceManager
    @ObservedObject private var store = HotkeyStore.shared
    @ObservedObject private var prefs = Prefs.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                ShortcutRecorder(label: "Cycle output device:", hotkey: $store.cycleOutput)
                ShortcutRecorder(label: "Cycle input device:", hotkey: $store.cycleInput)
            }

            Divider()

            cycleSection(title: "Outputs in the cycle",
                         devices: manager.outputDevices,
                         excluded: $prefs.excludedOutputUIDs)

            cycleSection(title: "Inputs in the cycle",
                         devices: manager.inputDevices,
                         excluded: $prefs.excludedInputUIDs)

            Divider()

            Toggle("Launch Aux at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { enabled in
                    setLaunchAtLogin(enabled)
                }
        }
        .padding(20)
        .frame(width: 380)
    }

    @ViewBuilder
    private func cycleSection(title: String, devices: [AudioDevice], excluded: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            if devices.isEmpty {
                Text("No devices found")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(devices) { device in
                Toggle(device.name, isOn: Binding(
                    get: { !excluded.wrappedValue.contains(device.uid) },
                    set: { include in
                        if include {
                            excluded.wrappedValue.remove(device.uid)
                        } else {
                            excluded.wrappedValue.insert(device.uid)
                        }
                    }
                ))
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Aux: launch at login change failed: \(error.localizedDescription)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
