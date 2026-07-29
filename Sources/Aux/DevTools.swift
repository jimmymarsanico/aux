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

/// `Aux --dump-icons <dir>`
/// Renders the menu bar glyph to a PNG so it can be eyeballed outside the menu bar.
func dumpIcons(to directory: String) -> Int32 {
    let dir = URL(fileURLWithPath: directory, isDirectory: true)
    do {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try writePNG(StatusIcon.headphones, to: dir.appendingPathComponent("menubar-headphones.png"))
    } catch {
        print("dump-icons: \(error.localizedDescription)")
        return 1
    }
    print("dump-icons: wrote menubar-headphones.png to \(dir.path)")
    return 0
}

private func writePNG(_ image: NSImage, to url: URL, scale: CGFloat = 8) throws {
    let pixelSize = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: Int(pixelSize.width),
                                     pixelsHigh: Int(pixelSize.height),
                                     bitsPerSample: 8,
                                     samplesPerPixel: 4,
                                     hasAlpha: true,
                                     isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0,
                                     bitsPerPixel: 0) else {
        throw CocoaError(.fileWriteUnknown)
    }
    rep.size = pixelSize
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(origin: .zero, size: pixelSize))
    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    try data.write(to: url)
}
