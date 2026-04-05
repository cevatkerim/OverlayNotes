import AppKit
import CoreImage
import Foundation

struct IconPalette {
    let canvasTop: NSColor
    let canvasBottom: NSColor
    let paper: NSColor
    let paperShade: NSColor
    let paperEdge: NSColor
    let accent: NSColor
    let accentDeep: NSColor
    let ink: NSColor
    let shadow: NSColor
}

enum IconStyle: String, CaseIterable {
    case crest
    case feather
    case editorial
    case monogram

    var palette: IconPalette {
        IconPalette(
            canvasTop: NSColor(srgbRed: 0.995, green: 0.992, blue: 0.985, alpha: 1),
            canvasBottom: NSColor(srgbRed: 0.945, green: 0.948, blue: 0.955, alpha: 1),
            paper: NSColor(srgbRed: 1.0, green: 1.0, blue: 1.0, alpha: 1),
            paperShade: NSColor(srgbRed: 0.955, green: 0.962, blue: 0.972, alpha: 1),
            paperEdge: NSColor(srgbRed: 0.835, green: 0.848, blue: 0.872, alpha: 1),
            accent: NSColor(srgbRed: 0.86, green: 0.20, blue: 0.22, alpha: 1),
            accentDeep: NSColor(srgbRed: 0.60, green: 0.07, blue: 0.13, alpha: 1),
            ink: NSColor(srgbRed: 0.22, green: 0.25, blue: 0.31, alpha: 1),
            shadow: NSColor(srgbRed: 0.16, green: 0.19, blue: 0.23, alpha: 0.18)
        )
    }
}

private let fileManager = FileManager.default
private let repoRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
private let generatedDir = repoRoot.appendingPathComponent("Generated", isDirectory: true)
private let generatedIconsDir = generatedDir.appendingPathComponent("AppIcons", isDirectory: true)
private let generatedAppIconSetDir = generatedIconsDir.appendingPathComponent("AppIcon.appiconset", isDirectory: true)
private let appAssetsIconSetDir = repoRoot.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
private let bundledAppIcon = repoRoot.appendingPathComponent("Sources/Resources/AppIcon.png")
private let exactPrimaryIconSource = repoRoot.appendingPathComponent("Sources/Resources/AppIconPrimarySource.png")
private let importedAppIconSource = repoRoot.appendingPathComponent("Sources/Resources/AppIconSource.png")
private let masterSize = CGSize(width: 1024, height: 1024)

try fileManager.createDirectory(at: generatedIconsDir, withIntermediateDirectories: true)
try fileManager.createDirectory(at: generatedAppIconSetDir, withIntermediateDirectories: true)
try fileManager.createDirectory(at: appAssetsIconSetDir, withIntermediateDirectories: true)

for style in IconStyle.allCases {
    let image = render(style: style, size: masterSize)
    let output = generatedIconsDir.appendingPathComponent("overlay-notes-\(style.rawValue)-1024.png")
    try savePNG(image: image, to: output)
}

if fileManager.fileExists(atPath: importedAppIconSource.path) {
    let imported = try renderImportedPrimaryIcon(from: importedAppIconSource, size: masterSize)
    try savePNG(image: imported, to: generatedIconsDir.appendingPathComponent("overlay-notes-imported-1024.png"))
}

let primaryImage: NSImage
if fileManager.fileExists(atPath: exactPrimaryIconSource.path),
   let exact = NSImage(contentsOf: exactPrimaryIconSource) {
    let directPrimary = resize(image: exact, to: masterSize)
    try savePNG(image: directPrimary, to: generatedIconsDir.appendingPathComponent("overlay-notes-primary-exact-1024.png"))
    primaryImage = directPrimary
} else {
    primaryImage = render(style: .crest, size: masterSize)
}

try savePNG(image: primaryImage, to: bundledAppIcon)

let iconSpecs: [(name: String, points: CGFloat, scale: Int)] = [
    ("icon-16@1x.png", 16, 1),
    ("icon-16@2x.png", 16, 2),
    ("icon-32@1x.png", 32, 1),
    ("icon-32@2x.png", 32, 2),
    ("icon-128@1x.png", 128, 1),
    ("icon-128@2x.png", 128, 2),
    ("icon-256@1x.png", 256, 1),
    ("icon-256@2x.png", 256, 2),
    ("icon-512@1x.png", 512, 1),
    ("icon-512@2x.png", 512, 2)
]

for spec in iconSpecs {
    let pixelSize = Int(spec.points) * spec.scale
    let resized = resize(image: primaryImage, to: CGSize(width: pixelSize, height: pixelSize))
    try savePNG(image: resized, to: generatedAppIconSetDir.appendingPathComponent(spec.name))
    try savePNG(image: resized, to: appAssetsIconSetDir.appendingPathComponent(spec.name))
}

let contentsJSON = """
{
  "images" : [
    { "filename" : "icon-16@1x.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon-16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon-32@1x.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon-32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon-128@1x.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon-128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon-256@1x.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon-256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon-512@1x.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon-512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "codex",
    "version" : 1
  }
}
"""

for destination in [generatedAppIconSetDir, appAssetsIconSetDir] {
    try contentsJSON.write(
        to: destination.appendingPathComponent("Contents.json"),
        atomically: true,
        encoding: .utf8
    )
}

print("Generated app icons in \(generatedIconsDir.path)")

func render(style: IconStyle, size: CGSize) -> NSImage {
    let image = NSImage(size: size)
    image.lockFocus()
    drawIcon(style: style, size: size)
    image.unlockFocus()
    return image
}

func drawIcon(style: IconStyle, size: CGSize) {
    let palette = style.palette
    let rect = CGRect(origin: .zero, size: size)
    let tileRect = rect.insetBy(dx: 40, dy: 40)

    drawCanvas(in: tileRect, palette: palette)

    switch style {
    case .crest:
        drawCrestIcon(in: tileRect, palette: palette)
    case .feather:
        drawFeatherPagesIcon(in: tileRect, palette: palette)
    case .editorial:
        drawEditorialIcon(in: tileRect, palette: palette)
    case .monogram:
        drawMonogramIcon(in: tileRect, palette: palette)
    }
}

func drawCanvas(in rect: CGRect, palette: IconPalette) {
    let tilePath = NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220)

    withShadow(color: palette.shadow, blur: 48, offset: CGSize(width: 0, height: -20)) {
        let gradient = NSGradient(colors: [palette.canvasTop, palette.canvasBottom])!
        gradient.draw(in: tilePath, angle: -90)
    }

    let glowRect = rect.insetBy(dx: 90, dy: 120).offsetBy(dx: 0, dy: 80)
    let glow = NSBezierPath(ovalIn: glowRect)
    NSColor.white.withAlphaComponent(0.82).setFill()
    glow.fill()

    let border = NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: 218, yRadius: 218)
    NSColor.white.withAlphaComponent(0.65).setStroke()
    border.lineWidth = 4
    border.stroke()
}

func drawFeatherPagesIcon(in rect: CGRect, palette: IconPalette) {
    let backLeft = CGRect(x: rect.minX + 176, y: rect.minY + 290, width: 484, height: 530)
    let backRight = CGRect(x: rect.minX + 302, y: rect.minY + 250, width: 484, height: 530)
    let front = CGRect(x: rect.minX + 228, y: rect.minY + 186, width: 560, height: 610)

    drawPaperSheet(
        rect: backLeft,
        palette: palette,
        rotationDegrees: -8,
        isFront: false,
        lineLayout: [],
        accentLineIndex: nil
    )
    drawPaperSheet(
        rect: backRight,
        palette: palette,
        rotationDegrees: 7,
        isFront: false,
        lineLayout: [],
        accentLineIndex: nil
    )
    drawPaperSheet(
        rect: front,
        palette: palette,
        rotationDegrees: 0,
        isFront: true,
        lineLayout: [0.72, 0.62, 0.79, 0.54],
        accentLineIndex: 2
    )

    drawFeather(
        center: CGPoint(x: rect.minX + 618, y: rect.minY + 558),
        scale: 1,
        angleDegrees: -29,
        palette: palette
    )
}

func drawCrestIcon(in rect: CGRect, palette: IconPalette) {
    let circleRect = CGRect(x: rect.minX + 202, y: rect.minY + 200, width: 580, height: 580)
    let circlePath = NSBezierPath(ovalIn: circleRect)

    withShadow(color: palette.shadow.withAlphaComponent(0.22), blur: 22, offset: CGSize(width: 0, height: -8)) {
        let circleGradient = NSGradient(colors: [
            NSColor(srgbRed: 0.99, green: 0.27, blue: 0.34, alpha: 1),
            NSColor(srgbRed: 0.79, green: 0.10, blue: 0.18, alpha: 1)
        ])!
        circleGradient.draw(in: circlePath, relativeCenterPosition: NSPoint(x: -0.22, y: 0.34))
    }

    let highlight = NSBezierPath(ovalIn: CGRect(x: circleRect.minX + 68, y: circleRect.midY + 70, width: 220, height: 118))
    NSColor.white.withAlphaComponent(0.12).setFill()
    highlight.fill()

    drawFeatherSilhouette(
        center: CGPoint(x: circleRect.midX - 4, y: circleRect.midY - 12),
        scale: 0.98,
        angleDegrees: -36,
        fill: NSColor.white,
        detail: palette.accentDeep.withAlphaComponent(0.18)
    )
}

func drawEditorialIcon(in rect: CGRect, palette: IconPalette) {
    let page = CGRect(x: rect.minX + 244, y: rect.minY + 168, width: 540, height: 646)
    drawPaperSheet(
        rect: page,
        palette: palette,
        rotationDegrees: 0,
        isFront: true,
        lineLayout: [0.76, 0.64, 0.83, 0.57, 0.72],
        accentLineIndex: 3
    )

    let redMark = NSBezierPath()
    redMark.move(to: CGPoint(x: page.minX + 132, y: page.maxY - 154))
    redMark.curve(
        to: CGPoint(x: page.maxX - 126, y: page.minY + 168),
        controlPoint1: CGPoint(x: page.minX + 210, y: page.maxY - 118),
        controlPoint2: CGPoint(x: page.maxX - 198, y: page.minY + 240)
    )
    palette.accent.setStroke()
    redMark.lineWidth = 42
    redMark.lineCapStyle = .round
    redMark.stroke()

    let nib = NSBezierPath()
    nib.move(to: CGPoint(x: page.maxX - 154, y: page.minY + 146))
    nib.line(to: CGPoint(x: page.maxX - 106, y: page.minY + 98))
    nib.line(to: CGPoint(x: page.maxX - 178, y: page.minY + 78))
    nib.close()
    palette.accentDeep.setFill()
    nib.fill()
}

func drawMonogramIcon(in rect: CGRect, palette: IconPalette) {
    let outer = CGRect(x: rect.minX + 196, y: rect.minY + 184, width: 612, height: 612)
    let inner = outer.insetBy(dx: 136, dy: 136)

    drawPaperSheet(
        rect: CGRect(x: rect.minX + 256, y: rect.minY + 248, width: 512, height: 560),
        palette: palette,
        rotationDegrees: 0,
        isFront: false,
        lineLayout: [],
        accentLineIndex: nil
    )

    let outerPath = NSBezierPath(ovalIn: outer)
    let innerPath = NSBezierPath(ovalIn: inner)
    outerPath.append(innerPath.reversed)
    NSColor.white.withAlphaComponent(0.98).setFill()
    outerPath.fill()

    let split = NSBezierPath()
    split.move(to: CGPoint(x: outer.midX + 54, y: outer.maxY - 92))
    split.curve(
        to: CGPoint(x: outer.midX + 54, y: outer.minY + 92),
        controlPoint1: CGPoint(x: outer.midX + 160, y: outer.maxY - 220),
        controlPoint2: CGPoint(x: outer.midX + 160, y: outer.minY + 220)
    )
    split.lineWidth = 84
    palette.canvasBottom.withAlphaComponent(0.92).setStroke()
    split.lineCapStyle = .round
    split.stroke()

    drawFeather(
        center: CGPoint(x: rect.minX + 636, y: rect.minY + 446),
        scale: 0.76,
        angleDegrees: -18,
        palette: palette
    )
}

func renderImportedPrimaryIcon(from url: URL, size: CGSize) throws -> NSImage {
    guard let source = NSImage(contentsOf: url) else {
        throw NSError(
            domain: "IconGeneration",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Failed to load imported icon source at \(url.path)"]
        )
    }

    let palette = IconStyle.feather.palette
    let cleanedArtwork = try cleanedImportedArtwork(from: source)

    let image = NSImage(size: size)
    image.lockFocus()

    let rect = CGRect(origin: .zero, size: size)
    let tileRect = rect.insetBy(dx: 40, dy: 40)
    drawCanvas(in: tileRect, palette: palette)

    let artBounds = fit(
        size: cleanedArtwork.size,
        into: tileRect.insetBy(dx: 92, dy: 92).offsetBy(dx: 0, dy: 8)
    )

    withShadow(color: palette.shadow.withAlphaComponent(0.28), blur: 28, offset: CGSize(width: 0, height: -10)) {
        cleanedArtwork.draw(in: artBounds, from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    image.unlockFocus()
    return image
}

func cleanedImportedArtwork(from image: NSImage) throws -> NSImage {
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: [.interpolation: NSImageInterpolation.high]) else {
        throw NSError(
            domain: "IconGeneration",
            code: 3,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage from imported icon source"]
        )
    }

    let width = cgImage.width
    let height = cgImage.height
    let bytesPerRow = width * 4
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    ) else {
        throw NSError(
            domain: "IconGeneration",
            code: 4,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap context for imported icon source"]
        )
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let data = context.data else {
        throw NSError(
            domain: "IconGeneration",
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: "Failed to access bitmap data for imported icon source"]
        )
    }

    let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
    var minX = width
    var minY = height
    var maxX = 0
    var maxY = 0
    var foundOpaquePixel = false

    for y in 0..<height {
        for x in 0..<width {
            let offset = (y * bytesPerRow) + (x * 4)
            let red = CGFloat(pixels[offset]) / 255
            let green = CGFloat(pixels[offset + 1]) / 255
            let blue = CGFloat(pixels[offset + 2]) / 255
            let baseAlpha = CGFloat(pixels[offset + 3]) / 255

            let maxChannel = max(red, green, blue)
            let minChannel = min(red, green, blue)
            let saturation = maxChannel > 0 ? (maxChannel - minChannel) / maxChannel : 0
            let brightness = (red + green + blue) / 3
            let darkness = 1 - brightness
            let chromaPresence = smoothstep(edge0: 0.06, edge1: 0.18, x: saturation)
            let inkPresence = smoothstep(edge0: 0.18, edge1: 0.44, x: darkness)
            let alphaFactor = max(chromaPresence, inkPresence)
            let finalAlpha = min(max(baseAlpha * alphaFactor, 0), 1)

            pixels[offset] = UInt8(CGFloat(pixels[offset]) * alphaFactor)
            pixels[offset + 1] = UInt8(CGFloat(pixels[offset + 1]) * alphaFactor)
            pixels[offset + 2] = UInt8(CGFloat(pixels[offset + 2]) * alphaFactor)
            pixels[offset + 3] = UInt8(finalAlpha * 255)

            if finalAlpha > 0.03 {
                foundOpaquePixel = true
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
    }

    guard foundOpaquePixel, let processedImage = context.makeImage() else {
        throw NSError(
            domain: "IconGeneration",
            code: 6,
            userInfo: [NSLocalizedDescriptionKey: "Imported icon cleanup removed all visible pixels"]
        )
    }

    let padding = 76
    let cropRect = CGRect(
        x: max(minX - padding, 0),
        y: max(minY - padding, 0),
        width: min((maxX - minX) + (padding * 2), width - max(minX - padding, 0)),
        height: min((maxY - minY) + (padding * 2), height - max(minY - padding, 0))
    ).integral

    guard let cropped = processedImage.cropping(to: cropRect) else {
        throw NSError(
            domain: "IconGeneration",
            code: 7,
            userInfo: [NSLocalizedDescriptionKey: "Failed to crop cleaned imported icon artwork"]
        )
    }

    let ciContext = CIContext(options: nil)
    let croppedCI = CIImage(cgImage: cropped)
    let sharpen = CIFilter(name: "CIUnsharpMask")!
    sharpen.setValue(croppedCI, forKey: kCIInputImageKey)
    sharpen.setValue(1.0, forKey: kCIInputRadiusKey)
    sharpen.setValue(0.32, forKey: kCIInputIntensityKey)

    let outputImage = sharpen.outputImage ?? croppedCI
    guard let finalCG = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
        throw NSError(
            domain: "IconGeneration",
            code: 8,
            userInfo: [NSLocalizedDescriptionKey: "Failed to render cleaned imported icon artwork"]
        )
    }

    return NSImage(cgImage: finalCG, size: NSSize(width: finalCG.width, height: finalCG.height))
}

func drawPaperSheet(
    rect: CGRect,
    palette: IconPalette,
    rotationDegrees: CGFloat,
    isFront: Bool,
    lineLayout: [CGFloat],
    accentLineIndex: Int?
) {
    NSGraphicsContext.saveGraphicsState()

    if let context = NSGraphicsContext.current?.cgContext, rotationDegrees != 0 {
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: (rotationDegrees * .pi) / 180)
        context.translateBy(x: -rect.midX, y: -rect.midY)
    }

    let shadowColor = isFront ? palette.shadow : palette.shadow.withAlphaComponent(0.13)
    withShadow(color: shadowColor, blur: isFront ? 32 : 20, offset: CGSize(width: 0, height: -16)) {
        let sheetPath = NSBezierPath(roundedRect: rect, xRadius: 86, yRadius: 86)
        let fillGradient = NSGradient(colors: [
            palette.paper,
            isFront ? palette.paper : palette.paperShade
        ])!
        fillGradient.draw(in: sheetPath, angle: -90)

        palette.paperEdge.withAlphaComponent(isFront ? 0.68 : 0.48).setStroke()
        sheetPath.lineWidth = 5
        sheetPath.stroke()

        let shine = NSBezierPath(
            roundedRect: CGRect(
                x: rect.minX + 44,
                y: rect.maxY - 108,
                width: rect.width * 0.54,
                height: 54
            ),
            xRadius: 27,
            yRadius: 27
        )
        NSColor.white.withAlphaComponent(0.76).setFill()
        shine.fill()
    }

    if isFront {
        drawFoldedCorner(in: rect, palette: palette)
        drawNoteLines(in: rect, palette: palette, widths: lineLayout, accentLineIndex: accentLineIndex)
    }

    NSGraphicsContext.restoreGraphicsState()
}

func drawFoldedCorner(in rect: CGRect, palette: IconPalette) {
    let foldWidth: CGFloat = 94
    let foldHeight: CGFloat = 94
    let fold = NSBezierPath()
    fold.move(to: CGPoint(x: rect.maxX - foldWidth, y: rect.maxY))
    fold.line(to: CGPoint(x: rect.maxX, y: rect.maxY))
    fold.line(to: CGPoint(x: rect.maxX, y: rect.maxY - foldHeight))
    fold.close()
    palette.paperShade.setFill()
    fold.fill()

    let crease = NSBezierPath()
    crease.move(to: CGPoint(x: rect.maxX - foldWidth, y: rect.maxY))
    crease.line(to: CGPoint(x: rect.maxX, y: rect.maxY - foldHeight))
    palette.paperEdge.withAlphaComponent(0.72).setStroke()
    crease.lineWidth = 4
    crease.stroke()
}

func drawNoteLines(in rect: CGRect, palette: IconPalette, widths: [CGFloat], accentLineIndex: Int?) {
    let linesRect = CGRect(
        x: rect.minX + 78,
        y: rect.minY + 114,
        width: rect.width - 156,
        height: rect.height - 208
    )
    let spacing = linesRect.height / CGFloat(widths.count + 1)

    for (index, widthFactor) in widths.enumerated() {
        let lineRect = CGRect(
            x: linesRect.minX,
            y: linesRect.maxY - CGFloat(index + 1) * spacing,
            width: linesRect.width * widthFactor,
            height: index == 0 ? 24 : 20
        )
        let path = NSBezierPath(roundedRect: lineRect, xRadius: lineRect.height / 2, yRadius: lineRect.height / 2)
        let fill: NSColor
        if accentLineIndex == index {
            fill = palette.accent.withAlphaComponent(0.82)
        } else {
            fill = palette.ink.withAlphaComponent(index == 0 ? 0.28 : 0.18)
        }
        fill.setFill()
        path.fill()
    }
}

func drawFeatherSilhouette(center: CGPoint, scale: CGFloat, angleDegrees: CGFloat, fill: NSColor, detail: NSColor) {
    NSGraphicsContext.saveGraphicsState()
    if let context = NSGraphicsContext.current?.cgContext {
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: (angleDegrees * .pi) / 180)
        context.scaleBy(x: scale, y: scale)
    }

    let featherPath = NSBezierPath()
    featherPath.move(to: CGPoint(x: 0, y: 228))
    featherPath.curve(
        to: CGPoint(x: -48, y: 112),
        controlPoint1: CGPoint(x: -8, y: 198),
        controlPoint2: CGPoint(x: -44, y: 154)
    )
    featherPath.curve(
        to: CGPoint(x: -60, y: -10),
        controlPoint1: CGPoint(x: -54, y: 82),
        controlPoint2: CGPoint(x: -72, y: 26)
    )
    featherPath.curve(
        to: CGPoint(x: 0, y: -164),
        controlPoint1: CGPoint(x: -38, y: -76),
        controlPoint2: CGPoint(x: -10, y: -118)
    )
    featherPath.curve(
        to: CGPoint(x: 54, y: -18),
        controlPoint1: CGPoint(x: 14, y: -124),
        controlPoint2: CGPoint(x: 66, y: -74)
    )
    featherPath.curve(
        to: CGPoint(x: 48, y: 120),
        controlPoint1: CGPoint(x: 40, y: 24),
        controlPoint2: CGPoint(x: 58, y: 82)
    )
    featherPath.curve(
        to: CGPoint(x: 0, y: 228),
        controlPoint1: CGPoint(x: 42, y: 164),
        controlPoint2: CGPoint(x: 8, y: 206)
    )
    featherPath.close()

    fill.setFill()
    featherPath.fill()

    let shaft = NSBezierPath()
    shaft.move(to: CGPoint(x: 2, y: 192))
    shaft.curve(
        to: CGPoint(x: 0, y: -188),
        controlPoint1: CGPoint(x: 8, y: 74),
        controlPoint2: CGPoint(x: -4, y: -82)
    )
    detail.setStroke()
    shaft.lineWidth = 9
    shaft.lineCapStyle = .round
    shaft.stroke()

    for cut in stride(from: 150 as CGFloat, through: -4, by: -44) {
        let slit = NSBezierPath()
        slit.move(to: CGPoint(x: 8, y: cut))
        slit.line(to: CGPoint(x: 46, y: cut - 18))
        detail.setStroke()
        slit.lineWidth = 4
        slit.lineCapStyle = .round
        slit.stroke()
    }

    let notch = NSBezierPath()
    notch.move(to: CGPoint(x: -10, y: -182))
    notch.line(to: CGPoint(x: 8, y: -228))
    notch.line(to: CGPoint(x: 24, y: -178))
    notch.close()
    fill.setFill()
    notch.fill()

    NSGraphicsContext.restoreGraphicsState()
}

func drawFeather(center: CGPoint, scale: CGFloat, angleDegrees: CGFloat, palette: IconPalette) {
    NSGraphicsContext.saveGraphicsState()
    if let context = NSGraphicsContext.current?.cgContext {
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: (angleDegrees * .pi) / 180)
        context.scaleBy(x: scale, y: scale)
    }

    let featherPath = NSBezierPath()
    featherPath.move(to: CGPoint(x: 0, y: 228))
    featherPath.curve(
        to: CGPoint(x: -48, y: 112),
        controlPoint1: CGPoint(x: -8, y: 198),
        controlPoint2: CGPoint(x: -44, y: 154)
    )
    featherPath.curve(
        to: CGPoint(x: -60, y: -10),
        controlPoint1: CGPoint(x: -54, y: 82),
        controlPoint2: CGPoint(x: -72, y: 26)
    )
    featherPath.curve(
        to: CGPoint(x: 0, y: -164),
        controlPoint1: CGPoint(x: -38, y: -76),
        controlPoint2: CGPoint(x: -10, y: -118)
    )
    featherPath.curve(
        to: CGPoint(x: 54, y: -18),
        controlPoint1: CGPoint(x: 14, y: -124),
        controlPoint2: CGPoint(x: 66, y: -74)
    )
    featherPath.curve(
        to: CGPoint(x: 48, y: 120),
        controlPoint1: CGPoint(x: 40, y: 24),
        controlPoint2: CGPoint(x: 58, y: 82)
    )
    featherPath.curve(
        to: CGPoint(x: 0, y: 228),
        controlPoint1: CGPoint(x: 42, y: 164),
        controlPoint2: CGPoint(x: 8, y: 206)
    )
    featherPath.close()

    let featherGradient = NSGradient(colors: [
        palette.accent,
        palette.accentDeep
    ])!
    featherGradient.draw(in: featherPath, angle: -90)

    let shaft = NSBezierPath()
    shaft.move(to: CGPoint(x: 2, y: 192))
    shaft.curve(
        to: CGPoint(x: 0, y: -186),
        controlPoint1: CGPoint(x: 8, y: 72),
        controlPoint2: CGPoint(x: -6, y: -78)
    )
    palette.accentDeep.withAlphaComponent(0.96).setStroke()
    shaft.lineWidth = 10
    shaft.lineCapStyle = .round
    shaft.stroke()

    for cut in stride(from: 148 as CGFloat, through: -8, by: -44) {
        let slit = NSBezierPath()
        slit.move(to: CGPoint(x: 8, y: cut))
        slit.line(to: CGPoint(x: 48, y: cut - 18))
        NSColor.white.withAlphaComponent(0.46).setStroke()
        slit.lineWidth = 5
        slit.lineCapStyle = .round
        slit.stroke()
    }

    let nib = NSBezierPath()
    nib.move(to: CGPoint(x: -10, y: -186))
    nib.line(to: CGPoint(x: 14, y: -238))
    nib.line(to: CGPoint(x: 28, y: -178))
    nib.close()
    palette.ink.withAlphaComponent(0.92).setFill()
    nib.fill()

    NSGraphicsContext.restoreGraphicsState()
}

func withShadow(color: NSColor, blur: CGFloat, offset: CGSize, draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = offset
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

func fit(size: CGSize, into rect: CGRect) -> CGRect {
    guard size.width > 0, size.height > 0 else { return rect }
    let scale = min(rect.width / size.width, rect.height / size.height)
    let fittedSize = CGSize(width: size.width * scale, height: size.height * scale)
    return CGRect(
        x: rect.midX - (fittedSize.width / 2),
        y: rect.midY - (fittedSize.height / 2),
        width: fittedSize.width,
        height: fittedSize.height
    ).integral
}

func smoothstep(edge0: CGFloat, edge1: CGFloat, x: CGFloat) -> CGFloat {
    guard edge0 != edge1 else { return x < edge0 ? 0 : 1 }
    let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
    return t * t * (3 - (2 * t))
}

func resize(image: NSImage, to size: CGSize) -> NSImage {
    let pixelWidth = max(Int(size.width.rounded()), 1)
    let pixelHeight = max(Int(size.height.rounded()), 1)

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelWidth,
        pixelsHigh: pixelHeight,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return image
    }

    bitmap.size = size

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
    context?.imageInterpolation = .high
    NSGraphicsContext.current = context
    image.draw(
        in: CGRect(origin: .zero, size: size),
        from: .zero,
        operation: .copy,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    let resized = NSImage(size: size)
    resized.addRepresentation(bitmap)
    return resized
}

func savePNG(image: NSImage, to url: URL) throws {
    if let bitmap = image.representations
        .compactMap({ $0 as? NSBitmapImageRep })
        .max(by: { $0.pixelsWide < $1.pixelsWide }),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        try pngData.write(to: url)
        return
    }

    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        throw NSError(
            domain: "IconGeneration",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"]
        )
    }

    let bitmap = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(
            domain: "IconGeneration",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG data"]
        )
    }

    try pngData.write(to: url)
}
