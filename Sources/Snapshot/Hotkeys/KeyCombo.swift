import AppKit
import Carbon.HIToolbox

/// A keyboard shortcut: a key plus a set of modifier flags.
///
/// Stored as `keyCode` (virtual key code — e.g. `kVK_ANSI_4` = 21) and
/// `modifiers` (the subset of `NSEvent.ModifierFlags` the user pressed).
/// Persisted via `UserDefaults` by going through the `rawValue` string
/// (`"modifiers:keyCode"`), which makes it trivially `@AppStorage`-compatible.
struct KeyCombo: Equatable, Hashable, Codable, RawRepresentable {

    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        // Only keep the meaningful chord modifiers; strip out device flags.
        self.modifiers = modifiers.intersection([.command, .option, .control, .shift])
    }

    // MARK: - RawRepresentable (for @AppStorage)

    var rawValue: String {
        "\(modifiers.rawValue):\(keyCode)"
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ":")
        guard parts.count == 2,
              let mods = UInt(parts[0]),
              let code = UInt32(parts[1]) else { return nil }
        self.keyCode = code
        self.modifiers = NSEvent.ModifierFlags(rawValue: mods)
            .intersection([.command, .option, .control, .shift])
    }

    // MARK: - Carbon bridge

    /// Translate `NSEvent.ModifierFlags` into the Carbon modifier mask used by
    /// `RegisterEventHotKey`.
    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        if modifiers.contains(.command) { m |= UInt32(cmdKey) }
        if modifiers.contains(.option)  { m |= UInt32(optionKey) }
        if modifiers.contains(.control) { m |= UInt32(controlKey) }
        if modifiers.contains(.shift)   { m |= UInt32(shiftKey) }
        return m
    }

    // MARK: - Display

    /// Human-readable form like "⌘⇧4" for menus and preference rows.
    var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        s += Self.keyName(for: keyCode)
        return s
    }

    /// Map a virtual key code to its printable name. Covers the common ANSI
    /// keys plus function keys and a handful of named keys; anything unknown
    /// falls back to `"Key \(keyCode)"`.
    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Grave: return "`"
        default: return "Key \(keyCode)"
        }
    }

    // MARK: - Defaults

    static let defaultRegion = KeyCombo(
        keyCode: UInt32(kVK_ANSI_4),
        modifiers: [.command, .control, .shift]
    )
    static let defaultFullScreen = KeyCombo(
        keyCode: UInt32(kVK_ANSI_3),
        modifiers: [.command, .control, .shift]
    )
    static let defaultWindow = KeyCombo(
        keyCode: UInt32(kVK_ANSI_5),
        modifiers: [.command, .control, .shift]
    )
}
