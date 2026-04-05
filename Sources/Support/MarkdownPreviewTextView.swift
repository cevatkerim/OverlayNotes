import AppKit
import SwiftUI
import WebKit

struct MarkdownPreviewTextView: NSViewRepresentable {
    let text: String
    let textScale: Double
    let isOverlay: Bool
    let baseURL: URL?
    let themeOverride: OverlayThemeOverride
    var scrollSyncBridge: ScrollSyncBridge? = nil
    var scrollSyncSource: ScrollSyncSource? = nil
    var scrollSyncCommand: ScrollSyncCommand?
    var verticalScrollElasticity: NSScrollView.Elasticity = .automatic
    var onUserInteraction: (() -> Void)? = nil
    var onScrollProgressChanged: ((ScrollSyncState) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            scrollSyncBridge: scrollSyncBridge,
            scrollSyncSource: scrollSyncSource,
            onUserInteraction: onUserInteraction,
            onScrollProgressChanged: onScrollProgressChanged
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: Coordinator.scrollMessageHandlerName)
        configuration.userContentController.add(context.coordinator, name: Coordinator.userInteractionHandlerName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        webView.appearance = themeOverride.appearance
        if #available(macOS 13.0, *) {
            webView.underPageBackgroundColor = .clear
        }
        setVerticalScrollElasticity(verticalScrollElasticity, for: webView)

        context.coordinator.attach(webView)
        if let scrollSyncBridge, let scrollSyncSource {
            scrollSyncBridge.register(context.coordinator, for: scrollSyncSource)
        }
        context.coordinator.reloadShellIfNeeded(
            baseURL: baseURL,
            text: text,
            textScale: textScale,
            isOverlay: isOverlay,
            themeOverride: themeOverride,
            scrollSyncCommand: scrollSyncCommand
        )

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.appearance = themeOverride.appearance
        setVerticalScrollElasticity(verticalScrollElasticity, for: webView)
        context.coordinator.attach(webView)
        context.coordinator.scrollSyncBridge = scrollSyncBridge
        context.coordinator.scrollSyncSource = scrollSyncSource
        context.coordinator.onUserInteraction = onUserInteraction
        context.coordinator.onScrollProgressChanged = onScrollProgressChanged

        if let scrollSyncBridge, let scrollSyncSource {
            scrollSyncBridge.register(context.coordinator, for: scrollSyncSource)
        }
        context.coordinator.reloadShellIfNeeded(
            baseURL: baseURL,
            text: text,
            textScale: textScale,
            isOverlay: isOverlay,
            themeOverride: themeOverride,
            scrollSyncCommand: scrollSyncCommand
        )
    }

    private func setVerticalScrollElasticity(_ elasticity: NSScrollView.Elasticity, for webView: WKWebView) {
        webView.descendantScrollView?.verticalScrollElasticity = elasticity
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, ScrollSyncEndpoint {
        static let scrollMessageHandlerName = "overlayNotesScroll"
        static let userInteractionHandlerName = "overlayNotesUserScroll"

        private weak var webView: WKWebView?
        private var isReady = false
        private var hasLoadedShell = false
        private var lastBaseURL: URL?
        private var pendingPayload: PreviewPayload?
        private var pendingScrollSyncCommand: ScrollSyncCommand?
        private var lastRenderedPayload: PreviewPayload?
        var scrollSyncBridge: ScrollSyncBridge?
        var scrollSyncSource: ScrollSyncSource?
        var onUserInteraction: (() -> Void)?
        var onScrollProgressChanged: ((ScrollSyncState) -> Void)?
        private var isApplyingSyncedScroll = false
        private var lastAppliedCommandID: UUID?
        private var lastReportedState: ScrollSyncState?

        init(
            scrollSyncBridge: ScrollSyncBridge?,
            scrollSyncSource: ScrollSyncSource?,
            onUserInteraction: (() -> Void)?,
            onScrollProgressChanged: ((ScrollSyncState) -> Void)?
        ) {
            self.scrollSyncBridge = scrollSyncBridge
            self.scrollSyncSource = scrollSyncSource
            self.onUserInteraction = onUserInteraction
            self.onScrollProgressChanged = onScrollProgressChanged
        }

        func attach(_ webView: WKWebView) {
            self.webView = webView
        }

        func reloadShellIfNeeded(baseURL: URL?, text: String, textScale: Double, isOverlay: Bool, themeOverride: OverlayThemeOverride, scrollSyncCommand: ScrollSyncCommand?) {
            let payload = PreviewPayload(
                text: text,
                textScale: textScale,
                isOverlay: isOverlay,
                baseURL: baseURL,
                themeOverride: themeOverride
            )
            pendingPayload = payload
            pendingScrollSyncCommand = scrollSyncCommand

            if hasLoadedShell == false || lastBaseURL != baseURL {
                isReady = false
                hasLoadedShell = true
                lastBaseURL = baseURL
                webView?.loadHTMLString(MarkdownRenderer.htmlDocument(), baseURL: baseURL)
                return
            }

            applyPendingPayloadIfPossible()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isReady = true
            applyPendingPayloadIfPossible()
        }

        @MainActor
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == Self.userInteractionHandlerName {
                if let scrollSyncBridge, let scrollSyncSource {
                    Task { @MainActor in
                        scrollSyncBridge.activateLeader(scrollSyncSource)
                    }
                }
                let handler = onUserInteraction
                DispatchQueue.main.async {
                    handler?()
                }
                return
            }

            guard message.name == Self.scrollMessageHandlerName else { return }
            guard isApplyingSyncedScroll == false else { return }

            let state = scrollSyncState(from: message.body)
            guard lastReportedState?.requiresSync(to: state) != false else { return }
            lastReportedState = state

            let handler = onScrollProgressChanged
            DispatchQueue.main.async {
                handler?(state)
            }
        }

        private func applyPendingPayloadIfPossible() {
            guard isReady, let webView, let pendingPayload else { return }
            guard pendingPayload != lastRenderedPayload else {
                apply(scrollSyncCommand: pendingScrollSyncCommand, to: webView)
                return
            }

            lastRenderedPayload = pendingPayload
            let previewMarkdown = MarkdownRenderer.prepareMarkdownForPreview(
                pendingPayload.text,
                baseURL: pendingPayload.baseURL
            )
            let fallbackHTML = MarkdownRenderer.renderHTMLBody(pendingPayload.text, baseURL: pendingPayload.baseURL)
            let scriptPayload: [String: Any] = [
                "markdown": previewMarkdown,
                "fallbackHTML": fallbackHTML,
                "baseFontSize": MarkdownRenderer.baseFontSize(textScale: pendingPayload.textScale, isOverlay: pendingPayload.isOverlay),
                "isOverlay": pendingPayload.isOverlay,
                "themeOverride": pendingPayload.themeOverride.rawValue
            ]

            guard let jsonData = try? JSONSerialization.data(withJSONObject: scriptPayload),
                  let json = String(data: jsonData, encoding: .utf8) else {
                return
            }

            lastAppliedCommandID = nil
            webView.evaluateJavaScript("window.__overlayNotesUpdate(\(json));") { [weak self, weak webView] _, _ in
                guard let self, let webView else { return }
                self.apply(scrollSyncCommand: self.pendingScrollSyncCommand, to: webView)
            }
        }

        private func apply(scrollSyncCommand: ScrollSyncCommand?, to webView: WKWebView) {
            guard let scrollSyncCommand else { return }
            guard lastAppliedCommandID != scrollSyncCommand.id else { return }
            guard lastReportedState?.requiresSync(to: scrollSyncCommand.state) != false else {
                lastAppliedCommandID = scrollSyncCommand.id
                return
            }

            lastAppliedCommandID = scrollSyncCommand.id
            isApplyingSyncedScroll = true
            lastReportedState = scrollSyncCommand.state
            let progress = min(max(Double(scrollSyncCommand.progress), 0), 1)
            let edgeAffinity = scrollSyncCommand.edgeAffinity.rawValue
            let sourceLineArgument = scrollSyncCommand.sourceLine.map(String.init) ?? "null"
            webView.evaluateJavaScript("window.__overlayNotesSetScrollProgress(\(progress), '\(edgeAffinity)', \(sourceLineArgument));") { [weak self] _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    self?.isApplyingSyncedScroll = false
                }
            }
        }

        var currentScrollSyncState: ScrollSyncState {
            lastReportedState ?? ScrollSyncState(progress: 0, edgeAffinity: .top, sourceLine: 1)
        }

        func applyScrollSyncCommand(_ command: ScrollSyncCommand) {
            guard let webView else { return }
            apply(scrollSyncCommand: command, to: webView)
        }

        func setVerticalScrollElasticity(_ elasticity: NSScrollView.Elasticity) {
            guard let webView else { return }
            webView.descendantScrollView?.verticalScrollElasticity = elasticity
        }

        private func scrollSyncState(from messageBody: Any) -> ScrollSyncState {
            if let dictionary = messageBody as? [String: Any] {
                let progress = CGFloat(min(max((dictionary["progress"] as? NSNumber)?.doubleValue ?? 0, 0), 1))
                let edgeAffinity = (dictionary["edgeAffinity"] as? String).flatMap(ScrollSyncEdgeAffinity.init(rawValue:)) ?? .middle
                let sourceLine = (dictionary["sourceLine"] as? NSNumber)?.intValue
                return ScrollSyncState(progress: progress, edgeAffinity: edgeAffinity, sourceLine: sourceLine)
            }

            if let dictionary = messageBody as? NSDictionary {
                let progress = CGFloat(min(max((dictionary["progress"] as? NSNumber)?.doubleValue ?? 0, 0), 1))
                let edgeAffinity = (dictionary["edgeAffinity"] as? String).flatMap(ScrollSyncEdgeAffinity.init(rawValue:)) ?? .middle
                let sourceLine = (dictionary["sourceLine"] as? NSNumber)?.intValue
                return ScrollSyncState(progress: progress, edgeAffinity: edgeAffinity, sourceLine: sourceLine)
            }

            let progressValue: Double?
            switch messageBody {
            case let number as NSNumber:
                progressValue = number.doubleValue
            case let string as String:
                progressValue = Double(string)
            default:
                progressValue = nil
            }

            let progress = CGFloat(min(max(progressValue ?? 0, 0), 1))
            return ScrollSyncState(progress: progress, edgeAffinity: .middle, sourceLine: nil)
        }
    }
}

private extension WKWebView {
    var descendantScrollView: NSScrollView? {
        if let scrollView = subviews.first(where: { $0 is NSScrollView }) as? NSScrollView {
            return scrollView
        }

        return findScrollView(in: self)
    }

    private func findScrollView(in view: NSView) -> NSScrollView? {
        for subview in view.subviews {
            if let scrollView = subview as? NSScrollView {
                return scrollView
            }

            if let nestedScrollView = findScrollView(in: subview) {
                return nestedScrollView
            }
        }

        return nil
    }
}

private struct PreviewPayload: Equatable {
    let text: String
    let textScale: Double
    let isOverlay: Bool
    let baseURL: URL?
    let themeOverride: OverlayThemeOverride
}
