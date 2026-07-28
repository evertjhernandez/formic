#!/usr/bin/env swift

import AppKit
import Foundation

let projectRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesDirectory = projectRoot.appendingPathComponent("Resources", isDirectory: true)
let iconsetDirectory = resourcesDirectory.appendingPathComponent("FormicAppIcon.iconset", isDirectory: true)

try FileManager.default.createDirectory(
    at: iconsetDirectory,
    withIntermediateDirectories: true
)

let iconFiles: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for iconFile in iconFiles {
    let data = try renderIcon(pixels: iconFile.pixels)
    try data.write(to: iconsetDirectory.appendingPathComponent(iconFile.name), options: .atomic)
}

let preview = try renderIcon(pixels: 1024)
try preview.write(to: resourcesDirectory.appendingPathComponent("FormicAppIcon.png"), options: .atomic)

func renderIcon(pixels: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw IconGenerationError.couldNotCreateBitmap
    }

    let dimension = CGFloat(pixels)
    bitmap.size = NSSize(width: dimension, height: dimension)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    graphicsContext.shouldAntialias = true
    graphicsContext.imageInterpolation = .high

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: dimension, height: dimension).fill()

    let inset = dimension * 0.07
    let iconRect = NSRect(
        x: inset,
        y: inset,
        width: dimension - (inset * 2),
        height: dimension - (inset * 2)
    )
    let iconPath = NSBezierPath(
        roundedRect: iconRect,
        xRadius: dimension * 0.20,
        yRadius: dimension * 0.20
    )

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = dimension * 0.055
    shadow.shadowOffset = NSSize(width: 0, height: -dimension * 0.025)
    shadow.set()

    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 1.00, green: 0.48, blue: 0.24, alpha: 1),
        ending: NSColor(calibratedRed: 0.96, green: 0.25, blue: 0.10, alpha: 1)
    )
    gradient?.draw(in: iconPath, angle: -55)

    NSGraphicsContext.current?.saveGraphicsState()
    NSShadow().set()
    NSColor.white.withAlphaComponent(0.18).setStroke()
    iconPath.lineWidth = max(1, dimension * 0.008)
    iconPath.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()

    let symbolSize = dimension * 0.43
    let symbolConfiguration = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .bold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))

    if let baseSymbol = NSImage(systemSymbolName: "ant.fill", accessibilityDescription: nil),
       let symbol = baseSymbol.withSymbolConfiguration(symbolConfiguration) {
        symbol.draw(
            in: NSRect(
                x: (dimension - symbolSize) / 2,
                y: (dimension - symbolSize) / 2,
                width: symbolSize,
                height: symbolSize
            ),
            from: NSRect.zero,
            operation: NSCompositingOperation.sourceOver,
            fraction: 1
        )
    } else {
        throw IconGenerationError.missingSymbol
    }

    graphicsContext.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw IconGenerationError.couldNotEncodePNG
    }

    return data
}

enum IconGenerationError: Error {
    case couldNotCreateBitmap
    case couldNotEncodePNG
    case missingSymbol
}
