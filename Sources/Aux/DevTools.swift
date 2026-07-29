import AppKit

/// `Aux --smoke-test`
/// Verifies device enumeration and the default-device write path. Used by CI,
/// where runners may have zero audio devices — that is not a failure.
func runSmokeTest() -> Int32 {
    let manager = AudioDeviceManager()

    print("smoke-test: \(manager.outputDevices.count) output(s), \(manager.inputDevices.count) input(s)")
    for device in manager.outputDevices {
        let marker = device.id == manager.defaultOutputID ? "  ← default" : ""
        print("  out: \(device.name) [\(device.transportName)]\(marker)")
    }
    for device in manager.inputDevices {
        let marker = device.id == manager.defaultInputID ? "  ← default" : ""
        print("  in:  \(device.name) [\(device.transportName)]\(marker)")
    }

    guard let current = manager.currentOutput else {
        print("smoke-test: no default output device (headless machine?) — skipping switch check, OK")
        return 0
    }

    // Re-assert the current default: exercises the write path without
    // audibly changing anything on the machine running the test.
    guard manager.setDefaultOutput(current) else {
        print("smoke-test: failed to re-assert default output '\(current.name)'")
        return 1
    }
    print("smoke-test: re-asserted default output '\(current.name)' — OK")
    return 0
}
