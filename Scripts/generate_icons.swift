import AppKit
import Foundation

struct IconPalette {
    let bgTop: NSColor
    let bgBottom: NSColor
    let accent: NSColor
    let accentSoft: NSColor
    let ink: NSColor
    let glow: NSColor
}

enum IconStyle: String, CaseIterable {
    case glass
    case spotlight
    case stack

    var palette: IconPalette {
        switch self {
        case .glass:
            return IconPalette(
                bgTop: NSColor(srgbRed: 0.07, green: 0.11, blue: 0.20, alpha: 1),
                bgBottom: NSColor(srgbRed: 0.14, green: 0.22, blue: 0.37, alpha: 1),
                accent: NSColor(srgbRed: 0.42, green: 0.88, blue: 0.92, alpha: 1),
                accentSoft: NSColor(srgbRed: 0.69, green: 0.97, blue: 0.98, alpha: 1),
                ink: NSColor(srgbRed: 0.94, green: 0.98, blue: 1.0, alpha: 1),
                glow: NSColor(srgbRed: 0.52, green: 0.94, blue: 1.0, alpha: 0.65)
            )
        case .spotlight:
            return IconPalette(
                bgTop: NSColor(srgbRed: 0.16, green: 0.10, blue: 0.20, alpha: 1),
                bgBottom: NSColor(srgbRed: 0.33, green: 0.14, blue: 0.17, alpha: 1),
                accent: NSColor(srgbRed: 1.0, green: 0.73, blue: 0.40, alpha: 1),
                accentSoft: NSColor(srgbRed: 1.0, green: 0.87, blue: 0.72, alpha: 1),
                ink: NSColor(srgbRed: 1.0, green: 0.98, blue: 0.95, alpha: 1),
                glow: NSColor(srgbRed: 1.0, green: 0.79, blue: 0.48, alpha: 0.62)
            )
        case .stack:
            return IconPalette(
                bgTop: NSColor(srgbRed: 0.07, green: 0.16, blue: 0.14, alpha: 1),
                bgBottom: NSColor(srgbRed: 0.11, green: 0.31, blue: 0.27, alpha: 1),
                accent: NSColor(srgbRed: 0.54, green: 0.97, blue: 0.67, alpha: 1),
                accentSoft: NSColor(srgbRed: 0.80, green: 1.0, blue: 0.84, alpha: 1),
                ink: NSColor(srgbRed: 0.96, green: 1.0, blue: 0.98, alpha: 1),
                glow: NSColor(srgbRed: 0.56, green: 1.0, blue: 0.73, alpha: 0.62)
            )
        }
    }
}

let fileManager = FileManager.default
let repoRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let generatedDir = repoRoot.appendingPathComponent("Generated", isDirectory: true)
let iconsDir = generatedDir.appendingPathComponent("AppIcons", isDirectory: true)
let appIconSetDir = iconsDir.appendingPathComponent("AppIcon.appiconset", isDirectory: true)

try fileManager.createDirectory(at: iconsDir, withIntermediateDirectories: true)
try fileManager.createDirectory(at: appIconSetDir, withIntermediateDirectories: true)

let masterSize = CGSize(width: 1024, height: 1024)

for style in IconStyle.allCases {
    let image = NSImage(size: masterSize)
    image.lockFocus()
    drawIcon(style: style, size: masterSize)
    image.unlockFocus()

    let output = iconsDir.appendingPathComponent("overlay-notes-\(style.rawValue)-1024.png")
    try savePNG(image: image, to: output)
}

let primaryImage = NSImage(size: masterSize)
primaryImage.lockFocus()
drawIcon(style: .glass, size: masterSize)
primaryImage.unlockFocus()

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
    let destination = appIconSetDir.appendingPathComponent(spec.name)
    try savePNG(image: resized, to: destination)
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

try contentsJSON.write(
    to: appIconSetDir.appendingPathComponent("Contents.json"),
    atomically: true,
    encoding: .utf8
)

print("Generated icons in \(iconsDir.path)")

func drawIcon(style: IconStyle, size: CGSize) {
    let palette = style.palette
    let rect = CGRect(origin: .zero, size: size)
    let backgroundPath = NSBezierPath(roundedRect: rect.insetBy(dx: 36, dy: 36), xRadius: 232, yRadius: 232)
    drawBackground(path: backgroundPath, rect: rect, palette: palette)

    switch style {
    case .glass:
        drawGlassStyle(in: rect, palette: palette)
    case .spotlight:
        drawSpotlightStyle(in: rect, palette: palette)
    case .stack:
        drawStackStyle(in: rect, palette: palette)
    }
}

func drawBackground(path: NSBezierPath, rect: CGRect, palette: IconPalette) {
    NSGraphicsContext.saveGraphicsState()
    path.addClip()

    let gradient = NSGradient(starting: palette.bgTop, ending: palette.bgBottom)
    gradient?.draw(in: path, angle: -90)

    let glowRect = rect.insetBy(dx: 120, dy: 120)
    let glowPath = NSBezierPath(ovalIn: glowRect.offsetBy(dx: 0, dy: 90))
    palette.glow.withAlphaComponent(0.38).setFill()
    glowPath.fill()

    let highlightRect = CGRect(x: 130, y: 640, width: 760, height: 230)
    let highlight = NSBezierPath(roundedRect: highlightRect, xRadius: 110, yRadius: 110)
    palette.accentSoft.withAlphaComponent(0.13).setFill()
    highlight.fill()

    NSGraphicsContext.restoreGraphicsState()
}

func drawGlassStyle(in rect: CGRect, palette: IconPalette) {
    let paneRect = CGRect(x: 208, y: 214, width: 608, height: 602)
    drawGlassPanel(
        rect: paneRect,
        cornerRadius: 124,
        palette: palette,
        highlightInset: 22
    )

    let topBar = NSBezierPath(roundedRect: CGRect(x: 258, y: 724, width: 300, height: 40), xRadius: 20, yRadius: 20)
    palette.ink.withAlphaComponent(0.32).setFill()
    topBar.fill()

    drawNoteLines(in: paneRect.insetBy(dx: 88, dy: 116), palette: palette, lineCount: 5, emphasis: 2)

    let eyePath = NSBezierPath()
    eyePath.move(to: CGPoint(x: 382, y: 450))
    eyePath.curve(to: CGPoint(x: 642, y: 450), controlPoint1: CGPoint(x: 430, y: 386), controlPoint2: CGPoint(x: 594, y: 386))
    eyePath.curve(to: CGPoint(x: 382, y: 450), controlPoint1: CGPoint(x: 594, y: 514), controlPoint2: CGPoint(x: 430, y: 514))
    eyePath.close()
    palette.accent.withAlphaComponent(0.92).setStroke()
    eyePath.lineWidth = 20
    eyePath.stroke()

    let pupil = NSBezierPath(ovalIn: CGRect(x: 472, y: 392, width: 80, height: 80))
    palette.accent.setFill()
    pupil.fill()

    let sparkle = NSBezierPath(ovalIn: CGRect(x: 530, y: 458, width: 22, height: 22))
    palette.ink.withAlphaComponent(0.85).setFill()
    sparkle.fill()
}

func drawSpotlightStyle(in rect: CGRect, palette: IconPalette) {
    let ringRect = CGRect(x: 194, y: 188, width: 636, height: 636)
    let outerRing = NSBezierPath(ovalIn: ringRect)
    palette.accent.withAlphaComponent(0.25).setFill()
    outerRing.fill()

    let innerRing = NSBezierPath(ovalIn: ringRect.insetBy(dx: 58, dy: 58))
    palette.accentSoft.withAlphaComponent(0.22).setFill()
    innerRing.fill()

    let noteRect = CGRect(x: 262, y: 246, width: 500, height: 530)
    drawGlassPanel(
        rect: noteRect,
        cornerRadius: 110,
        palette: palette,
        highlightInset: 18
    )

    let cameraRect = CGRect(x: 438, y: 684, width: 148, height: 38)
    let cameraSlot = NSBezierPath(roundedRect: cameraRect, xRadius: 19, yRadius: 19)
    NSColor.black.withAlphaComponent(0.38).setFill()
    cameraSlot.fill()

    drawNoteLines(in: noteRect.insetBy(dx: 76, dy: 110), palette: palette, lineCount: 6, emphasis: 3)

    let pointer = NSBezierPath()
    pointer.move(to: CGPoint(x: 728, y: 318))
    pointer.line(to: CGPoint(x: 786, y: 266))
    pointer.line(to: CGPoint(x: 744, y: 374))
    pointer.close()
    palette.accent.setFill()
    pointer.fill()

    let pointerShadow = NSBezierPath(ovalIn: CGRect(x: 714, y: 298, width: 82, height: 82))
    palette.glow.withAlphaComponent(0.28).setFill()
    pointerShadow.fill()
}

func drawStackStyle(in rect: CGRect, palette: IconPalette) {
    let backRect = CGRect(x: 212, y: 252, width: 470, height: 500)
    let middleRect = CGRect(x: 300, y: 210, width: 470, height: 500)
    let frontRect = CGRect(x: 250, y: 294, width: 470, height: 500)

    NSGraphicsContext.saveGraphicsState()
    if let context = NSGraphicsContext.current?.cgContext {
        context.translateBy(x: -104, y: 84)
        context.rotate(by: (-7 * .pi) / 180)
    }
    drawGlassPanel(rect: backRect, cornerRadius: 92, palette: palette, highlightInset: 16)
    drawNoteLines(in: backRect.insetBy(dx: 70, dy: 110), palette: palette, lineCount: 4, emphasis: 1)
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    if let context = NSGraphicsContext.current?.cgContext {
        context.translateBy(x: 114, y: -76)
        context.rotate(by: (8 * .pi) / 180)
    }
    drawGlassPanel(rect: middleRect, cornerRadius: 92, palette: palette, highlightInset: 16)
    drawNoteLines(in: middleRect.insetBy(dx: 70, dy: 110), palette: palette, lineCount: 4, emphasis: 3)
    NSGraphicsContext.restoreGraphicsState()

    drawGlassPanel(rect: frontRect, cornerRadius: 98, palette: palette, highlightInset: 18)
    drawNoteLines(in: frontRect.insetBy(dx: 74, dy: 120), palette: palette, lineCount: 5, emphasis: 2)

    let check = NSBezierPath()
    check.move(to: CGPoint(x: 392, y: 482))
    check.line(to: CGPoint(x: 470, y: 404))
    check.line(to: CGPoint(x: 624, y: 560))
    palette.accent.setStroke()
    check.lineWidth = 34
    check.lineCapStyle = .round
    check.lineJoinStyle = .round
    check.stroke()
}

func drawGlassPanel(rect: CGRect, cornerRadius: CGFloat, palette: IconPalette, highlightInset: CGFloat) {
    let panelPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor.white.withAlphaComponent(0.16).setFill()
    panelPath.fill()

    let overlayGradient = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.28),
        NSColor.white.withAlphaComponent(0.10),
        NSColor.white.withAlphaComponent(0.06)
    ])
    overlayGradient?.draw(in: panelPath, angle: -90)

    let stroke = NSBezierPath(roundedRect: rect.insetBy(dx: 4, dy: 4), xRadius: cornerRadius - 4, yRadius: cornerRadius - 4)
    NSColor.white.withAlphaComponent(0.28).setStroke()
    stroke.lineWidth = 6
    stroke.stroke()

    let highlight = NSBezierPath(
        roundedRect: CGRect(
            x: rect.minX + highlightInset,
            y: rect.maxY - 140,
            width: rect.width * 0.54,
            height: 80
        ),
        xRadius: 40,
        yRadius: 40
    )
    palette.accentSoft.withAlphaComponent(0.15).setFill()
    highlight.fill()
}

func drawNoteLines(in rect: CGRect, palette: IconPalette, lineCount: Int, emphasis: Int) {
    let spacing: CGFloat = rect.height / CGFloat(lineCount + 1)
    for index in 0..<lineCount {
        let widthFactor: CGFloat = index == emphasis ? 0.86 : (0.60 + CGFloat(index) * 0.06)
        let lineRect = CGRect(
            x: rect.minX,
            y: rect.maxY - CGFloat(index + 1) * spacing,
            width: rect.width * min(widthFactor, 0.92),
            height: 26
        )

        let path = NSBezierPath(roundedRect: lineRect, xRadius: 13, yRadius: 13)
        let fill = index == emphasis ? palette.accent.withAlphaComponent(0.86) : palette.ink.withAlphaComponent(0.84)
        fill.setFill()
        path.fill()
    }
}

func resize(image: NSImage, to size: CGSize) -> NSImage {
    let resized = NSImage(size: size)
    resized.lockFocus()
    image.draw(in: CGRect(origin: .zero, size: size))
    resized.unlockFocus()
    return resized
}

func savePNG(image: NSImage, to url: URL) throws {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
    }

    try pngData.write(to: url)
}
