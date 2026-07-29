import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let manager = AudioDeviceManager()
    private lazy var switcher = SwitchController(manager: manager, prefs: .shared)

    private var statusItem: NSStatusItem!
    private let menu = NSMenu()
    private lazy var settingsWindowController = SettingsWindowController(manager: manager)

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        menu.delegate = self
        statusItem.menu = menu

        manager.onChange = { [weak self] in self?.refreshStatusItem() }

        HotkeyCenter.shared.handlers[HotkeyID.cycleOutput] = { [weak self] in self?.switcher.cycleOutput() }
        HotkeyCenter.shared.handlers[HotkeyID.cycleInput] = { [weak self] in self?.switcher.cycleInput() }
        _ = HotkeyStore.shared // loads and registers any saved shortcuts

        refreshStatusItem()

        // First launch: open Settings so recording a shortcut is the obvious
        // next step, instead of a hotkey that silently does not exist yet.
        if Prefs.shared.consumeFirstLaunch() {
            openSettings()
        }
    }

    // MARK: - Menu

    /// The menu is rebuilt every time it opens, straight from CoreAudio state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === self.menu else { return }
        menu.removeAllItems()

        menu.addItem(header("Output"))
        if manager.outputDevices.isEmpty {
            menu.addItem(disabledItem("No output devices"))
        }
        for device in manager.outputDevices {
            menu.addItem(deviceItem(device, isInput: false))
        }

        menu.addItem(.separator())
        menu.addItem(header("Input"))
        if manager.inputDevices.isEmpty {
            menu.addItem(disabledItem("No input devices"))
        }
        for device in manager.inputDevices {
            menu.addItem(deviceItem(device, isInput: true))
        }

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let about = NSMenuItem(title: "About Aux", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Aux", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.attributedTitle = NSAttributedString(
            string: title.uppercased(),
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )
        return item
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        NSMenuItem(title: title, action: nil, keyEquivalent: "")
    }

    private func deviceItem(_ device: AudioDevice, isInput: Bool) -> NSMenuItem {
        let item = NSMenuItem(title: device.name,
                              action: isInput ? #selector(selectInput(_:)) : #selector(selectOutput(_:)),
                              keyEquivalent: "")
        item.target = self
        item.representedObject = device
        item.state = device.id == (isInput ? manager.defaultInputID : manager.defaultOutputID) ? .on : .off
        item.image = NSImage(systemSymbolName: isInput ? device.inputSymbolName : device.outputSymbolName,
                             accessibilityDescription: nil)
        return item
    }

    // MARK: - Actions

    @objc private func selectOutput(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AudioDevice else { return }
        switcher.switchOutput(to: device)
    }

    @objc private func selectInput(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AudioDevice else { return }
        switcher.switchInput(to: device)
    }

    @objc private func openSettings() {
        settingsWindowController.show()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    // MARK: - Status item

    /// The menu bar icon mirrors where audio is going right now.
    private func refreshStatusItem() {
        let symbolName = manager.currentOutput?.outputSymbolName ?? "speaker.slash"
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Aux")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 15, weight: .regular))
        statusItem.button?.image = image

        var parts: [String] = []
        if let output = manager.currentOutput { parts.append("Output: \(output.name)") }
        if let input = manager.currentInput { parts.append("Input: \(input.name)") }
        statusItem.button?.toolTip = parts.isEmpty ? "Aux" : "Aux — " + parts.joined(separator: " • ")
    }
}
