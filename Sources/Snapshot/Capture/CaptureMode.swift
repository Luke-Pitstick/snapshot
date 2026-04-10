import Foundation

/// Which kind of screen capture to perform.
enum CaptureMode: String, CaseIterable, Identifiable {
    case region
    case fullScreen
    case window

    var id: String { rawValue }

    var title: String {
        switch self {
        case .region:     return "Capture Region"
        case .fullScreen: return "Capture Full Screen"
        case .window:     return "Capture Window"
        }
    }
}
