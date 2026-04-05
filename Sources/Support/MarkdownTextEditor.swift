import AppKit
import SwiftUI

struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var isEditable: Bool = true
    var drawBackground: Bool = true
    var themeOverride: OverlayThemeOverride = .system
    var scrollSyncBridge: ScrollSyncBridge? = nil
    var scrollSyncSource: ScrollSyncSource? = nil
    var scrollSyncCommand: ScrollSyncCommand?
    var verticalScrollElasticity: NSScrollView.Elasticity = .automatic
    var onUserInteraction: (() -> Void)? = nil
    var onScrollProgressChanged: ((ScrollSyncState) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            scrollSyncBridge: scrollSyncBridge,
            scrollSyncSource: scrollSyncSource,
            onUserInteraction: onUserInteraction,
            onScrollProgressChanged: onScrollProgressChanged
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = TrackingScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollView.drawsBackground = false

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = .zero
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView

        configure(textView: textView, scrollView: scrollView)
        scrollView.onUserInteraction = context.coordinator.handleUserInteraction
        context.coordinator.attach(scrollView: scrollView)
        if let scrollSyncBridge, let scrollSyncSource {
            scrollSyncBridge.register(context.coordinator, for: scrollSyncSource)
        }
        textView.delegate = context.coordinator
        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.updateLineStartLocations(for: text)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        configure(textView: textView, scrollView: scrollView)
        (scrollView as? TrackingScrollView)?.onUserInteraction = context.coordinator.handleUserInteraction
        context.coordinator.scrollSyncBridge = scrollSyncBridge
        context.coordinator.scrollSyncSource = scrollSyncSource
        context.coordinator.onUserInteraction = onUserInteraction
        context.coordinator.onScrollProgressChanged = onScrollProgressChanged

        if let scrollSyncBridge, let scrollSyncSource {
            scrollSyncBridge.register(context.coordinator, for: scrollSyncSource)
        }

        if textView.string != text {
            textView.string = text
            context.coordinator.updateLineStartLocations(for: text)
        }

        context.coordinator.apply(scrollSyncCommand: scrollSyncCommand, to: scrollView)
    }

    private func configure(textView: NSTextView, scrollView: NSScrollView) {
        scrollView.drawsBackground = drawBackground
        scrollView.appearance = themeOverride.appearance
        scrollView.verticalScrollElasticity = verticalScrollElasticity
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindBar = true
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.appearance = themeOverride.appearance
        textView.drawsBackground = drawBackground
        textView.backgroundColor = drawBackground ? resolvedColor(.textBackgroundColor) : .clear
        textView.insertionPointColor = isEditable ? resolvedColor(.labelColor) : .clear
        textView.textColor = resolvedColor(.labelColor)
        textView.font = .systemFont(ofSize: fontSize, weight: .regular)
        textView.textContainerInset = NSSize(width: 0, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 10_000, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.allowsUndo = true
    }

    private func resolvedColor(_ color: NSColor) -> NSColor {
        color.resolvedForAppearance(themeOverride.appearance)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate, ScrollSyncEndpoint {
        @Binding var text: String
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var scrollSyncBridge: ScrollSyncBridge?
        var scrollSyncSource: ScrollSyncSource?
        var onUserInteraction: (() -> Void)?
        var onScrollProgressChanged: ((ScrollSyncState) -> Void)?
        private var isApplyingSyncedScroll = false
        private var lastAppliedCommandID: UUID?
        private var lastReportedState: ScrollSyncState?
        private var lineStartLocations: [Int] = [0]
        private static let viewportAnchorRatio: CGFloat = 0.24

        init(
            text: Binding<String>,
            scrollSyncBridge: ScrollSyncBridge?,
            scrollSyncSource: ScrollSyncSource?,
            onUserInteraction: (() -> Void)?,
            onScrollProgressChanged: ((ScrollSyncState) -> Void)?
        ) {
            _text = text
            self.scrollSyncBridge = scrollSyncBridge
            self.scrollSyncSource = scrollSyncSource
            self.onUserInteraction = onUserInteraction
            self.onScrollProgressChanged = onScrollProgressChanged
            super.init()
        }

        func handleUserInteraction() {
            if let scrollSyncBridge, let scrollSyncSource {
                scrollSyncBridge.activateLeader(scrollSyncSource)
            }
            onUserInteraction?()
        }

        func attach(scrollView: NSScrollView) {
            guard self.scrollView !== scrollView else { return }

            if let existingScrollView = self.scrollView {
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSView.boundsDidChangeNotification,
                    object: existingScrollView.contentView
                )
            }

            self.scrollView = scrollView
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleBoundsDidChange(_:)),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }

        func apply(scrollSyncCommand: ScrollSyncCommand?, to scrollView: NSScrollView) {
            guard let scrollSyncCommand else { return }
            guard lastAppliedCommandID != scrollSyncCommand.id else { return }

            let currentState = scrollView.currentScrollSyncState
            guard currentState.requiresSync(to: scrollSyncCommand.state) else {
                lastAppliedCommandID = scrollSyncCommand.id
                return
            }

            lastAppliedCommandID = scrollSyncCommand.id
            let maxOffset = max(0, scrollView.documentView?.bounds.height ?? 0 - scrollView.contentView.bounds.height)
            let yOffset = targetOffset(for: scrollSyncCommand.state, maxOffset: maxOffset)
            let origin = NSPoint(x: 0, y: yOffset)

            isApplyingSyncedScroll = true
            lastReportedState = scrollSyncCommand.state
            scrollView.contentView.scroll(to: origin)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            DispatchQueue.main.async { [weak self] in
                self?.isApplyingSyncedScroll = false
            }
        }

        var currentScrollSyncState: ScrollSyncState {
            let baseState = scrollView?.currentScrollSyncState ?? ScrollSyncState(progress: 0, edgeAffinity: .top, sourceLine: 1)
            return ScrollSyncState(
                progress: baseState.progress,
                edgeAffinity: baseState.edgeAffinity,
                sourceLine: visibleSourceLine()
            )
        }

        func applyScrollSyncCommand(_ command: ScrollSyncCommand) {
            guard let scrollView else { return }
            apply(scrollSyncCommand: command, to: scrollView)
        }

        func setVerticalScrollElasticity(_ elasticity: NSScrollView.Elasticity) {
            scrollView?.verticalScrollElasticity = elasticity
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text = textView.string
            updateLineStartLocations(for: textView.string)
        }

        @objc
        private func handleBoundsDidChange(_ notification: Notification) {
            handleScroll()
        }

        private func handleScroll() {
            guard isApplyingSyncedScroll == false, scrollView != nil else { return }
            let state = currentScrollSyncState
            guard lastReportedState?.requiresSync(to: state) != false else { return }
            lastReportedState = state

            let handler = onScrollProgressChanged
            DispatchQueue.main.async {
                handler?(state)
            }
        }

        private func targetOffset(for state: ScrollSyncState, maxOffset: CGFloat) -> CGFloat {
            let progressOffset = state.targetOffset(maxOffset: maxOffset)
            if let sourceLine = state.sourceLine, let lineOffset = verticalOffset(forSourceLine: sourceLine) {
                if state.edgeAffinity == .middle {
                    let blendedOffset = (lineOffset * 0.88) + (progressOffset * 0.12)
                    return min(max(blendedOffset, 0), maxOffset)
                }

                return min(max(lineOffset, 0), maxOffset)
            }

            return progressOffset
        }

        private func visibleSourceLine() -> Int {
            guard let scrollView, let textView, let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
                return 1
            }

            let visibleRect = scrollView.contentView.bounds
            let anchorOffset = max(24, visibleRect.height * Self.viewportAnchorRatio)
            let probePoint = NSPoint(
                x: max(visibleRect.minX + textView.textContainerInset.width + 1, 1),
                y: max(visibleRect.minY + textView.textContainerInset.height + anchorOffset, 1)
            )
            let glyphIndex = layoutManager.glyphIndex(for: probePoint, in: textContainer)
            let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
            return lineNumber(forUTF16Location: characterIndex)
        }

        private func verticalOffset(forSourceLine sourceLine: Int) -> CGFloat? {
            guard let scrollView, let textView, let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
                return nil
            }

            layoutManager.ensureLayout(for: textContainer)
            let characterLocation = utf16Location(forLine: sourceLine)
            let clampedCharacterLocation = min(characterLocation, (textView.string as NSString).length)
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: clampedCharacterLocation)
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil, withoutAdditionalLayout: true)
            let anchorOffset = max(24, scrollView.contentView.bounds.height * Self.viewportAnchorRatio)
            return max(0, lineRect.minY - textView.textContainerInset.height - anchorOffset)
        }

        func updateLineStartLocations(for string: String) {
            let nsString = string as NSString
            var locations = [0]
            var index = 0

            while index < nsString.length {
                var lineStart = 0
                var lineEnd = 0
                var contentsEnd = 0
                nsString.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: index, length: 0))
                if lineEnd < nsString.length {
                    locations.append(lineEnd)
                }
                if lineEnd <= index {
                    break
                }
                index = lineEnd
            }

            lineStartLocations = locations
        }

        private func lineNumber(forUTF16Location location: Int) -> Int {
            guard lineStartLocations.isEmpty == false else { return 1 }

            var lowerBound = 0
            var upperBound = lineStartLocations.count
            while lowerBound < upperBound {
                let middle = (lowerBound + upperBound) / 2
                if lineStartLocations[middle] <= location {
                    lowerBound = middle + 1
                } else {
                    upperBound = middle
                }
            }

            return max(lowerBound, 1)
        }

        private func utf16Location(forLine sourceLine: Int) -> Int {
            let lineIndex = min(max(sourceLine - 1, 0), max(lineStartLocations.count - 1, 0))
            return lineStartLocations[lineIndex]
        }
    }
}

private final class TrackingScrollView: NSScrollView {
    var onUserInteraction: (() -> Void)?

    override func scrollWheel(with event: NSEvent) {
        onUserInteraction?()
        super.scrollWheel(with: event)
    }
}

struct ScrollSyncCommand: Equatable {
    let id = UUID()
    let progress: CGFloat
    let edgeAffinity: ScrollSyncEdgeAffinity
    let sourceLine: Int?

    var state: ScrollSyncState {
        ScrollSyncState(progress: progress, edgeAffinity: edgeAffinity, sourceLine: sourceLine)
    }

    init(progress: CGFloat, edgeAffinity: ScrollSyncEdgeAffinity = .middle, sourceLine: Int? = nil) {
        self.progress = progress
        self.edgeAffinity = edgeAffinity
        self.sourceLine = sourceLine
    }
}

extension NSScrollView {
    var currentVerticalScrollProgress: CGFloat {
        let maxOffset = max(0, documentView?.bounds.height ?? 0 - contentView.bounds.height)
        guard maxOffset > 0 else { return 0 }
        return min(max(contentView.bounds.origin.y / maxOffset, 0), 1)
    }

    var currentScrollSyncState: ScrollSyncState {
        let maxOffset = max(0, documentView?.bounds.height ?? 0 - contentView.bounds.height)
        let offset = min(max(contentView.bounds.origin.y, 0), maxOffset)
        let progress: CGFloat
        if maxOffset > 0 {
            progress = min(max(offset / maxOffset, 0), 1)
        } else {
            progress = 0
        }

        let edgeAffinity = ScrollSyncEdgeAffinity.resolve(
            offset: offset,
            maxOffset: maxOffset,
            viewportHeight: contentView.bounds.height
        )
        return ScrollSyncState(progress: progress, edgeAffinity: edgeAffinity, sourceLine: nil)
    }
}

enum ScrollSyncEdgeAffinity: String, Equatable {
    case top
    case middle
    case bottom

    static func resolve(offset: CGFloat, maxOffset: CGFloat, viewportHeight: CGFloat) -> ScrollSyncEdgeAffinity {
        guard maxOffset > 0 else { return .top }

        let remainingOffset = max(0, maxOffset - offset)
        let edgeThreshold = min(max(88, viewportHeight * 0.16), maxOffset * 0.5)

        if offset <= edgeThreshold {
            return .top
        }

        if remainingOffset <= edgeThreshold {
            return .bottom
        }

        return .middle
    }
}

struct ScrollSyncState: Equatable {
    let progress: CGFloat
    let edgeAffinity: ScrollSyncEdgeAffinity
    let sourceLine: Int?

    func targetOffset(maxOffset: CGFloat) -> CGFloat {
        guard maxOffset > 0 else { return 0 }

        switch edgeAffinity {
        case .top:
            return 0
        case .bottom:
            return maxOffset
        case .middle:
            return min(max(progress, 0), 1) * maxOffset
        }
    }

    func requiresSync(to other: ScrollSyncState) -> Bool {
        if let sourceLine, let otherSourceLine = other.sourceLine {
            return abs(sourceLine - otherSourceLine) > 0
                || abs(progress - other.progress) > 0.012
                || edgeAffinity != other.edgeAffinity
        }

        if edgeAffinity == other.edgeAffinity, edgeAffinity != .middle {
            return false
        }

        return abs(progress - other.progress) > 0.008 || edgeAffinity != other.edgeAffinity
    }
}
