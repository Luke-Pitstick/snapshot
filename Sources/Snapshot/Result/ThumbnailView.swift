import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Small preview card for a fresh screenshot. The image fills the entire
/// rounded-rect card with no padding; only an X button overlays the
/// top-right corner.
///
/// - Drag out the card to produce a PNG file.
/// - Right-click for Save As… / Copy / Open in Preview / Dismiss.
/// - Click to open in Preview.
/// - Hover pauses the auto-dismiss timer on the parent controller.
struct ThumbnailView: View {
    let result: CaptureResult
    let onSaveAs: () -> Void
    let onCopy: () -> Void
    let onOpen: () -> Void
    let onDismiss: () -> Void
    let onHoverChange: (Bool) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(nsImage: result.nsImage)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: 220, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(radius: 12, y: 6)
                .onDrag {
                    let provider = NSItemProvider()
                    provider.registerDataRepresentation(
                        forTypeIdentifier: UTType.png.identifier,
                        visibility: .all
                    ) { completion in
                        completion(result.pngData, nil)
                        return nil
                    }
                    return provider
                }
                .onTapGesture { onOpen() }
                .contextMenu {
                    Button("Save As…") { onSaveAs() }
                    Button("Copy") { onCopy() }
                    Button("Open in Preview") { onOpen() }
                    Divider()
                    Button("Dismiss") { onDismiss() }
                }

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.black.opacity(0.55))
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .frame(width: 220, height: 160)
        .onHover(perform: onHoverChange)
    }
}
