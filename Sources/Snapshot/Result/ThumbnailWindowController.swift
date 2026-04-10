import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Floating window in the bottom-right corner of the active screen. Shows a
/// preview of the last capture and lets the user drag it out, save it, open
/// it, or dismiss.
@MainActor
final class ThumbnailWindowController: NSWindowController {

    private let result: CaptureResult
    private let preferences: Preferences
    private var dismissTimer: Timer?

    init(result: CaptureResult, preferences: Preferences) {
        self.result = result
        self.preferences = preferences

        let contentSize = NSSize(width: 220, height: 160)
        // NSPanel (not NSWindow) is the right class for a floating accessory
        // surface: it supports .nonactivatingPanel properly, and with
        // `becomesKeyOnlyIfNeeded` set it can display without stealing focus
        // from whatever the user was typing into.
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.worksWhenModal = true
        panel.hidesOnDeactivate = false

        super.init(window: panel)

        let rootView = ThumbnailView(
            result: result,
            onSaveAs: { [weak self] in self?.saveAs() },
            onCopy:   { [weak self] in self?.copyToClipboard() },
            onOpen:   { [weak self] in self?.openPreviewWindow() },
            onDismiss:{ [weak self] in self?.dismiss() },
            onHoverChange: { [weak self] hovering in
                if hovering {
                    self?.dismissTimer?.invalidate()
                } else {
                    self?.startAutoDismissTimer()
                }
            }
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(origin: .zero, size: contentSize)
        panel.contentView = hosting

        positionInBottomRight()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Layout

    private func positionInBottomRight() {
        guard let window = window else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return }
        let margin: CGFloat = 20
        let origin = NSPoint(
            x: visible.maxX - window.frame.width - margin,
            y: visible.minY + margin
        )
        window.setFrameOrigin(origin)
    }

    // MARK: - Auto dismiss

    func startAutoDismissTimer() {
        dismissTimer?.invalidate()
        let interval = preferences.autoDismissSeconds
        guard interval > 0 else { return }
        dismissTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }

    // MARK: - Actions

    private func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        window?.orderOut(nil)
    }

    private func copyToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let png = result.pngData {
            pb.setData(png, forType: .png)
        }
    }

    private func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType.png]
        panel.nameFieldStringValue = result.defaultFileName
        if let url = preferences.defaultSaveDirectoryURL {
            panel.directoryURL = url
        }
        panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let data = self?.result.pngData else { return }
            do {
                try data.write(to: url)
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    /// Open the full-size preview window (custom, with Copy / Save / Save As
    /// buttons) and dismiss the thumbnail itself — the preview takes over.
    private func openPreviewWindow() {
        let controller = PreviewWindowController(
            result: result,
            preferences: preferences
        )
        PreviewWindowRegistry.shared.retain(controller)
        controller.show()
        dismiss()
    }
}
