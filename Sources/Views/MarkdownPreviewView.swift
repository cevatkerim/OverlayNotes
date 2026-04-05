import SwiftUI
import AppKit

struct MarkdownPreviewView: View {
    let text: String
    let textScale: Double
    let isOverlay: Bool
    let baseURL: URL?
    var themeOverride: OverlayThemeOverride = .system
    var scrollSyncBridge: ScrollSyncBridge? = nil
    var scrollSyncSource: ScrollSyncSource? = nil
    var scrollSyncCommand: ScrollSyncCommand? = nil
    var verticalScrollElasticity: NSScrollView.Elasticity = .automatic
    var onUserInteraction: (() -> Void)? = nil
    var onScrollProgressChanged: ((ScrollSyncState) -> Void)? = nil

    var body: some View {
        MarkdownPreviewTextView(
            text: text,
            textScale: textScale,
            isOverlay: isOverlay,
            baseURL: baseURL,
            themeOverride: themeOverride,
            scrollSyncBridge: scrollSyncBridge,
            scrollSyncSource: scrollSyncSource,
            scrollSyncCommand: scrollSyncCommand,
            verticalScrollElasticity: verticalScrollElasticity,
            onUserInteraction: onUserInteraction,
            onScrollProgressChanged: onScrollProgressChanged
        )
        .background(backgroundStyle)
    }

    @ViewBuilder
    private var backgroundStyle: some View {
        if isOverlay {
            Color.clear
        } else {
            Color(nsColor: resolvedColor(.textBackgroundColor))
        }
    }

    private func resolvedColor(_ color: NSColor) -> NSColor {
        color.resolvedForAppearance(themeOverride.appearance)
    }
}
