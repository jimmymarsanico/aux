#!/usr/bin/env swift
//
// Generates Aux's app icon (Support/AppIcon.icns) and the README logo
// (assets/logo.png). Pure CoreGraphics — no design tools required.
//
// Usage (from the repo root): swift Scripts/make_icon.swift

import AppKit
import UniformTypeIdentifiers

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha)
}

// All geometry lives in a 1024x1024 canvas and is scaled down per size.
func drawIcon(into ctx: CGContext, canvas: CGFloat) {
    ctx.saveGState()
    let s = canvas / 1024
    ctx.scaleBy(x: s, y: s)

    // Background: rounded square, deep teal.
    let bgRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    ctx.addPath(CGPath(roundedRect: bgRect, cornerWidth: 185, cornerHeight: 185, transform: nil))
    ctx.clip()

    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                              colors: [color(0x14B8A6), color(0x0A3A34)] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 512, y: 924),
                           end: CGPoint(x: 512, y: 100),
                           options: [])

    // The aux plug, tilted toward the upper right, with sound waves
    // radiating from the tip.
    ctx.translateBy(x: 470, y: 470)
    ctx.rotate(by: -0.52) // ~30° clockwise

    drawPlug(ctx)
    drawWaves(ctx)

    ctx.restoreGState()
}

func drawPlug(_ ctx: CGContext) {
    let metal = color(0xE2E8F0)
    let band = color(0x0F172A)
    let body = color(0xF97316)

    // Tip (rounded).
    ctx.setFillColor(metal)
    ctx.addPath(CGPath(roundedRect: CGRect(x: -34, y: 180, width: 68, height: 120),
                       cornerWidth: 34, cornerHeight: 34, transform: nil))
    ctx.fillPath()

    // Insulating bands and the segments between them.
    ctx.setFillColor(band)
    ctx.fill(CGRect(x: -34, y: 150, width: 68, height: 34))
    ctx.setFillColor(metal)
    ctx.fill(CGRect(x: -34, y: 100, width: 68, height: 54))
    ctx.setFillColor(band)
    ctx.fill(CGRect(x: -34, y: 70, width: 68, height: 34))

    // Sleeve.
    ctx.setFillColor(metal)
    ctx.fill(CGRect(x: -34, y: -60, width: 68, height: 134))

    // Plastic handle.
    ctx.setFillColor(body)
    ctx.addPath(CGPath(roundedRect: CGRect(x: -65, y: -300, width: 130, height: 240),
                       cornerWidth: 36, cornerHeight: 36, transform: nil))
    ctx.fillPath()

    // Cable trailing off the handle.
    ctx.setStrokeColor(color(0x0F172A))
    ctx.setLineWidth(30)
    ctx.setLineCap(.round)
    ctx.beginPath()
    ctx.move(to: CGPoint(x: 0, y: -290))
    ctx.addCurve(to: CGPoint(x: 95, y: -390),
                 control1: CGPoint(x: 5, y: -350),
                 control2: CGPoint(x: 45, y: -390))
    ctx.strokePath()
}

func drawWaves(_ ctx: CGContext) {
    let center = CGPoint(x: 0, y: 310)
    let waves: [(radius: CGFloat, width: CGFloat, alpha: CGFloat)] = [
        (95, 22, 0.95), (160, 20, 0.7), (225, 18, 0.45)
    ]
    ctx.setLineCap(.round)
    for wave in waves {
        ctx.setStrokeColor(color(0xFFFFFF, wave.alpha))
        ctx.setLineWidth(wave.width)
        ctx.beginPath()
        ctx.addArc(center: center, radius: wave.radius,
                   startAngle: .pi * 0.25, endAngle: .pi * 0.75, clockwise: false)
        ctx.strokePath()
    }
}

func render(_ pixels: Int) -> CGImage {
    let ctx = CGContext(data: nil,
                        width: pixels,
                        height: pixels,
                        bitsPerComponent: 8,
                        bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    drawIcon(into: ctx, canvas: CGFloat(pixels))
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

do {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
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

    try FileManager.default.createDirectory(at: root.appendingPathComponent("assets"), withIntermediateDirectories: true)
    writePNG(render(512), to: root.appendingPathComponent("assets/logo.png"))

    print("Wrote Support/AppIcon.icns and assets/logo.png")
} catch {
    print("make_icon failed: \(error.localizedDescription)")
    exit(1)
}
