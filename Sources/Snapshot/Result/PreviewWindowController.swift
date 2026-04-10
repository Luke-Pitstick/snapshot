import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Standard titled window that hosts `PreviewView` — shown when the user
/// clicks the floating thumbnail. Handles the actual Copy / Save / Save As…
/// / Open In Preview / Reveal In Finder actions.
///
/// Remembers the most recent "quick save" URL so "Reveal in Finder" can
/// highlight it; if no quick save happened in this session, falls back to
/// writing a temp file and revealing that.
@MainActor
final class PreviewWindowController: NSWindowController, NSWindowDelegate {

    private let result: CaptureResult
    private let preferences: Preferences
    private var lastSavedURL: URL?

    init(result: CaptureResult, preferences: Preferences) {
        self.result = result
        self.preferences = preferences

        let initialSize = Self.initialWindowSize(for: result.cgImage)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = result.defaultFileName
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.center()
        window.collectionBehavior = [.fullScreenPrimary]

        super.init(window: window)
        window.delegate = self

        let rootView = PreviewView(
            result: result,
            onCopy:           { [weak self] in self?.copyToClipboard() },
            onSaveAs:         { [weak self] in self?.saveAs() },
            onSaveQuick:      { [weak self] in self?.quickSave() },
            onOpenInPreview:  { [weak self] in self?.openInSystemPreview() },
            onRevealInFinder: { [weak self] in self?.revealInFinder() }
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(origin: .zero, size: initialSize)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    // MARK: - Initial sizing

    /// Pick a reasonable starting window size: fit the screenshot at 1×
    /// up to 80% of the main screen in each dimension; add ~48pt for the
    /// toolbar row.
    private static func initialWindowSize(for image: CGImage) -> NSSize {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let maxWidth  = (screen?.visibleFrame.width  ?? 1400) * 0.8
        let maxHeight = (screen?.visibleFrame.height ?? 900)  * 0.8 - 48
        let w = CGFloat(image.width)
        let h = CGFloat(image.height)
        let scale = min(maxWidth / w, maxHeight / h, 1.0)
        return NSSize(width: max(w * scale, 420), height: max(h * scale + 48, 320))
    }

    // MARK: - Actions

    private func copyToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let png = result.pngData {
            pb.setData(png, forType: .png)
        }
        let rep = NSBitmapImageRep(cgImage: result.cgImage)
        if let tiff = rep.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }
    }

    private func quickSave() {
        guard let data = result.pngData else { return }
        let dir = preferences.defaultSaveDirectoryURL
            ?? FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let url = dir.appendingPathComponent(result.defaultFileName)
        do {
            try data.write(to: url)
            lastSavedURL = url
        } catch {
            NSAlert(error: error).runModal()
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
        panel.beginSheetModal(for: window ?? NSApp.mainWindow ?? NSWindow()) { [weak self] response in
            guard let self,
                  response == .OK,
                  let url = panel.url,
                  let data = self.result.pngData else { return }
            do {
                try data.write(to: url)
                self.lastSavedURL = url
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }

    private func openInSystemPreview() {
        guard let data = result.pngData else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(result.defaultFileName)
        do {
            try data.write(to: tempURL)
            NSWorkspace.shared.open(tempURL)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func revealInFinder() {
        if let url = lastSavedURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }
        // Nothing saved yet this session → write a temp copy just to reveal.
        guard let data = result.pngData else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(result.defaultFileName)
        do {
            try data.write(to: tempURL)
            NSWorkspace.shared.activateFileViewerSelecting([tempURL])
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        // Break the retain cycle held by ThumbnailWindowController.
        PreviewWindowRegistry.shared.release(self)
    }
}

/// Holds strong references to any open `PreviewWindowController`s so they
/// outlive their opener (the floating thumbnail, which dismisses itself).
@MainActor
final class PreviewWindowRegistry {
    static let shared = PreviewWindowRegistry()
    private var windows: [PreviewWindowController] = []

    func retain(_ controller: PreviewWindowController) {
        windows.append(controller)
    }

    func release(_ controller: PreviewWindowController) {
        windows.removeAll { $0 === controller }
    }
}
