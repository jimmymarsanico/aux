import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A minimal shortcut recorder: click, type a combination, done.
/// Esc cancels; Delete removes the saved shortcut.
struct ShortcutRecorder: View {
    let label: String
    @Binding var hotkey: Hotkey?

    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
            Spacer()

            Button(action: toggleRecording) {
                Text(isRecording ? "Type shortcut…" : (hotkey?.display ?? "Record Shortcut"))
                    .frame(minWidth: 120)
            }

            if hotkey != nil && !isRecording {
                Button {
                    hotkey = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove shortcut")
            }
        }
        .onDisappear { stopRecording() }
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil // swallow the keystroke while recording
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }
        if event.keyCode == UInt16(kVK_Delete),
           event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            hotkey = nil
            stopRecording()
            return
        }
        guard let recorded = Hotkey(event: event) else {
            NSSound.beep() // needs ⌘, ⌥, or ⌃ (or an F-key)
            return
        }
        hotkey = recorded
        stopRecording()
    }
}
