import AppKit
import ScreenCaptureKit
import CoreGraphics

/// Wraps ScreenCaptureKit's `SCScreenshotManager.captureImage` for our three
/// capture modes. All calls are async and return a `CGImage` at the native
/// pixel scale of the source display.
enum CaptureError: Error, LocalizedError {
    case noDisplay
    case noContent(Error)
    case captureFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noDisplay:           return "No display found under the cursor."
        case .noContent(let e):    return "Couldn't enumerate displays: \(e.localizedDescription)"
        case .captureFailed(let e): return "Capture failed: \(e.localizedDescription)"
        }
    }
}

struct ScreenCaptureService {

    // MARK: - Full display

    /// Capture the entire `display`.
    static func captureFullScreen(display: SCDisplay) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width  = display.width  * scale(for: display)
        config.height = display.height * scale(for: display)
        config.showsCursor = false
        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            throw CaptureError.captureFailed(error)
        }
    }

    /// Capture `rect` (in display-local points, origin top-left) from `display`.
    static func captureRegion(_ rect: CGRect, on display: SCDisplay) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        let s = scale(for: display)
        // SCStreamConfiguration sourceRect is in points; width/height are in pixels.
        config.sourceRect = rect
        config.width  = Int(rect.width  * CGFloat(s))
        config.height = Int(rect.height * CGFloat(s))
        config.showsCursor = false
        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            throw CaptureError.captureFailed(error)
        }
    }

    // MARK: - Single window

    static func captureWindow(_ window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        let s = Int(NSScreen.main?.backingScaleFactor ?? 2)
        config.width  = Int(window.frame.width)  * s
        config.height = Int(window.frame.height) * s
        config.showsCursor = false
        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            throw CaptureError.captureFailed(error)
        }
    }

    // MARK: - Content enumeration

    static func shareableContent() async throws -> SCShareableContent {
        do {
            return try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            throw CaptureError.noContent(error)
        }
    }

    // MARK: - Helpers

    /// Find the SCDisplay that matches a given NSScreen by display ID.
    static func display(for screen: NSScreen, in content: SCShareableContent) -> SCDisplay? {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        let displayID = CGDirectDisplayID(screenNumber.uint32Value)
        return content.displays.first { $0.displayID == displayID }
    }

    /// NSScreen under a global point (flipped for AppKit coords).
    static func screen(at point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { $0.frame.contains(point) }
    }

    private static func scale(for display: SCDisplay) -> Int {
        // Match the physical pixel size of the matching NSScreen if we can;
        // fall back to 2x.
        if let ns = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display.displayID
        }) {
            return Int(ns.backingScaleFactor)
        }
        return 2
    }
}
