import SwiftUI

struct OverlayPaneView: View {
    @ObservedObject var session: NoteSession
    @State private var initialResizeSize: CGSize?

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                header
                Divider().overlay(Color.white.opacity(0.12))
                content
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .overlay(alignment: .bottomTrailing) {
            if session.overlayPlacement.isClickThrough == false {
                resizeHandle
                    .padding(12)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .preferredColorScheme(session.overlayAppearance.themeOverride.colorScheme)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.fileDisplayName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(session.shareSafetyMode.title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 18)

            if session.overlayPlacement.isClickThrough == false {
                Picker("Mode", selection: $session.overlayMode) {
                    ForEach(OverlayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)

                Button {
                    session.setClickThrough(true)
                } label: {
                    Image(systemName: "lock.fill")
                }
                .help("Lock overlay and make it click-through")

                Menu {
                    ForEach(OverlaySnapPreset.allCases) { preset in
                        Button {
                            session.snapOverlay(to: preset)
                        } label: {
                            Label(preset.title, systemImage: preset.systemImage)
                        }
                    }
                } label: {
                    Image(systemName: "square.split.2x2")
                }

                Button {
                    session.toggleOverlayVisibility()
                } label: {
                    Image(systemName: "xmark")
                }
                .help("Hide overlay")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var content: some View {
        switch session.overlayMode {
        case .read:
            MarkdownPreviewView(
                text: session.text,
                textScale: session.overlayAppearance.textScale,
                isOverlay: true,
                baseURL: session.previewBaseURL,
                themeOverride: session.overlayAppearance.themeOverride
            )
        case .edit:
            MarkdownTextEditor(
                text: $session.text,
                fontSize: 16 * session.overlayAppearance.textScale,
                isEditable: true,
                drawBackground: false,
                themeOverride: session.overlayAppearance.themeOverride
            )
                .padding(14)
                .background(Color.clear)
        }
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(session.overlayAppearance.tintColor.color.opacity(session.overlayAppearance.opacity))
            .overlay {
                if let material = session.overlayAppearance.blurMaterial.material {
                    VisualEffectView(material: material)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .opacity(session.overlayAppearance.opacity)
                }
            }
    }

    private var resizeHandle: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(10)
            .background(.thinMaterial, in: Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if initialResizeSize == nil {
                            initialResizeSize = session.overlaySize
                        }

                        guard let initialResizeSize else { return }
                        let nextSize = CGSize(
                            width: initialResizeSize.width + value.translation.width,
                            height: initialResizeSize.height + value.translation.height
                        )
                        session.setOverlaySize(nextSize)
                    }
                    .onEnded { _ in
                        initialResizeSize = nil
                    }
            )
    }
}
