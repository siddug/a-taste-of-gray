import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    fputs("usage: generate-icon.swift <iconset-dir>\n", stderr)
    exit(2)
}

let iconsetURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconVariants: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (filename, side) in iconVariants {
    let image = makeIconImage(side: side)
    let destination = iconsetURL.appendingPathComponent(filename)
    try pngData(for: image).write(to: destination)
}

func makeIconImage(side: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: side, height: side))
    image.lockFocus()

    let rect = NSRect(origin: .zero, size: image.size)
    NSColor(calibratedWhite: 0.96, alpha: 1).setFill()
    let radius = side * 0.22
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

    let borderRect = rect.insetBy(dx: side * 0.02, dy: side * 0.02)
    NSColor(calibratedWhite: 0.82, alpha: 1).setStroke()
    let border = NSBezierPath(roundedRect: borderRect, xRadius: radius, yRadius: radius)
    border.lineWidth = max(1, side * 0.025)
    border.stroke()

    let symbolPointSize = side * 0.54
    let configuration = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
    let symbol = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration)

    let symbolSize = side * 0.58
    let symbolRect = NSRect(
        x: (side - symbolSize) / 2,
        y: (side - symbolSize) / 2,
        width: symbolSize,
        height: symbolSize
    )

    NSColor.black.set()
    symbol?.draw(in: symbolRect)

    image.unlockFocus()
    return image
}

func pngData(for image: NSImage) throws -> Data {
    guard
        let tiffData = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiffData),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconGen", code: 1)
    }

    return png
}
