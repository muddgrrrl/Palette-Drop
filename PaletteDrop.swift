import CoreGraphics
import Foundation
import ImageIO

struct Color: Hashable {
    let red: Int
    let green: Int
    let blue: Int

    var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }

    var contrastingInk: String {
        func linear(_ channel: Int) -> Double {
            let sRGB = Double(channel) / 255
            return sRGB <= 0.04045 ? sRGB / 12.92 : pow((sRGB + 0.055) / 1.055, 2.4)
        }
        let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        return (luminance + 0.05) / 0.05 >= 1.05 / (luminance + 0.05) ? "#000000" : "#FFFFFF"
    }

    func distance(to other: Color) -> Int {
        let dr = red - other.red, dg = green - other.green, db = blue - other.blue
        return dr * dr + dg * dg + db * db
    }
}

struct Swatch: Encodable {
    let hex: String
    let ink: String
}

enum PaletteError: LocalizedError {
    case unreadableImage, emptyImage, encoding
    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "Could not read the image."
        case .emptyImage: return "The image contains no sufficiently opaque pixels."
        case .encoding: return "Could not format the palette."
        }
    }
}

func sampledPixels(url: URL) throws -> [Color] {
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: 192
    ]
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
          let space = CGColorSpace(name: CGColorSpace.sRGB)
    else { throw PaletteError.unreadableImage }

    let width = image.width, height = image.height
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let rendered = bytes.withUnsafeMutableBytes { buffer in
        let format = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: space, bitmapInfo: format)
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard rendered else { throw PaletteError.unreadableImage }
    return stride(from: 0, to: bytes.count, by: 4).compactMap { i in
        let alpha = Int(bytes[i + 3])
        guard alpha >= 192 else { return nil }
        func restore(_ channel: UInt8) -> Int { min(255, (Int(channel) * 255 + alpha / 2) / alpha) }
        return Color(red: restore(bytes[i]), green: restore(bytes[i + 1]), blue: restore(bytes[i + 2]))
    }
}

func palette(_ pixels: [Color], limit: Int) -> [Color] {
    struct Bucket {
        var count = 0, red = 0, green = 0, blue = 0
        mutating func add(_ color: Color) {
            count += 1
            red += color.red
            green += color.green
            blue += color.blue
        }
        var average: Color { Color(red: red / count, green: green / count, blue: blue / count) }
    }
    var buckets: [Int: Bucket] = [:]
    for color in pixels {
        let key = (color.red / 32) * 64 + (color.green / 32) * 8 + color.blue / 32
        buckets[key, default: Bucket()].add(color)
    }
    let ranked = buckets.sorted { a, b in
        a.value.count == b.value.count ? a.key < b.key : a.value.count > b.value.count
    }
    var selected: [Color] = []
    for (_, bucket) in ranked {
        let color = bucket.average
        if selected.allSatisfy({ $0.distance(to: color) >= 38 * 38 }) {
            selected.append(color)
            if selected.count == limit { break }
        }
    }
    return selected
}

func run(_ args: [String]) throws -> Int32 {
    if args == ["--self-test"] {
        let red = Color(red: 220, green: 20, blue: 20)
        let blue = Color(red: 20, green: 20, blue: 220)
        precondition(palette([red, blue, red], limit: 2) == [red, blue])
        precondition(palette([], limit: 5).isEmpty)
        precondition(Color(red: 0, green: 0, blue: 0).contrastingInk == "#FFFFFF")
        precondition(Color(red: 255, green: 255, blue: 255).contrastingInk == "#000000")
        print("PASS: ranking, empty input and contrast")
        return 0
    }
    if args == ["--help"] || args.isEmpty {
        print("Usage: swift PaletteDrop.swift IMAGE [COUNT 1–12] [hex|css|json]")
        return args.isEmpty ? 2 : 0
    }
    let count = args.count > 1 ? Int(args[1]) : 5
    let format = args.count > 2 ? args[2] : "hex"
    guard args.count <= 3, let count, (1...12).contains(count), ["hex","css","json"].contains(format)
    else {
        FileHandle.standardError.write(Data("Use --help for the accepted arguments.\n".utf8))
        return 2
    }
    let colors = palette(try sampledPixels(url: URL(fileURLWithPath: args[0])), limit: count)
    guard !colors.isEmpty else { throw PaletteError.emptyImage }
    switch format {
    case "css":
        print(":root {")
        for (index, color) in colors.enumerated() {
            print("  --swatch-\(index + 1): \(color.hex);")
            print("  --swatch-\(index + 1)-ink: \(color.contrastingInk);")
        }
        print("}")
    case "json":
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let output = try encoder.encode(colors.map { Swatch(hex: $0.hex, ink: $0.contrastingInk) })
        guard let string = String(data: output, encoding: .utf8) else { throw PaletteError.encoding }
        print(string)
    default:
        for color in colors { print(color.hex) }
    }
    return 0
}

do {
    exit(try run(Array(CommandLine.arguments.dropFirst())))
} catch {
    FileHandle.standardError.write(Data("Palette Drop: \(error.localizedDescription)\n".utf8))
    exit(1)
}
