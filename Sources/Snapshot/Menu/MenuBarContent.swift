import SwiftUI

/// Menu shown when the user clicks the status-bar icon.
struct MenuBarContent: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Capture Region") {
            AppCoordinator.shared?.capture.run(.region)
        }
        Button("Capture Full Screen") {
            AppCoordinator.shared?.capture.run(.fullScreen)
        }
        Button("Capture Window") {
            AppCoordinator.shared?.capture.run(.window)
        }
        Divider()
        Button("Settings…") { openSettings() }
            .keyboardShortcut(",")
        Divider()
        Button("Quit Snapshot") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
