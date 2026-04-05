import SwiftUI
import AppKit

struct NoteEditorView: View {
    @ObservedObject var session: NoteSession
    @SceneStorage("noteEditorShowsInspector") private var showsInspector = true
    @State private var scrollSyncBridge = ScrollSyncBridge()

    var body: some View {
        editorContent
            .inspector(isPresented: $showsInspector) {
                inspector
            }
            .inspectorColumnWidth(min: 280, ideal: 320, max: 360)
            .toolbarRole(.editor)
            .preferredColorScheme(session.overlayAppearance.themeOverride.colorScheme)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    inspectorToggleButton
                }

                ToolbarItemGroup(placement: .principal) {
                    noteViewPicker
                    overlayModePicker
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        session.toggleOverlayVisibility()
                    } label: {
                        Image(systemName: session.isOverlayVisible ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle")
                    }
                    .help(session.isOverlayVisible ? "Hide Overlay" : "Show Overlay")

                    Menu {
                        ForEach(OverlaySnapPreset.allCases) { preset in
                            Button {
                                session.snapOverlay(to: preset)
                                session.isOverlayVisible = true
                            } label: {
                                Label(preset.title, systemImage: preset.systemImage)
                            }
                        }
                    } label: {
                        Image(systemName: "square.split.2x2")
                    }
                    .help("Snap Overlay")
                }
            }
            .onChange(of: session.isScrollSyncEnabled) { _, isEnabled in
                guard isEnabled, session.noteViewMode == .split else {
                    scrollSyncBridge.reset()
                    return
                }

                Task { @MainActor in
                    scrollSyncBridge.syncNow(from: .editor)
                }
            }
            .onChange(of: session.noteViewMode) { _, mode in
                guard session.isScrollSyncEnabled, mode == .split else {
                    scrollSyncBridge.reset()
                    return
                }

                Task { @MainActor in
                    scrollSyncBridge.syncNow(from: .editor)
                }
            }
            .onDisappear {
                scrollSyncBridge.reset()
            }
    }

    private var editorContent: some View {
        Group {
            switch session.noteViewMode {
            case .edit:
                editorPane
            case .preview:
                MarkdownPreviewView(
                    text: session.text,
                    textScale: 1.0,
                    isOverlay: false,
                    baseURL: session.previewBaseURL,
                    themeOverride: session.overlayAppearance.themeOverride,
                    scrollSyncBridge: splitScrollSyncBridge,
                    scrollSyncSource: .preview,
                    onScrollProgressChanged: handlePreviewScroll
                )
            case .split:
                HSplitView {
                    editorPane
                    MarkdownPreviewView(
                        text: session.text,
                        textScale: 1.0,
                        isOverlay: false,
                        baseURL: session.previewBaseURL,
                        themeOverride: session.overlayAppearance.themeOverride,
                        scrollSyncBridge: splitScrollSyncBridge,
                        scrollSyncSource: .preview,
                        onScrollProgressChanged: handlePreviewScroll
                    )
                }
            }
        }
    }

    private var editorPane: some View {
        MarkdownTextEditor(
            text: $session.text,
            fontSize: 16,
            isEditable: session.overlayMode == .edit,
            drawBackground: true,
            themeOverride: session.overlayAppearance.themeOverride,
            scrollSyncBridge: splitScrollSyncBridge,
            scrollSyncSource: .editor,
            onScrollProgressChanged: handleEditorScroll
        )
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color(nsColor: resolvedEditorBackgroundColor))
    }

    private var noteViewPicker: some View {
        Picker("Note View", selection: $session.noteViewMode) {
            ForEach(NoteViewMode.allCases) { mode in
                Image(systemName: mode.systemImage)
                    .accessibilityLabel(mode.title)
                    .help(mode.title)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 120)
    }

    private var overlayModePicker: some View {
        Picker("Overlay Mode", selection: $session.overlayMode) {
            ForEach(OverlayMode.allCases) { mode in
                Image(systemName: mode.systemImage)
                    .accessibilityLabel(mode.title)
                    .help("Overlay \(mode.title)")
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 84)
    }

    private var inspectorToggleButton: some View {
        Button {
            showsInspector.toggle()
        } label: {
            Image(systemName: showsInspector ? "sidebar.trailing" : "sidebar.right")
        }
        .help(showsInspector ? "Hide Sidebar" : "Show Sidebar")
    }

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                inspectorSection("Overlay") {
                    Toggle("Show floating overlay", isOn: $session.isOverlayVisible)

                    Picker("Mode", selection: $session.overlayMode) {
                        ForEach(OverlayMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle(
                        "Lock and click through",
                        isOn: Binding(
                            get: { session.overlayPlacement.isClickThrough },
                            set: { session.setClickThrough($0) }
                        )
                    )

                    LabeledContent("Display") {
                        Text(session.activeOverlayDisplayName)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        ForEach(OverlaySnapPreset.allCases) { preset in
                            Button {
                                session.snapOverlay(to: preset)
                                session.isOverlayVisible = true
                            } label: {
                                Image(systemName: preset.systemImage)
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.bordered)
                            .help("Snap \(preset.title)")
                        }
                    }
                }

                inspectorSection("Sharing") {
                    Picker("Mode", selection: $session.shareSafetyMode) {
                        ForEach(ShareSafetyMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(session.shareSafetyMode.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if session.shareSafetyMode == .desktopSafe {
                        if session.canUseDesktopSafeMode {
                            Picker(
                                "Overlay display",
                                selection: Binding(
                                    get: { session.overlayPlacement.displayID ?? session.desktopSafeDisplays.first?.id ?? "" },
                                    set: { session.setOverlayDisplayID($0) }
                                )
                            ) {
                                ForEach(session.desktopSafeDisplays) { display in
                                    Text(display.name).tag(display.id)
                                }
                            }
                        } else {
                            Label("Connect a second display to place the overlay away from your shared desktop.", systemImage: "display.2")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                inspectorSection("Appearance") {
                    Toggle("Sync scroll in Split view", isOn: $session.isScrollSyncEnabled)
                        .disabled(session.noteViewMode != .split)

                    LabeledContent("Opacity") {
                        Text(session.overlayAppearance.opacity, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                    }
                    Slider(
                        value: $session.overlayAppearance.opacity,
                        in: 0.35...1.0,
                        step: 0.01
                    )

                    LabeledContent("Text Scale") {
                        Text(session.overlayAppearance.textScale, format: .number.precision(.fractionLength(2)))
                            .monospacedDigit()
                    }
                    Slider(
                        value: $session.overlayAppearance.textScale,
                        in: 0.7...1.8,
                        step: 0.05
                    )

                    ColorPicker(
                        "Tint",
                        selection: Binding(
                            get: { session.overlayAppearance.tintColor.color },
                            set: { session.overlayAppearance.tintColor = CodableColor(color: $0) }
                        )
                    )

                    Picker("Blur", selection: $session.overlayAppearance.blurMaterial) {
                        ForEach(OverlayBlurMaterial.allCases) { material in
                            Text(material.title).tag(material)
                        }
                    }

                    Picker("Theme", selection: $session.overlayAppearance.themeOverride) {
                        ForEach(OverlayThemeOverride.allCases) { override in
                            Text(override.title).tag(override)
                        }
                    }
                }
            }
            .padding(18)
        }
    }

    private func inspectorSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleEditorScroll(_ state: ScrollSyncState) {
        guard session.isScrollSyncEnabled, session.noteViewMode == .split else { return }
        scrollSyncBridge.handleScroll(from: .editor, state: state)
    }

    private func handlePreviewScroll(_ state: ScrollSyncState) {
        guard session.isScrollSyncEnabled, session.noteViewMode == .split else { return }
        scrollSyncBridge.handleScroll(from: .preview, state: state)
    }

    private var resolvedEditorBackgroundColor: NSColor {
        NSColor.textBackgroundColor.resolvedForAppearance(session.overlayAppearance.themeOverride.appearance)
    }

    private var splitScrollSyncBridge: ScrollSyncBridge? {
        guard session.isScrollSyncEnabled, session.noteViewMode == .split else { return nil }
        return scrollSyncBridge
    }
}

enum ScrollSyncSource {
    case editor
    case preview
}

@MainActor
protocol ScrollSyncEndpoint: AnyObject {
    var currentScrollSyncState: ScrollSyncState { get }
    func applyScrollSyncCommand(_ command: ScrollSyncCommand)
    func setVerticalScrollElasticity(_ elasticity: NSScrollView.Elasticity)
}

@MainActor
final class ScrollSyncBridge {
    private weak var editorEndpoint: (any ScrollSyncEndpoint)?
    private weak var previewEndpoint: (any ScrollSyncEndpoint)?

    private var activeLeader: ScrollSyncSource?
    private var ignoredFeedbackSource: ScrollSyncSource?
    private var ignoredFeedbackResetTask: Task<Void, Never>?
    private var scheduledEditorScrollSyncTask: Task<Void, Never>?
    private var scheduledPreviewScrollSyncTask: Task<Void, Never>?
    private var pendingEditorScrollSyncState: ScrollSyncState?
    private var pendingPreviewScrollSyncState: ScrollSyncState?

    private static let scrollSyncDebounceDelay = Duration.milliseconds(120)

    func register(_ endpoint: any ScrollSyncEndpoint, for source: ScrollSyncSource) {
        switch source {
        case .editor:
            editorEndpoint = endpoint
        case .preview:
            previewEndpoint = endpoint
        }

        updateElasticity()
    }

    func reset() {
        clearIgnoredFeedback()
        clearScheduledScrollSync()
        activeLeader = nil
        updateElasticity()
    }

    func activateLeader(_ source: ScrollSyncSource) {
        if ignoredFeedbackSource == source {
            clearIgnoredFeedback()
        }

        if activeLeader != source {
            cancelScheduledScrollSync(targeting: source)
        }

        activeLeader = source
        updateElasticity()
    }

    func syncNow(from source: ScrollSyncSource) {
        guard let sourceEndpoint = endpoint(for: source) else { return }
        let state = sourceEndpoint.currentScrollSyncState
        dispatchSync(to: opposite(of: source), state: state)
    }

    func handleScroll(from source: ScrollSyncSource, state: ScrollSyncState) {
        if ignoredFeedbackSource == source {
            clearIgnoredFeedback()
            return
        }

        guard activeLeader == source else { return }
        guard let targetEndpoint = endpoint(for: opposite(of: source)) else { return }
        guard state.requiresSync(to: targetEndpoint.currentScrollSyncState) else { return }

        ignoreNextFeedback(from: opposite(of: source))

        switch source {
        case .editor:
            schedulePreviewScrollSync(state: state)
        case .preview:
            scheduleEditorScrollSync(state: state)
        }
    }

    private func endpoint(for source: ScrollSyncSource) -> (any ScrollSyncEndpoint)? {
        switch source {
        case .editor:
            return editorEndpoint
        case .preview:
            return previewEndpoint
        }
    }

    private func opposite(of source: ScrollSyncSource) -> ScrollSyncSource {
        switch source {
        case .editor:
            return .preview
        case .preview:
            return .editor
        }
    }

    private func ignoreNextFeedback(from source: ScrollSyncSource) {
        ignoredFeedbackResetTask?.cancel()
        ignoredFeedbackSource = source
        ignoredFeedbackResetTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            if ignoredFeedbackSource == source {
                ignoredFeedbackSource = nil
            }
        }
    }

    private func clearIgnoredFeedback() {
        ignoredFeedbackResetTask?.cancel()
        ignoredFeedbackResetTask = nil
        ignoredFeedbackSource = nil
    }

    private func schedulePreviewScrollSync(state: ScrollSyncState) {
        pendingPreviewScrollSyncState = state
        scheduledPreviewScrollSyncTask?.cancel()
        scheduledPreviewScrollSyncTask = Task { @MainActor in
            try? await Task.sleep(for: Self.scrollSyncDebounceDelay)
            scheduledPreviewScrollSyncTask = nil

            guard let pendingState = pendingPreviewScrollSyncState else { return }
            pendingPreviewScrollSyncState = nil
            dispatchSync(to: .preview, state: pendingState)
        }
    }

    private func scheduleEditorScrollSync(state: ScrollSyncState) {
        pendingEditorScrollSyncState = state
        scheduledEditorScrollSyncTask?.cancel()
        scheduledEditorScrollSyncTask = Task { @MainActor in
            try? await Task.sleep(for: Self.scrollSyncDebounceDelay)
            scheduledEditorScrollSyncTask = nil

            guard let pendingState = pendingEditorScrollSyncState else { return }
            pendingEditorScrollSyncState = nil
            dispatchSync(to: .editor, state: pendingState)
        }
    }

    private func dispatchSync(to target: ScrollSyncSource, state: ScrollSyncState) {
        guard activeLeader != target else { return }
        guard let endpoint = endpoint(for: target) else { return }

        let command = ScrollSyncCommand(
            progress: state.progress,
            edgeAffinity: state.edgeAffinity,
            sourceLine: state.sourceLine
        )
        endpoint.applyScrollSyncCommand(command)
    }

    private func cancelScheduledScrollSync(targeting source: ScrollSyncSource) {
        switch source {
        case .editor:
            scheduledEditorScrollSyncTask?.cancel()
            scheduledEditorScrollSyncTask = nil
            pendingEditorScrollSyncState = nil
        case .preview:
            scheduledPreviewScrollSyncTask?.cancel()
            scheduledPreviewScrollSyncTask = nil
            pendingPreviewScrollSyncState = nil
        }
    }

    private func clearScheduledScrollSync() {
        scheduledEditorScrollSyncTask?.cancel()
        scheduledEditorScrollSyncTask = nil
        scheduledPreviewScrollSyncTask?.cancel()
        scheduledPreviewScrollSyncTask = nil
        pendingEditorScrollSyncState = nil
        pendingPreviewScrollSyncState = nil
    }

    private func updateElasticity() {
        switch activeLeader {
        case .editor:
            editorEndpoint?.setVerticalScrollElasticity(.automatic)
            previewEndpoint?.setVerticalScrollElasticity(.none)
        case .preview:
            editorEndpoint?.setVerticalScrollElasticity(.none)
            previewEndpoint?.setVerticalScrollElasticity(.automatic)
        case nil:
            editorEndpoint?.setVerticalScrollElasticity(.automatic)
            previewEndpoint?.setVerticalScrollElasticity(.automatic)
        }
    }
}
