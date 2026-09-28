#!/usr/bin/env swift

// Renders both icon sets from one geometry. Run from the repo root:
//
//     swift scripts/generate_app_icon.swift
//
// Geometry and colour follow the shared look used across the phpz.xyz apps,
// measured off LinguaDock's master icon: a flat coral tile inset from the
// canvas, a 25% corner radius, and one solid white glyph. No gradients and no
// drop shadows — those were the two things that made this icon look unrelated
// to its siblings.
//
// The menu bar icon is generated from the same bookmark and W paths so the two
// cannot drift apart. It is a template image: black shape, transparent W, no
// tile — the system recolours it for light and dark menu bars.

import AppKit

private let appIconDirectory = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().first
        ?? "WordClip/Resources/Assets.xcassets/AppIcon.appiconset"
)
private let menuBarDirectory = URL(
    fileURLWithPath: CommandLine.arguments.dropFirst().dropFirst().first
        ?? "WordClip/Resources/Assets.xcassets/MenuBarIcon.imageset"
)
private let iconSizes = [16, 32, 64, 128, 256, 512, 1024]
private let menuBarScales = [(name: "menubar.png", size: 18), (name: "menubar@2x.png", size: 36), (name: "menubar@3x.png", size: 54)]

// Shared family values, expressed against a 1024 canvas.
private let tileColor = NSColor(red: 255 / 255, green: 103 / 255, blue: 77 / 255, alpha: 1)
private let canvasInset: CGFloat = 62      // 6.1% of the canvas on every side
private let cornerRadiusRatio: CGFloat = 0.25   // of the tile's width
private let glyphHeightRatio: CGFloat = 0.60    // of the tile's height

/// Bookmark outline: flat top, V notch cut out of the bottom.
/// Built in a unit box so it can be scaled to any icon size.
private func bookmarkPath(in rect: CGRect) -> NSBezierPath {
    let path = NSBezierPath()
    let corner = rect.width * 0.063
    let notch = rect.height * 0.214

    // Bottom-left tip, up the left edge, round the top-left corner.
    path.move(to: CGPoint(x: rect.minX, y: rect.minY + notch))
    path.line(to: CGPoint(x: rect.minX, y: rect.maxY - corner))
    path.appendArc(
        withCenter: CGPoint(x: rect.minX + corner, y: rect.maxY - corner),
        radius: corner, startAngle: 180, endAngle: 90, clockwise: true
    )
    // Along the flat top, round the top-right corner, down the right edge.
    path.line(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))
    path.appendArc(
        withCenter: CGPoint(x: rect.maxX - corner, y: rect.maxY - corner),
        radius: corner, startAngle: 90, endAngle: 0, clockwise: true
    )
    path.line(to: CGPoint(x: rect.maxX, y: rect.minY + notch))
    // The V notch, back to the start.
    path.line(to: CGPoint(x: rect.midX, y: rect.minY))
    path.close()
    return path
}

/// The "W", drawn as a stroked path rather than text: rendering text would
/// depend on which system font version the machine happens to ship.
/// Returns the path and the line width it must be stroked with.
/// `heightRatio` and `topInsetRatio` are fractions of the bookmark's height.
///
/// The app icon and the menu bar icon use the same values, so the mark reads
/// the same in the Dock and in the menu bar. They are sized for the menu bar:
/// an 18pt slot needs a W well above what the app icon alone would call for,
/// and at app icon sizes the larger W costs nothing — it survives the 16pt
/// Finder list, where the old smaller W turned to mush.
///
/// The centre sits at 42% of the bookmark's height (0.19 + 0.46/2), not higher.
/// The menu bar icon used to raise it to 37% for legibility, which made the W
/// look like it was floating out of the bookmark.
private func letterWPath(
    in glyphRect: CGRect,
    heightRatio: CGFloat = 0.46,
    topInsetRatio: CGFloat = 0.19
) -> (NSBezierPath, CGFloat) {
    let letterHeight = glyphRect.height * heightRatio
    let letterWidth = letterHeight * 1.22
    let rect = CGRect(
        x: glyphRect.midX - letterWidth / 2,
        y: glyphRect.maxY - glyphRect.height * topInsetRatio - letterHeight,
        width: letterWidth, height: letterHeight
    )
    // Heavy stroke to match the chunky glyph weight the family uses.
    let stroke = letterWidth * 0.26

    let path = NSBezierPath()
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.move(to: CGPoint(x: rect.minX + stroke / 2, y: rect.maxY))
    path.line(to: CGPoint(x: rect.minX + letterWidth * 0.30, y: rect.minY + stroke / 2))
    path.line(to: CGPoint(x: rect.midX, y: rect.maxY - letterHeight * 0.38))
    path.line(to: CGPoint(x: rect.maxX - letterWidth * 0.30, y: rect.minY + stroke / 2))
    path.line(to: CGPoint(x: rect.maxX - stroke / 2, y: rect.maxY))
    return (path, stroke)
}

private func renderIcon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { throw CocoaError(.fileWriteUnknown) }

    let scale = CGFloat(size) / 1024
    let canvas = CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))
    let tile = canvas.insetBy(dx: canvasInset * scale, dy: canvasInset * scale)
    let cornerRadius = tile.width * cornerRadiusRatio

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.current = context
    context.cgContext.clear(canvas)
    context.cgContext.interpolationQuality = .high

    tileColor.setFill()
    NSBezierPath(roundedRect: tile, xRadius: cornerRadius, yRadius: cornerRadius).fill()

    // Bookmark, centred on the tile.
    let glyphHeight = tile.height * glyphHeightRatio
    let glyphWidth = glyphHeight * 0.76
    let glyphRect = CGRect(
        x: tile.midX - glyphWidth / 2,
        y: tile.midY - glyphHeight / 2,
        width: glyphWidth, height: glyphHeight
    )
    NSColor.white.setFill()
    bookmarkPath(in: glyphRect).fill()

    tileColor.setStroke()
    let (w, strokeWidth) = letterWPath(in: glyphRect)
    w.lineWidth = strokeWidth
    w.stroke()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return data
}

/// Menu bar template image: black bookmark with the W punched through to
/// transparent, no tile. Same paths as the app icon, so the two stay in step.
private func renderMenuBarIcon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ) else { throw CocoaError(.fileWriteUnknown) }

    let canvas = CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))

    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.current = context
    context.cgContext.clear(canvas)
    context.cgContext.interpolationQuality = .high

    // The bookmark fills the height here — a menu bar slot is already small, so
    // the app icon's tile padding would only shrink the glyph further.
    let glyphHeight = canvas.height * 0.92
    let glyphWidth = glyphHeight * 0.76
    let glyphRect = CGRect(
        x: canvas.midX - glyphWidth / 2,
        y: canvas.midY - glyphHeight / 2,
        width: glyphWidth, height: glyphHeight
    )

    NSColor.black.setFill()
    bookmarkPath(in: glyphRect).fill()

    // Punch the W out rather than drawing it in a colour: a template image only
    // carries alpha, so anything non-transparent renders as one flat tint.
    context.cgContext.setBlendMode(.destinationOut)
    let (w, strokeWidth) = letterWPath(in: glyphRect)
    w.lineWidth = strokeWidth
    NSColor.black.setStroke()
    w.stroke()
    context.cgContext.setBlendMode(.normal)

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return data
}

let fileManager = FileManager.default
try fileManager.createDirectory(at: appIconDirectory, withIntermediateDirectories: true)
try fileManager.createDirectory(at: menuBarDirectory, withIntermediateDirectories: true)

for scale in menuBarScales {
    let data = try renderMenuBarIcon(size: scale.size)
    let url = menuBarDirectory.appendingPathComponent(scale.name)
    try data.write(to: url)
    print("wrote \(url.lastPathComponent) (\(scale.size)x\(scale.size), \(data.count) bytes)")
}

for size in iconSizes {
    let data = try renderIcon(size: size)
    let url = appIconDirectory.appendingPathComponent("icon_\(size).png")
    try data.write(to: url)
    print("wrote \(url.lastPathComponent) (\(size)x\(size), \(data.count) bytes)")
}
