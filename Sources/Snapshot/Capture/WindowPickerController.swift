import AppKit
import ScreenCaptureKit

/// Presents a full-screen overlay that highlights the window under the
/// cursor. Click to pick, Esc to cancel.
///
/// Windows are enumerated once at session start via `SCShareableContent`. A
/// tracking area on the overlay fires `mouseMoved` events so we can update
/// the highlight as the user hovers.
@MainActor
final class WindowPickerController {

    private var overlay: SelectionOverlayWindow?
    private var view: WindowHighlightView?
    private var windows: [SCWindow] = []
    private var completion: ((SCWindow?) -> Void)?

    func present(completion: @escaping (SCWindow?) -> Void) {
        self.completion = completion

        Task { @MainActor in
            do {
                let content = try await ScreenCaptureService.shareableContent()
                // Filter out our own overlay windows + zero-sized windows.
                self.windows = content.windows.filter { w in
                    w.isOnScreen &&
                    w.frame.width > 10 &&
                    w.frame.height > 10 &&
                    w.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
                }
                self.showOverlay()
            } catch {
                self.finish(with: nil)
            }
        }
    }

    private func showOverlay() {
        guard let screen = NSScreen.main else {
            finish(with: nil)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        let window = SelectionOverlayWindow(screen: screen)
        let v = WindowHighlightView(frame: NSRect(origin: .zero, size: screen.frame.size))
        v.windows = windows
        v.screen = screen
        v.onPick = { [weak self] scWindow in self?.finish(with: scWindow) }
        v.onCancel = { [weak self] in self?.finish(with: nil) }
        window.contentView = v
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(v)
        self.overlay = window
        self.view = v
    }

    private func finish(with window: SCWindow?) {
        let handler = completion
        completion = nil
        overlay?.orderOut(nil)
        overlay = nil
        view = nil
        handler?(window)
    }
}

/// Full-screen transparent view that tracks mouse moves and highlights the
/// topmost `SCWindow` containing the cursor.
final class WindowHighlightView: NSView {

    var windows: [SCWindow] = []
    weak var screen: NSScreen?
    var onPick: ((SCWindow) -> Void)?
    var onCancel: (() -> Void)?

    private var hoveredWindow: SCWindow?
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    // MARK: - Hit testing

    /// ScreenCaptureKit uses the Core Graphics coordinate space — origin at
    /// the top-left of the primary display, y increasing downward. Convert
    /// an AppKit event location (bottom-left origin on the current screen)
    /// into that space before testing window frames.
    private func cgPoint(forLocationInWindow locationInWindow: NSPoint) -> CGPoint {
        guard let screen = screen else { return .zero }
        let viewPoint = convert(locationInWindow, from: nil)
        // Screen-local AppKit point:
        let screenPoint = NSPoint(
            x: screen.frame.origin.x + viewPoint.x,
            y: screen.frame.origin.y + viewPoint.y
        )
        // Flip y against the primary display's height.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        return CGPoint(x: screenPoint.x, y: primaryHeight - screenPoint.y)
    }

    private func windowAt(locationInWindow: NSPoint) -> SCWindow? {
        let p = cgPoint(forLocationInWindow: locationInWindow)
        // SCShareableContent returns windows in z-order, frontmost first.
        return windows.first { $0.frame.contains(p) }
    }

    // MARK: - Events

    override func mouseMoved(with event: NSEvent) {
        let w = windowAt(locationInWindow: event.locationInWindow)
        if w?.windowID != hoveredWindow?.windowID {
            hoveredWindow = w
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        if let w = windowAt(locationInWindow: event.locationInWindow) {
            onPick?(w)
        } else {
            onCancel?()
        }
    }

    override func keyDown(with event: NSEvent) {
        if Int(event.keyCode) == 53 { // Esc
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.25).setFill()
        bounds.fill()

        guard let w = hoveredWindow, let screen = screen else { return }

        // Convert the SCWindow frame (CG / top-left) back into our view-local
        // AppKit frame (bottom-left, screen-relative).
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let rectInAppKit = NSRect(
            x: w.frame.origin.x - screen.frame.origin.x,
            y: primaryHeight - w.frame.origin.y - w.frame.height - screen.frame.origin.y,
            width: w.frame.width,
            height: w.frame.height
        )

        // Punch out highlight area.
        NSColor.clear.setFill()
        NSGraphicsContext.current?.compositingOperation = .copy
        rectInAppKit.intersection(bounds).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver

        NSColor.controlAccentColor.setStroke()
        let border = NSBezierPath(rect: rectInAppKit)
        border.lineWidth = 2
        border.stroke()

        // Label with the window's app name.
        let name = w.owningApplication?.applicationName ?? "Window"
        let title = w.title.flatMap { $0.isEmpty ? nil : $0 } ?? ""
        let labelText = title.isEmpty ? name : "\(name) — \(title)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        let string = NSAttributedString(string: " \(labelText) ", attributes: attrs)
        let size = string.size()
        let origin = NSPoint(
            x: rectInAppKit.minX + 8,
            y: rectInAppKit.maxY - size.height - 8
        )
        string.draw(at: origin)
    }
}
