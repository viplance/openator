#!/usr/bin/env swift

import AppKit

let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

func drawAppIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    return NSImage(size: NSSize(width: s, height: s), flipped: true) { rect in
        let inset = s * 0.04
        let cr = s * 0.22
        let bg = rect.insetBy(dx: inset, dy: inset)
        let bgPath = NSBezierPath(roundedRect: bg, xRadius: cr, yRadius: cr)

        // Orange-to-gold gradient background
        let gradient = NSGradient(
            colors: [
                NSColor(calibratedRed: 1.0, green: 0.50, blue: 0.05, alpha: 1.0),
                NSColor(calibratedRed: 1.0, green: 0.80, blue: 0.10, alpha: 1.0),
            ],
            atLocations: [0.0, 1.0],
            colorSpace: .deviceRGB
        )!
        gradient.draw(in: bgPath, angle: -45)

        // Subtle inner shadow
        NSGraphicsContext.saveGraphicsState()
        bgPath.addClip()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.2)
        shadow.shadowOffset = NSSize(width: 0, height: -s * 0.02)
        shadow.shadowBlurRadius = s * 0.04
        shadow.set()
        bgPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        // Y-fork symbol
        let cx = s / 2
        let lw = s * 0.07
        let path = NSBezierPath()
        path.lineWidth = lw
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        let stemBottom = s * 0.76
        let junction = s * 0.46
        let branchTop = s * 0.22
        let spread = s * 0.20

        // Stem
        path.move(to: NSPoint(x: cx, y: stemBottom))
        path.line(to: NSPoint(x: cx, y: junction))
        // Left branch
        path.move(to: NSPoint(x: cx, y: junction))
        path.line(to: NSPoint(x: cx - spread, y: branchTop))
        // Right branch
        path.move(to: NSPoint(x: cx, y: junction))
        path.line(to: NSPoint(x: cx + spread, y: branchTop))

        NSColor.white.setStroke()
        path.stroke()

        // Dots at the three endpoints
        let dotR = lw * 0.85
        NSColor.white.setFill()
        for pt in [
            NSPoint(x: cx - spread, y: branchTop),
            NSPoint(x: cx + spread, y: branchTop),
            NSPoint(x: cx, y: stemBottom),
        ] {
            NSBezierPath(ovalIn: NSRect(
                x: pt.x - dotR, y: pt.y - dotR,
                width: dotR * 2, height: dotR * 2
            )).fill()
        }

        return true
    }
}

// Paths
let fm = FileManager.default
let projectDir = URL(fileURLWithPath: fm.currentDirectoryPath)
let assetsDir = projectDir.appendingPathComponent("assets")
let iconsetDir = assetsDir.appendingPathComponent("AppIcon.iconset")
let icnsPath = assetsDir.appendingPathComponent("icon.icns")

try? fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

print("Generating icon set…")
for (size, name) in sizes {
    let image = drawAppIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        print("  FAIL: \(name)")
        continue
    }
    try png.write(to: iconsetDir.appendingPathComponent(name))
    print("  \(name) (\(size)x\(size))")
}

print("Running iconutil…")
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath.path]
try proc.run()
proc.waitUntilExit()

try? fm.removeItem(at: iconsetDir)

if proc.terminationStatus == 0 {
    print("Created \(icnsPath.path)")
} else {
    print("iconutil failed with status \(proc.terminationStatus)")
    exit(1)
}
