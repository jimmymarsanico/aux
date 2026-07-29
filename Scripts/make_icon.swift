#!/usr/bin/env swift
//
// Builds Support/AppIcon.icns and assets/logo.png from the master artwork in
// assets/icon-master.png. The master is located by brightness (anything dark
// or transparent around it is discarded), scaled onto the standard macOS icon
// grid, and masked to a clean rounded square with transparent corners.
//
// Usage (from the repo root): swift Scripts/make_icon.swift

import AppKit
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func loadMaster() -> CGImage {
    let url = root.appendingPathComponent("assets/icon-master.png")
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        print("make_icon: could not read assets/icon-master.png")
        exit(1)
    }
    return image
}

/// Finds the bounding box of the artwork square: rows and columns where at
/// least half the pixels are meaningfully bright (the gradient), as opposed
/// to the dark or empty surroundings.
func artworkBounds(of image: CGImage) -> CGRect {
    let width = image.width
    let height = image.height
    guard let ctx = CGContext(data: nil, width: width, height: height,
                              bitsPerComponent: 8, bytesPerRow: width * 4,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
          let buffer = { () -> UnsafeMutablePointer<UInt8>? in
              ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
              return ctx.data?.assumingMemoryBound(to: UInt8.self)
          }() else {
        print("make_icon: could not rasterize master")
        exit(1)
    }

    var rowCounts = [Int](repeating: 0, count: height)
    var colCounts = [Int](repeating: 0, count: width)
    for y in 0..<height {
        for x in 0..<width {
            let p = (y * width + x) * 4
            let bright = Int(buffer[p]) + Int(buffer[p + 1]) + Int(buffer[p + 2])
            if buffer[p + 3] >= 200 && bright > 180 {
                rowCounts[y] += 1
                colCounts[x] += 1
            }
        }
    }

    guard let firstRow = rowCounts.firstIndex(where: { $0 > width / 2 }),
          let lastRow = rowCounts.lastIndex(where: { $0 > width / 2 }),
          let firstCol = colCounts.firstIndex(where: { $0 > height / 2 }),
          let lastCol = colCounts.lastIndex(where: { $0 > height / 2 }) else {
        print("make_icon: could not locate the artwork square in the master")
        exit(1)
    }

    // Row indices are in bitmap order; the rect below is in CG (y-up) space.
    return CGRect(x: CGFloat(firstCol),
                  y: CGFloat(height - 1 - lastRow),
                  width: CGFloat(lastCol - firstCol + 1),
                  height: CGFloat(lastRow - firstRow + 1))
}

let master = loadMaster()
let bounds = artworkBounds(of: master)

func render(_ pixels: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: pixels, height: pixels,
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let size = CGFloat(pixels)

    // Standard macOS icon grid: content square with a transparent margin.
    let margin = size * 100 / 1024
    let content = size * 824 / 1024
    let radius = size * 200 / 1024
    ctx.addPath(CGPath(roundedRect: CGRect(x: margin, y: margin, width: content, height: content),
                       cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.clip()

    // Scale the full master so its artwork square lands exactly on the grid.
    let scaleX = content / bounds.width
    let scaleY = content / bounds.height
    ctx.interpolationQuality = .high
    ctx.draw(master, in: CGRect(x: margin - bounds.minX * scaleX,
                                y: margin - bounds.minY * scaleY,
                                width: CGFloat(master.width) * scaleX,
                                height: CGFloat(master.height) * scaleY))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

do {
    let iconset = root.appendingPathComponent("build/AppIcon.iconset")
    try? FileManager.default.removeItem(at: iconset)
    try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

    let entries: [(String, Int)] = [
        ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
    ]
    for (name, pixels) in entries {
        writePNG(render(pixels), to: iconset.appendingPathComponent(name))
    }

    try FileManager.default.createDirectory(at: root.appendingPathComponent("Support"), withIntermediateDirectories: true)
    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Support/AppIcon.icns").path]
    try iconutil.run()
    iconutil.waitUntilExit()
    guard iconutil.terminationStatus == 0 else {
        print("iconutil failed with status \(iconutil.terminationStatus)")
        exit(1)
    }

    writePNG(render(512), to: root.appendingPathComponent("assets/logo.png"))
    print("Wrote Support/AppIcon.icns and assets/logo.png from icon-master.png")
} catch {
    print("make_icon failed: \(error.localizedDescription)")
    exit(1)
}
