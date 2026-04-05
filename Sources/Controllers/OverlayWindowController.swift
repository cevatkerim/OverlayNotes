import AppKit
import Combine
import SwiftUI

@MainActor
final class OverlayWindowController: NSObject, NSWindowDelegate {
    private let session: NoteSession
    private let window: OverlayWindow
    private var cancellables: Set<AnyCancellable> = []
    private var isApplyingProgrammaticFrameChange = false
    private var isWindowStateUpdateScheduled = false
    private var pendingAnimatedStateUpdate = false

    init(session: NoteSession) {
        self.session = session
        self.window = OverlayWindow(
            contentRect: CGRect(x: 0, y: 0, width: 440, height: 280),
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        super.init()

        configureWindow()
        installContent()
        configureSubscriptions()
        scheduleWindowStateUpdate(animated: false)
    }

    func invalidate() {
        cancellables.removeAll()
        window.delegate = nil
        window.orderOut(nil)
    }

    func windowDidMove(_ notification: Notification) {
        guard isApplyingProgrammaticFrameChange == false else { return }
        session.updatePlacementFromWindow(frame: window.frame, displayID: window.screen?.overlayDisplayID)
    }

    func windowDidResize(_ notification: Notification) {
        guard isApplyingProgrammaticFrameChange == false else { return }
        session.updatePlacementFromWindow(frame: window.frame, displayID: window.screen?.overlayDisplayID)
    }

    private func configureWindow() {
        window.delegate = self
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        // AppKit forbids combining canJoinAllSpaces with moveToActiveSpace.
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
    }

    private func installContent() {
        let hosting = NSHostingView(rootView: OverlayPaneView(session: session))
        hosting.wantsLayer = true
        hosting.layer?.masksToBounds = false
        window.contentView = hosting
    }

    private func configureSubscriptions() {
        session.$isOverlayVisible
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleWindowStateUpdate(animated: false)
            }
            .store(in: &cancellables)

        session.$overlayPlacement
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleWindowStateUpdate(animated: true)
            }
            .store(in: &cancellables)

        session.$overlayAppearance
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleWindowStateUpdate(animated: false)
            }
            .store(in: &cancellables)

        session.$overlayMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleWindowStateUpdate(animated: false)
            }
            .store(in: &cancellables)

        session.$shareSafetyMode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleWindowStateUpdate(animated: false)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleWindowStateUpdate(animated: false)
            }
            .store(in: &cancellables)
    }

    private func scheduleWindowStateUpdate(animated: Bool) {
        pendingAnimatedStateUpdate = pendingAnimatedStateUpdate || animated
        guard isWindowStateUpdateScheduled == false else { return }

        isWindowStateUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isWindowStateUpdateScheduled = false
            let shouldAnimate = self.pendingAnimatedStateUpdate
            self.pendingAnimatedStateUpdate = false
            self.applyWindowState(animated: shouldAnimate)
        }
    }

    private func applyWindowState(animated: Bool) {
        window.level = session.overlayPlacement.staysOnTop ? .statusBar : .normal
        window.ignoresMouseEvents = session.overlayPlacement.isClickThrough
        window.appearance = session.overlayAppearance.themeOverride.appearance

        guard session.isOverlayVisible, session.canDisplayOverlay else {
            window.orderOut(nil)
            return
        }

        if let frame = session.resolvedOverlayFrame() {
            let nextFrame = frame.integral
            if window.frame.integral != nextFrame {
                isApplyingProgrammaticFrameChange = true
                window.setFrame(nextFrame, display: true, animate: animated)
                isApplyingProgrammaticFrameChange = false
            }
        }

        if session.overlayPlacement.isClickThrough {
            window.orderFrontRegardless()
        } else if session.overlayMode == .read {
            window.orderFront(nil)
            session.focusEditorWindow()
        } else {
            NSApplication.shared.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
