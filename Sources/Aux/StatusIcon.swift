import AppKit

/// The menu bar glyph: headphones matching the app icon. Drawn by hand at
/// 18x18 so it sits correctly in the menu bar slot.
enum StatusIcon {
    static let headphones: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            // Band: an arch whose legs drop a little past the spring line.
            let band = NSBezierPath()
            band.move(to: NSPoint(x: 2.6, y: 7.2))
            band.line(to: NSPoint(x: 2.6, y: 9.2))
            band.appendArc(withCenter: NSPoint(x: 9, y: 9.2), radius: 6.4,
                           startAngle: 180, endAngle: 0, clockwise: true)
            band.line(to: NSPoint(x: 15.4, y: 7.2))
            band.lineWidth = 2.0
            band.lineCapStyle = .round
            band.stroke()

            // Ear cups.
            NSBezierPath(roundedRect: NSRect(x: 1.4, y: 1.6, width: 3.9, height: 5.6),
                         xRadius: 1.95, yRadius: 1.95).fill()
            NSBezierPath(roundedRect: NSRect(x: 12.7, y: 1.6, width: 3.9, height: 5.6),
                         xRadius: 1.95, yRadius: 1.95).fill()

            return true
        }
        image.isTemplate = true
        return image
    }()
}
