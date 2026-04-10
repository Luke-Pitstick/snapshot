import AppKit

/// Decides what to do with a fresh capture — copy to the clipboard or show a
/// floating thumbnail — based on user preferences, with optional per-capture
/// override from modifier flags the user is holding when the hotkey fires.
@MainActor
final class ResultRouter {

    private let preferences: Preferences
    private var thumbnailController: ThumbnailWindowController?

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    /// `overrideFlags` are the modifier flags present when the hot key fired
    /// (or `nil` for menu-item invocation). If the user's override modifier
    /// is set and present in those flags, we flip the destination.
    func handle(_ result: CaptureResult, overrideFlags: NSEvent.ModifierFlags?) {
        let destination = effectiveDestination(overrideFlags: overrideFlags)
        switch destination {
        case .clipboard:
            copyToClipboard(result)
        case .thumbnail:
            showThumbnail(result)
        }
    }

    private func effectiveDestination(overrideFlags: NSEvent.ModifierFlags?) -> DefaultDestination {
        let base = preferences.defaultDestination
        guard let flags = overrideFlags,
              let override = preferences.overrideModifier,
              flags.contains(override) else {
            return base
        }
        return base == .clipboard ? .thumbnail : .clipboard
    }

    // MARK: - Clipboard

    private func copyToClipboard(_ result: CaptureResult) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let png = result.pngData {
            pasteboard.setData(png, forType: .png)
        }
        let rep = NSBitmapImageRep(cgImage: result.cgImage)
        if let tiff = rep.tiffRepresentation {
            pasteboard.setData(tiff, forType: .tiff)
        }
        // Optional lightweight confirmation: a brief flash of the thumbnail
        // style could live here, but per the plan we just copy silently.
    }

    // MARK: - Thumbnail

    private func showThumbnail(_ result: CaptureResult) {
        // Dismiss any previous thumbnail that's still lingering so a rapid
        // second capture doesn't land on top of the first.
        thumbnailController?.close()

        let controller = ThumbnailWindowController(
            result: result,
            preferences: preferences
        )
        self.thumbnailController = controller
        // Use orderFrontRegardless on the underlying panel so we show
        // without stealing focus — showWindow() tries to make the window
        // key, which a non-activating panel politely refuses.
        controller.window?.orderFrontRegardless()
        controller.startAutoDismissTimer()
    }
}
