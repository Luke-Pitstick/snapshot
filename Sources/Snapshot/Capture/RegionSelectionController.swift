import AppKit
import ScreenCaptureKit

/// Owns the lifetime of the region-selection session: spawns one overlay
/// window per attached display, waits for the user to finish (or cancel),
/// then calls the completion handler with the chosen rect + screen.
@MainActor
final class RegionSelectionController {

    struct Selection {
        let rect: NSRect      // in screen coordinates (AppKit, origin bottom-left)
        let screen: NSScreen
    }

    private var overlays: [SelectionOverlayWindow] = []
    private var completion: ((Selection?) -> Void)?

    /// Present overlays and wait. Handler is called exactly once, either with
    /// the final selection or `nil` if the user cancelled.
    func present(completion: @escaping (Selection?) -> Void) {
        self.completion = completion

        NSApp.activate(ignoringOtherApps: true)

        for screen in NSScreen.screens {
            let window = SelectionOverlayWindow(screen: screen)
            let view = SelectionOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.onSelect = { [weak self] rect in
                self?.finish(with: Selection(rect: rect, screen: screen))
            }
            view.onCancel = { [weak self] in
                self?.finish(with: nil)
            }
            window.contentView = view
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(view)
            overlays.append(window)
        }
    }

    private func finish(with selection: Selection?) {
        let handler = completion
        completion = nil
        for w in overlays {
            w.orderOut(nil)
        }
        overlays.removeAll()
        handler?(selection)
    }
}
