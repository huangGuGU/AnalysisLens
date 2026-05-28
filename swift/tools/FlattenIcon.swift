import AppKit

guard CommandLine.arguments.count == 4 || CommandLine.arguments.count == 5 else {
    fputs("Usage: FlattenIcon <input.png> <output.png> <background-hex|none> [stroke-hex]\n", stderr)
    exit(64)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let backgroundHex = CommandLine.arguments[3]
let strokeHex = CommandLine.arguments.count == 5 ? CommandLine.arguments[4] : ""

func color(from hex: String) -> NSColor? {
    let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard trimmed.count == 6, let value = Int(trimmed, radix: 16) else {
        return nil
    }

    let red = CGFloat((value >> 16) & 0xff) / 255
    let green = CGFloat((value >> 8) & 0xff) / 255
    let blue = CGFloat(value & 0xff) / 255
    return NSColor(red: red, green: green, blue: blue, alpha: 1)
}

let background: NSColor?
if backgroundHex == "none" {
    background = nil
} else if let color = color(from: backgroundHex) {
    background = color
} else {
    fputs("Invalid background color: \(backgroundHex)\n", stderr)
    exit(64)
}

let stroke: NSColor?
if strokeHex.isEmpty {
    stroke = nil
} else if let color = color(from: strokeHex) {
    stroke = color
} else {
    fputs("Invalid stroke color: \(strokeHex)\n", stderr)
    exit(64)
}

guard let image = NSImage(contentsOf: inputURL),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Could not read icon image: \(inputURL.path)\n", stderr)
    exit(66)
}

let width = cgImage.width
let height = cgImage.height
guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                    pixelsWide: width,
                                    pixelsHigh: height,
                                    bitsPerSample: 8,
                                    samplesPerPixel: 4,
                                    hasAlpha: true,
                                    isPlanar: false,
                                    colorSpaceName: .deviceRGB,
                                    bytesPerRow: 0,
                                    bitsPerPixel: 0) else {
    fputs("Could not allocate output image\n", stderr)
    exit(70)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
if let background {
    background.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
}
NSGraphicsContext.current?.cgContext.interpolationQuality = .high
NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    .draw(in: NSRect(x: 0, y: 0, width: width, height: height),
          from: .zero,
          operation: .sourceOver,
          fraction: 1)
if let stroke, let bounds = alphaBounds(in: cgImage) {
    let lineWidth = max(4, CGFloat(width) / 220)
    let radius = min(bounds.width, bounds.height) * 0.18
    let strokeRect = bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
    let path = NSBezierPath(roundedRect: strokeRect,
                            xRadius: radius,
                            yRadius: radius)
    stroke.setStroke()
    path.lineWidth = lineWidth
    path.stroke()
}
NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not encode output PNG\n", stderr)
    exit(70)
}

try pngData.write(to: outputURL)

func alphaBounds(in cgImage: CGImage) -> NSRect? {
    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    let width = bitmap.pixelsWide
    let height = bitmap.pixelsHigh
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1

    for y in 0..<height {
        for x in 0..<width {
            guard let color = bitmap.colorAt(x: x, y: y), color.alphaComponent > 0.08 else {
                continue
            }
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }

    guard maxX >= minX, maxY >= minY else {
        return nil
    }

    return NSRect(x: minX,
                  y: height - maxY - 1,
                  width: maxX - minX + 1,
                  height: maxY - minY + 1)
}
