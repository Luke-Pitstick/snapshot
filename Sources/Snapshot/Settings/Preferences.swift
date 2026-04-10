import SwiftUI
import AppKit

enum DefaultDestination: String, CaseIterable, Identifiable {
    case clipboard
    case thumbnail

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .clipboard: return "Copy to Clipboard"
        case .thumbnail: return "Floating Thumbnail"
        }
    }
}

/// Raw-value wrapper so `NSEvent.ModifierFlags` is `@AppStorage`-friendly.
enum OverrideModifier: String, CaseIterable, Identifiable {
    case none
    case option
    case control
    case shift
    case command

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:    return "None"
        case .option:  return "⌥ Option"
        case .control: return "⌃ Control"
        case .shift:   return "⇧ Shift"
        case .command: return "⌘ Command"
        }
    }

    var flags: NSEvent.ModifierFlags? {
        switch self {
        case .none:    return nil
        case .option:  return .option
        case .control: return .control
        case .shift:   return .shift
        case .command: return .command
        }
    }
}

/// Observable wrapper over the handful of settings the app persists.
/// Values are stored in `UserDefaults` via `@AppStorage` so they survive
/// relaunches without us writing a plist by hand.
@MainActor
final class Preferences: ObservableObject {

    static let shared = Preferences()

    // MARK: - Hotkeys

    @AppStorage("hotkey.region")     var regionHotkey: KeyCombo = .defaultRegion
    @AppStorage("hotkey.fullScreen") var fullScreenHotkey: KeyCombo = .defaultFullScreen
    @AppStorage("hotkey.window")     var windowHotkey: KeyCombo = .defaultWindow

    // MARK: - Destination

    @AppStorage("destination.default") var defaultDestination: DefaultDestination = .thumbnail
    @AppStorage("destination.override") var overrideModifierRaw: OverrideModifier = .option

    var overrideModifier: NSEvent.ModifierFlags? { overrideModifierRaw.flags }

    // MARK: - Thumbnail

    @AppStorage("thumbnail.autoDismissSeconds") var autoDismissSeconds: Double = 6

    // MARK: - Save directory

    /// Stored as a security-scoped bookmark so we can write to user-chosen
    /// folders even after relaunch (and without entitlements).
    @AppStorage("save.directoryBookmark") private var saveDirectoryBookmark: Data?

    var defaultSaveDirectoryURL: URL? {
        get {
            guard let data = saveDirectoryBookmark else {
                return defaultPicturesURL()
            }
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                return url
            }
            return defaultPicturesURL()
        }
        set {
            guard let url = newValue else {
                saveDirectoryBookmark = nil
                return
            }
            if let data = try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) {
                saveDirectoryBookmark = data
            }
        }
    }

    private func defaultPicturesURL() -> URL? {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
    }
}
