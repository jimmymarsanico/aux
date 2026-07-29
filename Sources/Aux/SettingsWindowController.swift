import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    convenience init(manager: AudioDeviceManager) {
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(manager: manager)))
        window.title = "Aux Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        if window?.isVisible != true { window?.center() }
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
