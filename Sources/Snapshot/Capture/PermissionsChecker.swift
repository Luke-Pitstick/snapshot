import AppKit
import CoreGraphics

/// Thin wrapper around the TCC Screen Recording permission APIs.
enum PermissionsChecker {

    /// Non-triggering preflight check.
    static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Triggers the system prompt the first time it's called in a given
    /// process. Subsequent calls just return the cached answer — the user has
    /// to flip the toggle in System Settings and relaunch the app to change
    /// their mind, which the `openSystemSettings` helper below helps with.
    @discardableResult
    static func requestScreenRecordingPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    /// Show a blocking alert and offer to open the Privacy pane.
    @MainActor
    static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Snapshot needs Screen Recording permission"
        alert.informativeText = """
            macOS requires apps to be explicitly granted Screen Recording \
            permission before they can capture the screen. Click "Open \
            System Settings", enable Snapshot in the list, then relaunch \
            the app.
            """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openSystemSettings()
        }
    }

    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
