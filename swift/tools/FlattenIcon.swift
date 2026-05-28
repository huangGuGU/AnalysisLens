import AppKit

guard CommandLine.arguments.count == 4 else {
    fputs("Usage: FlattenIcon <input.png> <output.png> <background-hex>\n", stderr)
    exit(64)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let backgroundHex = CommandLine.arguments[3]

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

guard let background = color(from: backgroundHex) else {
    fputs("Invalid background color: \(backgroundHex)\n", stderr)
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
background.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
NSGraphicsContext.current?.cgContext.interpolationQuality = .high
NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
    .draw(in: NSRect(x: 0, y: 0, width: width, height: height),
          from: .zero,
          operation: .sourceOver,
          fraction: 1)
NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not encode output PNG\n", stderr)
    exit(70)
}

try pngData.write(to: outputURL)
