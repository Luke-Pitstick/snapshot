import AppKit

/// Owns the top-level app services: the capture coordinator, the hotkey
/// manager, and the result router. Exposed as a singleton so SwiftUI Settings
/// views can poke it when preferences change.
@MainActor
final class AppCoordinator {

    static private(set) var shared: AppCoordinator?

    let preferences: Preferences
    let router: ResultRouter
    let capture: CaptureCoordinator

    init(preferences: Preferences) {
        self.preferences = preferences
        self.router = ResultRouter(preferences: preferences)
        self.capture = CaptureCoordinator(preferences: preferences, router: router)
        AppCoordinator.shared = self
        reloadHotkeys()
    }

    /// Register (or re-register) all three capture hotkeys with the current
    /// values from `Preferences`. Called on startup and whenever the user
    /// changes a binding in the Settings UI.
    func reloadHotkeys() {
        let manager = HotKeyManager.shared
        manager.unregisterAll()

        let regionOK = manager.register(.region, combo: preferences.regionHotkey) { [weak self] in
            self?.capture.run(.region, sourceFlags: NSEvent.modifierFlags)
        }
        let fullOK = manager.register(.fullScreen, combo: preferences.fullScreenHotkey) { [weak self] in
            self?.capture.run(.fullScreen, sourceFlags: NSEvent.modifierFlags)
        }
        let winOK = manager.register(.window, combo: preferences.windowHotkey) { [weak self] in
            self?.capture.run(.window, sourceFlags: NSEvent.modifierFlags)
        }

        if !(regionOK && fullOK && winOK) {
            // Non-fatal — user can pick a different combo in Settings.
            NSLog("Snapshot: one or more hotkeys could not be registered (probably already taken).")
        }
    }
}
