import AppKit
import SwiftUI

@MainActor
final class NoteSession: ObservableObject {
    enum SafetyLevel {
        case info
        case warning
        case error

        var color: Color {
            switch self {
            case .info:
                return .accentColor
            case .warning:
                return .orange
            case .error:
                return .red
            }
        }

        var systemImage: String {
            switch self {
            case .info:
                return "info.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .error:
                return "xmark.octagon.fill"
            }
        }
    }

    @Published var text: String
    @Published var shareSafetyMode: ShareSafetyMode = .windowShare {
        didSet {
            refreshDisplayOptions()
            refreshSafetyMessage()
            persistSettingsDebounced()
        }
    }
    @Published var noteViewMode: NoteViewMode = .edit {
        didSet { persistSettingsDebounced() }
    }
    @Published var isScrollSyncEnabled: Bool = false {
        didSet { persistSettingsDebounced() }
    }
    @Published var overlayMode: OverlayMode = .read {
        didSet { persistSettingsDebounced() }
    }
    @Published var isOverlayVisible: Bool = false {
        didSet { persistSettingsDebounced() }
    }
    @Published var overlayAppearance: OverlayAppearance = .init() {
        didSet {
            applyEditorWindowAppearance()
            persistSettingsDebounced()
        }
    }
    @Published private(set) var overlayPlacement: OverlayPlacement = .init() {
        didSet { persistSettingsDebounced() }
    }
    @Published private(set) var availableDisplays: [DisplayOption] = []
    @Published private(set) var desktopSafeDisplays: [DisplayOption] = []
    @Published private(set) var safetyMessage: String = ""
    @Published private(set) var safetyLevel: SafetyLevel = .info
    @Published private(set) var fileDisplayName: String = "Untitled Note"
    @Published private(set) var fileURL: URL?
    @Published private(set) var activeOverlayDisplayName: String = "Current Display"

    private let settingsStore: OverlaySettingsStore
    private var persistenceIdentifier: String?
    private var pendingSaveTask: Task<Void, Never>?
    private weak var editorWindow: NSWindow?
    private var overlayController: OverlayWindowController?
    private var screenObserver: Any?
    private var editorWindowObservers: [Any] = []
    private var isRestoringSettings = false
    private var isUpdatingPlacementFromWindow = false

    init(initialText: String, fileURL: URL?, settingsStore: OverlaySettingsStore = .shared) {
        self.text = initialText
        self.settingsStore = settingsStore
        setFileURL(fileURL)
        refreshDisplayOptions()
        refreshSafetyMessage()

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDisplayOptions()
                self?.refreshSafetyMessage()
            }
        }

        overlayController = OverlayWindowController(session: self)
    }
    var canUseDesktopSafeMode: Bool {
        desktopSafeDisplays.isEmpty == false
    }

    var canDisplayOverlay: Bool {
        switch shareSafetyMode {
        case .windowShare:
            return resolvedOverlayScreen() != nil
        case .desktopSafe:
            return canUseDesktopSafeMode && resolvedOverlayScreen() != nil
        }
    }

    var overlaySize: CGSize {
        if let frame = overlayPlacement.frame?.cgRect {
            return frame.size
        }
        return CGSize(width: 440, height: 280)
    }

    func setFileURL(_ fileURL: URL?) {
        let normalizedIncomingURL = fileURL?.standardizedFileURL
        if self.fileURL?.standardizedFileURL == normalizedIncomingURL {
            return
        }

        self.fileURL = fileURL
        fileDisplayName = fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled Note"
        persistenceIdentifier = fileURL.map(settingsStore.stableIdentifier(for:))

        guard let persistenceIdentifier else {
            refreshDisplayOptions()
            refreshSafetyMessage()
            return
        }

        if let settings = settingsStore.load(forIdentifier: persistenceIdentifier) {
            apply(settings: settings)
        } else {
            persistSettingsDebounced()
        }

        refreshDisplayOptions()
        refreshSafetyMessage()
    }

    var previewBaseURL: URL? {
        fileURL?.deletingLastPathComponent()
    }

    func synchronizeDocumentText(_ newText: String) {
        guard text != newText else { return }
        text = newText
    }

    func setEditorWindow(_ window: NSWindow?) {
        guard editorWindow !== window else { return }

        for observer in editorWindowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        editorWindowObservers.removeAll()
        editorWindow = window

        guard let window else {
            refreshDisplayOptions()
            refreshSafetyMessage()
            return
        }

        let center = NotificationCenter.default
        editorWindowObservers.append(
            center.addObserver(forName: NSWindow.didChangeScreenNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshDisplayOptions()
                    self?.refreshSafetyMessage()
                }
            }
        )
        editorWindowObservers.append(
            center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshDisplayOptions()
                }
            }
        )

        refreshDisplayOptions()
        refreshSafetyMessage()
        focusEditorWindow()
        applyEditorWindowAppearance()
    }

    func toggleOverlayVisibility() {
        isOverlayVisible.toggle()
    }

    func focusEditorWindow() {
        guard let editorWindow else { return }

        NSApplication.shared.activate(ignoringOtherApps: true)
        editorWindow.makeKeyAndOrderFront(nil)

        DispatchQueue.main.async { [weak editorWindow] in
            guard let editorWindow,
                  let contentView = editorWindow.contentView,
                  let textView = Self.findTextView(in: contentView) else {
                return
            }

            editorWindow.makeFirstResponder(textView)
        }
    }

    func setClickThrough(_ enabled: Bool) {
        updateOverlayPlacement { placement in
            placement.isClickThrough = enabled
            placement.isLocked = enabled
        }
    }

    func setOverlayDisplayID(_ displayID: String) {
        updateOverlayPlacement { placement in
            placement.displayID = displayID
        }
    }

    func setOverlaySize(_ newSize: CGSize) {
        let size = CGSize(
            width: max(280, min(newSize.width, 1100)),
            height: max(160, min(newSize.height, 900))
        )

        let screen = resolvedOverlayScreen()
        let currentFrame = overlayPlacement.frame?.cgRect ?? defaultFrame(for: screen, size: size)
        var nextFrame = currentFrame
        nextFrame.size = size
        updateOverlayPlacement { placement in
            placement.frame = CodableRect(rect: adjustedFrame(nextFrame, for: screen))
        }
    }

    func snapOverlay(to preset: OverlaySnapPreset) {
        guard let screen = resolvedOverlayScreen() else { return }
        let visible = screen.visibleFrame.insetBy(dx: 24, dy: 24)
        let size = overlaySize
        let width = min(size.width, visible.width)
        let height = min(size.height, visible.height)

        let x: CGFloat
        let y: CGFloat

        switch preset {
        case .topLeft:
            x = visible.minX
            y = visible.maxY - height
        case .topCenter:
            x = visible.midX - (width / 2)
            y = visible.maxY - height
        case .topRight:
            x = visible.maxX - width
            y = visible.maxY - height
        case .center:
            x = visible.midX - (width / 2)
            y = visible.midY - (height / 2)
        }

        updateOverlayPlacement { placement in
            placement.displayID = screen.overlayDisplayID
            placement.frame = CodableRect(rect: CGRect(x: x, y: y, width: width, height: height))
        }
    }

    func updatePlacementFromWindow(frame: CGRect, displayID: String?) {
        guard isUpdatingPlacementFromWindow == false else { return }
        isUpdatingPlacementFromWindow = true
        updateOverlayPlacement { placement in
            placement.displayID = displayID
            placement.frame = CodableRect(rect: frame)
        }
        isUpdatingPlacementFromWindow = false
    }

    func resolvedOverlayScreen() -> NSScreen? {
        let screens = NSScreen.screens

        switch shareSafetyMode {
        case .windowShare:
            if let editorDisplayID, let matchingScreen = NSScreen.overlayScreen(withDisplayID: editorDisplayID) {
                return matchingScreen
            }
            if let storedDisplayID = overlayPlacement.displayID,
               let matchingScreen = NSScreen.overlayScreen(withDisplayID: storedDisplayID) {
                return matchingScreen
            }
            return screens.first ?? NSScreen.main

        case .desktopSafe:
            let candidates = desktopSafeScreenCandidates(from: screens)
            guard candidates.isEmpty == false else { return nil }

            if let storedDisplayID = overlayPlacement.displayID,
               let matchingScreen = candidates.first(where: { $0.overlayDisplayID == storedDisplayID }) {
                return matchingScreen
            }

            return candidates.first
        }
    }

    func resolvedOverlayFrame() -> CGRect? {
        guard let screen = resolvedOverlayScreen() else { return nil }
        let currentSize = overlaySize

        if let storedFrame = overlayPlacement.frame?.cgRect {
            if overlayPlacement.displayID == screen.overlayDisplayID {
                return adjustedFrame(storedFrame, for: screen)
            }

            return defaultFrame(for: screen, size: storedFrame.size)
        }

        return defaultFrame(for: screen, size: currentSize)
    }

    private var editorDisplayID: String? {
        editorWindow?.screen?.overlayDisplayID
    }

    private func desktopSafeScreenCandidates(from screens: [NSScreen]) -> [NSScreen] {
        guard let editorDisplayID else {
            return screens
        }

        return screens.filter { $0.overlayDisplayID != editorDisplayID }
    }

    private func refreshDisplayOptions() {
        let screens = NSScreen.screens
        availableDisplays = screens.enumerated().map { index, screen in
            DisplayOption(
                id: screen.overlayDisplayID,
                name: screen.overlayDisplayName,
                detail: "Display \(index + 1)"
            )
        }

        desktopSafeDisplays = desktopSafeScreenCandidates(from: screens).enumerated().map { index, screen in
            DisplayOption(
                id: screen.overlayDisplayID,
                name: screen.overlayDisplayName,
                detail: "Safe display \(index + 1)"
            )
        }

        if let screen = resolvedOverlayScreen() {
            activeOverlayDisplayName = screen.overlayDisplayName
        } else {
            activeOverlayDisplayName = "Unavailable"
        }

        if shareSafetyMode == .desktopSafe,
           overlayPlacement.displayID == nil,
           let first = desktopSafeDisplays.first {
            setOverlayDisplayID(first.id)
        }
    }

    private func refreshSafetyMessage() {
        switch shareSafetyMode {
        case .windowShare:
            safetyLevel = .warning
            safetyMessage = "Share a single app or window in Zoom or Teams. This mode is not meant for full desktop sharing."

        case .desktopSafe:
            if canUseDesktopSafeMode {
                safetyLevel = .info
                safetyMessage = "The overlay will live on the unshared display. Confirm your meeting app is only sharing the other display."
            } else {
                safetyLevel = .error
                safetyMessage = "Desktop Safe Mode needs a second display. Connect another display before using this mode."
            }
        }
    }

    private func applyEditorWindowAppearance() {
        editorWindow?.appearance = overlayAppearance.themeOverride.appearance
    }

    private func apply(settings: OverlaySettings) {
        isRestoringSettings = true
        shareSafetyMode = settings.shareSafetyMode
        noteViewMode = settings.noteViewMode
        isScrollSyncEnabled = settings.isScrollSyncEnabled
        overlayMode = settings.overlayMode
        isOverlayVisible = settings.isOverlayVisible
        overlayAppearance = settings.appearance
        setOverlayPlacement(settings.placement)
        isRestoringSettings = false
    }

    private func persistSettingsDebounced() {
        guard isRestoringSettings == false else { return }
        guard isUpdatingPlacementFromWindow == false else { return }
        guard let persistenceIdentifier else { return }
        let identifier = persistenceIdentifier

        let snapshot = OverlaySettings(
            shareSafetyMode: shareSafetyMode,
            noteViewMode: noteViewMode,
            isScrollSyncEnabled: isScrollSyncEnabled,
            overlayMode: overlayMode,
            isOverlayVisible: isOverlayVisible,
            appearance: overlayAppearance,
            placement: overlayPlacement
        )

        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [settingsStore, snapshot, identifier] in
            try? await Task.sleep(for: .milliseconds(200))
            guard Task.isCancelled == false else { return }

            DispatchQueue.global(qos: .utility).async {
                try? settingsStore.save(snapshot, forIdentifier: identifier)
            }
        }
    }

    private func updateOverlayPlacement(_ update: (inout OverlayPlacement) -> Void) {
        var placement = overlayPlacement
        update(&placement)
        setOverlayPlacement(placement)
    }

    private func setOverlayPlacement(_ placement: OverlayPlacement) {
        let normalizedPlacement = normalizedOverlayPlacement(placement)
        guard overlayPlacement != normalizedPlacement else { return }
        overlayPlacement = normalizedPlacement
    }

    private func normalizedOverlayPlacement(_ placement: OverlayPlacement) -> OverlayPlacement {
        var normalized = placement
        if normalized.isClickThrough {
            normalized.isLocked = true
        }
        return normalized
    }

    private func defaultFrame(for screen: NSScreen?, size: CGSize) -> CGRect {
        let referenceFrame = (screen ?? NSScreen.main)?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1280, height: 800)
        let width = min(size.width, max(280, referenceFrame.width - 80))
        let height = min(size.height, max(160, referenceFrame.height - 80))
        let x = referenceFrame.midX - (width / 2)
        let y = referenceFrame.maxY - height - 40
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func adjustedFrame(_ frame: CGRect, for screen: NSScreen?) -> CGRect {
        let referenceFrame = (screen ?? NSScreen.main)?.visibleFrame.insetBy(dx: 16, dy: 16) ?? frame
        let width = min(max(frame.width, 280), referenceFrame.width)
        let height = min(max(frame.height, 160), referenceFrame.height)
        let maxX = referenceFrame.maxX - width
        let maxY = referenceFrame.maxY - height

        let x = min(max(frame.origin.x, referenceFrame.minX), maxX)
        let y = min(max(frame.origin.y, referenceFrame.minY), maxY)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func findTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView {
            return textView
        }

        for subview in view.subviews {
            if let textView = findTextView(in: subview) {
                return textView
            }
        }

        return nil
    }
}
