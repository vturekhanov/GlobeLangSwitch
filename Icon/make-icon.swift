// Draws the app icon (a white wireframe globe on a blue rounded square, on the macOS icon grid)
// and writes it as an .icns file. Usage: make-icon <AppIcon.icns> [preview.png]
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Draws on a 1024 × 1024 canvas. Small icons get thicker lines and fewer details.
func drawIcon(in context: CGContext, pixels: Int) {
    // Rounded square of the macOS icon grid, with a soft shadow and a vertical gradient.
    let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                      cornerWidth: 185, cornerHeight: 185, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: CGColor(gray: 0, alpha: 0.3))
    context.addPath(tile)
    context.setFillColor(CGColor(red: 0.04, green: 0.35, blue: 0.84, alpha: 1))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tile)
    context.clip()
    let colors = [CGColor(red: 0.28, green: 0.63, blue: 1, alpha: 1), CGColor(red: 0.04, green: 0.35, blue: 0.84, alpha: 1)]
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    context.restoreGState()

    // Globe: outline, meridians and parallels.
    let center = CGPoint(x: 512, y: 512), radius: CGFloat = 280
    let detailed = pixels > 32
    context.setStrokeColor(CGColor(gray: 1, alpha: 1))
    context.setLineWidth(max(28, 1.4 * 1024 / CGFloat(pixels)))  // at least 1.4 px wide
    context.setLineCap(.round)
    context.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: 2 * radius, height: 2 * radius))
    context.addEllipse(in: CGRect(x: center.x - radius * 0.45, y: center.y - radius, width: radius * 0.9, height: 2 * radius))
    for offset in detailed ? [-radius / 2, 0, radius / 2] : [0] {
        let half = (radius * radius - offset * offset).squareRoot()
        context.move(to: CGPoint(x: center.x - half, y: center.y + offset))
        context.addLine(to: CGPoint(x: center.x + half, y: center.y + offset))
    }
    if detailed {
        context.move(to: CGPoint(x: center.x, y: center.y - radius))
        context.addLine(to: CGPoint(x: center.x, y: center.y + radius))
    }
    context.strokePath()
}

/// The icon drawn at the given size, encoded as PNG.
func png(pixels: Int) -> Data {
    let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(in: context, pixels: pixels)
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Cannot encode PNG") }
    return data as Data
}

func bigEndian(_ value: Int) -> Data { withUnsafeBytes(of: UInt32(value).bigEndian) { Data($0) } }

// .icns: "icns" + file length, then entries of type + entry length + PNG data.
// Types: 16, 32 (16@2x), 32, 64 (32@2x), 128, 256 (128@2x), 256, 512 (256@2x), 512, 1024 (512@2x) px.
let entries = [("icp4", 16), ("ic11", 32), ("icp5", 32), ("ic12", 64), ("ic07", 128),
               ("ic13", 256), ("ic08", 256), ("ic14", 512), ("ic09", 512), ("ic10", 1024)]
var body = Data()
for (type, pixels) in entries {
    let image = png(pixels: pixels)
    body += Data(type.utf8) + bigEndian(image.count + 8) + image
}
let arguments = CommandLine.arguments
try (Data("icns".utf8) + bigEndian(body.count + 8) + body).write(to: URL(fileURLWithPath: arguments[1]))
if arguments.count > 2 { try png(pixels: 1024).write(to: URL(fileURLWithPath: arguments[2])) }
