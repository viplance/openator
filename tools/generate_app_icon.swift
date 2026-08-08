#!/usr/bin/env swift

import AppKit

// All required macOS icon sizes (pixel size → filename)
let iconsetSizes: [(Int, String)] = [
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

// Asset catalog entries (logical size, scale, filename)
let catalogEntries: [(String, String, String)] = [
    ("16x16",   "1x", "icon_16x16.png"),
    ("16x16",   "2x", "icon_16x16@2x.png"),
    ("32x32",   "1x", "icon_32x32.png"),
    ("32x32",   "2x", "icon_32x32@2x.png"),
    ("128x128", "1x", "icon_128x128.png"),
    ("128x128", "2x", "icon_128x128@2x.png"),
    ("256x256", "1x", "icon_256x256.png"),
    ("256x256", "2x", "icon_256x256@2x.png"),
    ("512x512", "1x", "icon_512x512.png"),
    ("512x512", "2x", "icon_512x512@2x.png"),
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

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else { throw NSError(domain: "IconGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "PNG conversion failed"]) }
    try png.write(to: url)
}

// --- Paths ---
let fm = FileManager.default
let projectDir = URL(fileURLWithPath: fm.currentDirectoryPath)
let assetsDir = projectDir.appendingPathComponent("assets")
let iconsetDir = assetsDir.appendingPathComponent("AppIcon.iconset")
let icnsPath = assetsDir.appendingPathComponent("icon.icns")
let xcassetsDir = projectDir
    .appendingPathComponent("Assets.xcassets")
    .appendingPathComponent("AppIcon.appiconset")
let marketingIconPath = assetsDir.appendingPathComponent("AppStore-1024x1024.png")

// --- 1. Generate .icns (for app bundle) ---
print("=== Generating .icns ===")
try? fm.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

for (size, name) in iconsetSizes {
    let image = drawAppIcon(size: size)
    try savePNG(image, to: iconsetDir.appendingPathComponent(name))
    print("  \(name) (\(size)x\(size))")
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath.path]
try iconutil.run()
iconutil.waitUntilExit()
try? fm.removeItem(at: iconsetDir)

guard iconutil.terminationStatus == 0 else {
    print("iconutil failed with status \(iconutil.terminationStatus)")
    exit(1)
}
print("  → \(icnsPath.lastPathComponent)")

// --- 2. Generate Asset Catalog (for Xcode / App Store) ---
print("\n=== Generating Assets.xcassets ===")
try? fm.removeItem(at: xcassetsDir)
try fm.createDirectory(at: xcassetsDir, withIntermediateDirectories: true)

for (size, name) in iconsetSizes {
    let image = drawAppIcon(size: size)
    try savePNG(image, to: xcassetsDir.appendingPathComponent(name))
    print("  \(name)")
}

// Contents.json for the asset catalog
let contentsJSON = """
{
  "images": [
\(catalogEntries.map { size, scale, filename in
    "    {\"filename\": \"\(filename)\", \"idiom\": \"mac\", \"scale\": \"\(scale)\", \"size\": \"\(size)\"}"
}.joined(separator: ",\n"))
  ],
  "info": {
    "author": "openator",
    "version": 1
  }
}
"""
try contentsJSON.write(to: xcassetsDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("  Contents.json")

// Root-level Contents.json for Assets.xcassets
let rootContents = "{\"info\": {\"author\": \"openator\", \"version\": 1}}"
try rootContents.write(
    to: xcassetsDir.deletingLastPathComponent().appendingPathComponent("Contents.json"),
    atomically: true, encoding: .utf8
)

// --- 3. App Store marketing icon (1024x1024 standalone) ---
print("\n=== Generating App Store marketing icon ===")
let marketingImage = drawAppIcon(size: 1024)
try savePNG(marketingImage, to: marketingIconPath)
print("  → \(marketingIconPath.lastPathComponent)")

print("\nDone. All icons generated.")
