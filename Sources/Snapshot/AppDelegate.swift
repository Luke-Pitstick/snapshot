import AppKit

/// NSApplicationDelegate that boots the `AppCoordinator` once the app has
/// finished launching. Runs with `LSUIElement=YES` (see Info.plist) so there's
/// no Dock icon or default menu bar.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private(set) var coordinator: AppCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure we're accessory-style even if something decides to promote
        // the app (e.g. opening an NSOpenPanel temporarily).
        NSApp.setActivationPolicy(.accessory)
        coordinator = AppCoordinator(preferences: .shared)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
