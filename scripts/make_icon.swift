// Renders the Around app icon: a proximity ripple on a deep teal field.
// Run: swift scripts/make_icon.swift (from the repo root)
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
// No alpha channel: App Store Connect rejects icons with transparency.
let context = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [r, g, b, a])!
}

// Background: diagonal deep-teal gradient.
let background = CGGradient(
    colorsSpace: nil,
    colors: [rgba(0.04, 0.42, 0.47), rgba(0.01, 0.13, 0.20)] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    background,
    start: CGPoint(x: 0, y: CGFloat(size)),
    end: CGPoint(x: CGFloat(size), y: 0),
    options: []
)

// Soft radial glow behind the ripples.
let center = CGPoint(x: 512, y: 512)
let glow = CGGradient(
    colorsSpace: nil,
    colors: [rgba(0.30, 0.85, 0.82, 0.50), rgba(0.30, 0.85, 0.82, 0.0)] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: 640, options: [])

// Ripple rings, fading and thinning as they travel outward.
let rings: [(radius: CGFloat, width: CGFloat, alpha: CGFloat)] = [
    (158, 40, 0.98),
    (280, 32, 0.62),
    (402, 26, 0.34),
]
for ring in rings {
    context.setStrokeColor(rgba(1, 1, 1, ring.alpha))
    context.setLineWidth(ring.width)
    context.strokeEllipse(in: CGRect(
        x: center.x - ring.radius, y: center.y - ring.radius,
        width: ring.radius * 2, height: ring.radius * 2
    ))
}

// You are here: the center dot.
let dotRadius: CGFloat = 66
context.setFillColor(rgba(1, 1, 1, 1))
context.fillEllipse(in: CGRect(
    x: center.x - dotRadius, y: center.y - dotRadius,
    width: dotRadius * 2, height: dotRadius * 2
))

let image = context.makeImage()!
let outputURL = URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try? FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true
)
let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL, UTType.png.identifier as CFString, 1, nil
)!
CGImageDestinationAddImage(destination, image, nil)
CGImageDestinationFinalize(destination)
print("wrote \(outputURL.path)")
