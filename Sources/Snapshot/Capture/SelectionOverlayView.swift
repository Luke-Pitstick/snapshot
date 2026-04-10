import AppKit

/// Tracks mouse drags, draws a dimmed-out backdrop with a bright hole for the
/// selected rect plus marching ants around the edge, and reports the final
/// rect to `onSelect`.
///
/// Keyboard:
/// - Esc cancels the whole selection session.
/// - Enter confirms the current rect (or a 1×1 rect if the user hasn't dragged).
final class SelectionOverlayView: NSView {

    /// Called when the user finishes a drag. The rect is in view coordinates
    /// (same as screen-local AppKit coordinates since the overlay matches the
    /// screen frame).
    var onSelect: ((NSRect) -> Void)?
    var onCancel: (() -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: NSRect = .zero
    private var isDragging = false
    private var trackingArea: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    /// Use a tracking area with `.cursorUpdate` rather than `addCursorRect`
    /// because cursor rects only fire when the window is key — and our
    /// borderless overlay window isn't always key, especially on displays
    /// other than the one with the drag origin.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .inVisibleRect, .cursorUpdate, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func cursorUpdate(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.crosshair.set()
    }

    // MARK: - Mouse

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        startPoint = p
        currentRect = NSRect(origin: p, size: .zero)
        isDragging = true
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let p = convert(event.locationInWindow, from: nil)
        currentRect = NSRect(
            x: min(start.x, p.x),
            y: min(start.y, p.y),
            width:  abs(p.x - start.x),
            height: abs(p.y - start.y)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        isDragging = false
        let rect = currentRect
        startPoint = nil
        if rect.width < 2 || rect.height < 2 {
            // Treat as a miss-click — cancel.
            onCancel?()
            return
        }
        onSelect?(rect)
    }

    // MARK: - Keyboard

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 53: // kVK_Escape
            onCancel?()
        case 36, 76: // kVK_Return, kVK_ANSI_KeypadEnter
            if currentRect.width >= 2 && currentRect.height >= 2 {
                onSelect?(currentRect)
            } else {
                onCancel?()
            }
        default:
            super.keyDown(with: event)
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        // Dim backdrop.
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()

        guard currentRect.width > 0, currentRect.height > 0 else { return }

        // Punch a hole for the selection.
        NSColor.clear.setFill()
        NSGraphicsContext.current?.compositingOperation = .copy
        currentRect.fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver

        // Bright border.
        NSColor.white.setStroke()
        let border = NSBezierPath(rect: currentRect)
        border.lineWidth = 1
        border.stroke()

        // Dimensions label near the bottom-right of the rect.
        let label = "\(Int(currentRect.width)) × \(Int(currentRect.height))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.65)
        ]
        let labelString = NSAttributedString(string: " \(label) ", attributes: attrs)
        let size = labelString.size()
        var labelOrigin = NSPoint(
            x: currentRect.maxX - size.width - 4,
            y: currentRect.minY - size.height - 4
        )
        if labelOrigin.y < 0 {
            labelOrigin.y = currentRect.maxY + 4
        }
        if labelOrigin.x < 0 {
            labelOrigin.x = currentRect.minX + 4
        }
        labelString.draw(at: labelOrigin)
    }
}
