import SwiftUI
import AppKit

/// Full preview of a captured screenshot with an action toolbar.
/// Hosted by `PreviewWindowController` inside a resizable titled window.
struct PreviewView: View {
    let result: CaptureResult
    let onCopy: () -> Void
    let onSaveAs: () -> Void
    let onSaveQuick: () -> Void
    let onOpenInPreview: () -> Void
    let onRevealInFinder: () -> Void

    @State private var savedMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // The image fills all remaining vertical space and scales
            // proportionally. A checkered/dark backdrop keeps transparent
            // screenshots legible.
            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                Image(nsImage: result.nsImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .padding(16)
            }

            Divider()

            HStack(spacing: 8) {
                Text("\(result.cgImage.width) × \(result.cgImage.height)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

                if let message = savedMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(message)
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                    .transition(.opacity)
                }

                Spacer()

                Button {
                    onCopy()
                    flash("Copied")
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help("Copy to clipboard")
                .keyboardShortcut("c", modifiers: .command)

                Button {
                    onSaveQuick()
                    flash("Saved")
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .help("Save to the default folder")
                .keyboardShortcut("s", modifiers: .command)

                Button {
                    onSaveAs()
                } label: {
                    Label("Save As…", systemImage: "square.and.arrow.down.on.square")
                }
                .help("Choose where to save…")
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Menu {
                    Button("Open in Preview", action: onOpenInPreview)
                    Button("Reveal in Finder", action: onRevealInFinder)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.bar)
        }
        .frame(minWidth: 400, minHeight: 300)
    }

    private func flash(_ text: String) {
        withAnimation { savedMessage = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { savedMessage = nil }
        }
    }
}
