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

    NSShadow().set()
    let markInset = dimension * 0.22
    drawFormicMark(
        in: NSRect(
            x: markInset,
            y: markInset,
            width: dimension - (markInset * 2),
            height: dimension - (markInset * 2)
        )
    )

    graphicsContext.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw IconGenerationError.couldNotEncodePNG
    }

    return data
}

func drawFormicMark(in rect: NSRect) {
    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(
            x: rect.minX + (x * rect.width),
            y: rect.maxY - (y * rect.height)
        )
    }

    func polygon(_ coordinates: [(CGFloat, CGFloat)]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = coordinates.first else { return path }
        path.move(to: point(first.0, first.1))

        for coordinate in coordinates.dropFirst() {
            path.line(to: point(coordinate.0, coordinate.1))
        }

        path.close()
        return path
    }

    func polyline(_ coordinates: [(CGFloat, CGFloat)]) -> NSBezierPath {
        let path = NSBezierPath()
        guard let first = coordinates.first else { return path }
        path.move(to: point(first.0, first.1))

        for coordinate in coordinates.dropFirst() {
            path.line(to: point(coordinate.0, coordinate.1))
        }

        return path
    }

    let limbs: [[(CGFloat, CGFloat)]] = [
        [(0.43, 0.22), (0.36, 0.11), (0.24, 0.04)],
        [(0.57, 0.22), (0.64, 0.11), (0.76, 0.04)],
        [(0.38, 0.43), (0.23, 0.35), (0.11, 0.24)],
        [(0.62, 0.43), (0.77, 0.35), (0.89, 0.24)],
        [(0.37, 0.55), (0.22, 0.55), (0.10, 0.48)],
        [(0.63, 0.55), (0.78, 0.55), (0.90, 0.48)],
        [(0.40, 0.67), (0.25, 0.76), (0.14, 0.89)],
        [(0.60, 0.67), (0.75, 0.76), (0.86, 0.89)]
    ]

    NSColor.white.setStroke()
    for limb in limbs {
        let path = polyline(limb)
        path.lineWidth = max(1, rect.width * 0.045)
        path.lineCapStyle = .square
        path.lineJoinStyle = .miter
        path.stroke()
    }

    let bodyParts = [
        polygon([
            (0.43, 0.20), (0.57, 0.20), (0.63, 0.29),
            (0.57, 0.38), (0.43, 0.38), (0.37, 0.29)
        ]),
        polygon([
            (0.42, 0.40), (0.58, 0.40), (0.64, 0.52),
            (0.58, 0.64), (0.42, 0.64), (0.36, 0.52)
        ]),
        polygon([
            (0.42, 0.66), (0.58, 0.66), (0.69, 0.75),
            (0.69, 0.82), (0.60, 0.82), (0.60, 0.91),
            (0.50, 0.97), (0.34, 0.83), (0.34, 0.75)
        ]),
        polygon([
            (0.61, 0.84), (0.69, 0.84), (0.61, 0.91)
        ])
    ]

    NSColor.white.setFill()
    bodyParts.forEach { $0.fill() }
}

enum IconGenerationError: Error {
    case couldNotCreateBitmap
    case couldNotEncodePNG
}
