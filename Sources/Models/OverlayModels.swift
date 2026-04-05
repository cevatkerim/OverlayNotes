import AppKit
import SwiftUI

enum ShareSafetyMode: String, Codable, CaseIterable, Identifiable {
    case windowShare
    case desktopSafe

    var id: String { rawValue }

    var title: String {
        switch self {
        case .windowShare:
            return "Window"
        case .desktopSafe:
            return "Second Display"
        }
    }

    var description: String {
        switch self {
        case .windowShare:
            return "Keep the overlay on the same display as this note window when you’re sharing just one app or window."
        case .desktopSafe:
            return "Move the overlay to a separate display so your shared desktop stays clean."
        }
    }

    var systemImage: String {
        switch self {
        case .windowShare:
            return "macwindow"
        case .desktopSafe:
            return "display.2"
        }
    }
}

enum NoteViewMode: String, Codable, CaseIterable, Identifiable {
    case edit
    case preview
    case split

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .edit:
            return "square.and.pencil"
        case .preview:
            return "doc.text.image"
        case .split:
            return "rectangle.split.2x1"
        }
    }
}

enum OverlayMode: String, Codable, CaseIterable, Identifiable {
    case read
    case edit

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var systemImage: String {
        switch self {
        case .read:
            return "eyeglasses"
        case .edit:
            return "pencil"
        }
    }
}

enum OverlayThemeOverride: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system:
            return nil
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }
}

extension NSColor {
    func resolvedForAppearance(_ appearance: NSAppearance?) -> NSColor {
        guard let appearance else { return self }

        var resolved = self
        appearance.performAsCurrentDrawingAppearance {
            resolved = self.usingColorSpace(.deviceRGB) ?? self
        }
        return resolved
    }
}

enum OverlayBlurMaterial: String, Codable, CaseIterable, Identifiable {
    case none
    case hudWindow
    case sidebar
    case underWindowBackground
    case menu
    case titlebar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none:
            return "None"
        case .hudWindow:
            return "HUD"
        case .sidebar:
            return "Sidebar"
        case .underWindowBackground:
            return "Under Window"
        case .menu:
            return "Menu"
        case .titlebar:
            return "Titlebar"
        }
    }

    var material: NSVisualEffectView.Material? {
        switch self {
        case .none:
            return nil
        case .hudWindow:
            return .hudWindow
        case .sidebar:
            return .sidebar
        case .underWindowBackground:
            return .underWindowBackground
        case .menu:
            return .menu
        case .titlebar:
            return .titlebar
        }
    }
}

enum OverlaySnapPreset: String, CaseIterable, Identifiable {
    case topLeft
    case topCenter
    case topRight
    case center

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topLeft:
            return "Top Left"
        case .topCenter:
            return "Top Center"
        case .topRight:
            return "Top Right"
        case .center:
            return "Center"
        }
    }

    var systemImage: String {
        switch self {
        case .topLeft:
            return "arrow.up.left"
        case .topCenter:
            return "arrow.up"
        case .topRight:
            return "arrow.up.right"
        case .center:
            return "dot.scope"
        }
    }
}

struct OverlayAppearance: Codable, Equatable {
    var opacity: Double = 0.88
    var tintColor: CodableColor = .init(red: 0.11, green: 0.12, blue: 0.15, alpha: 0.90)
    var blurMaterial: OverlayBlurMaterial = .hudWindow
    var textScale: Double = 1.0
    var themeOverride: OverlayThemeOverride = .system
}

struct OverlayPlacement: Codable, Equatable {
    var displayID: String?
    var frame: CodableRect?
    var isLocked: Bool = false
    var isClickThrough: Bool = false
    var staysOnTop: Bool = true
}

struct OverlaySettings: Codable, Equatable {
    var shareSafetyMode: ShareSafetyMode = .windowShare
    var noteViewMode: NoteViewMode = .edit
    var isScrollSyncEnabled: Bool = false
    var overlayMode: OverlayMode = .read
    var isOverlayVisible: Bool = false
    var appearance: OverlayAppearance = .init()
    var placement: OverlayPlacement = .init()

    private enum CodingKeys: String, CodingKey {
        case shareSafetyMode
        case noteViewMode
        case isScrollSyncEnabled
        case overlayMode
        case isOverlayVisible
        case appearance
        case placement
    }

    init(
        shareSafetyMode: ShareSafetyMode = .windowShare,
        noteViewMode: NoteViewMode = .edit,
        isScrollSyncEnabled: Bool = false,
        overlayMode: OverlayMode = .read,
        isOverlayVisible: Bool = false,
        appearance: OverlayAppearance = .init(),
        placement: OverlayPlacement = .init()
    ) {
        self.shareSafetyMode = shareSafetyMode
        self.noteViewMode = noteViewMode
        self.isScrollSyncEnabled = isScrollSyncEnabled
        self.overlayMode = overlayMode
        self.isOverlayVisible = isOverlayVisible
        self.appearance = appearance
        self.placement = placement
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shareSafetyMode = try container.decodeIfPresent(ShareSafetyMode.self, forKey: .shareSafetyMode) ?? .windowShare
        noteViewMode = try container.decodeIfPresent(NoteViewMode.self, forKey: .noteViewMode) ?? .edit
        isScrollSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .isScrollSyncEnabled) ?? false
        overlayMode = try container.decodeIfPresent(OverlayMode.self, forKey: .overlayMode) ?? .read
        isOverlayVisible = try container.decodeIfPresent(Bool.self, forKey: .isOverlayVisible) ?? false
        appearance = try container.decodeIfPresent(OverlayAppearance.self, forKey: .appearance) ?? .init()
        placement = try container.decodeIfPresent(OverlayPlacement.self, forKey: .placement) ?? .init()
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(shareSafetyMode, forKey: .shareSafetyMode)
        try container.encode(noteViewMode, forKey: .noteViewMode)
        try container.encode(isScrollSyncEnabled, forKey: .isScrollSyncEnabled)
        try container.encode(overlayMode, forKey: .overlayMode)
        try container.encode(isOverlayVisible, forKey: .isOverlayVisible)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(placement, forKey: .placement)
    }
}

struct DisplayOption: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
}

struct CodableColor: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? .windowBackgroundColor
        self.red = Double(nsColor.redComponent)
        self.green = Double(nsColor.greenComponent)
        self.blue = Double(nsColor.blueComponent)
        self.alpha = Double(nsColor.alphaComponent)
    }

    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

struct CodableRect: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.width
        height = rect.height
    }

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}
