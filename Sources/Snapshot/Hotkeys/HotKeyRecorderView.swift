import SwiftUI
import AppKit
import Carbon.HIToolbox

/// SwiftUI control that lets the user record a new hotkey combo.
///
/// When inactive it shows the current combo as `⌘⇧4`. Click it to enter
/// "record" mode — the next keyDown event becomes the new combo. Esc cancels.
struct HotKeyRecorderView: View {
    @Binding var combo: KeyCombo

    @State private var isRecording = false

    var body: some View {
        KeyRecorderRepresentable(combo: $combo, isRecording: $isRecording)
            .frame(width: 140, height: 24)
    }
}

private struct KeyRecorderRepresentable: NSViewRepresentable {
    @Binding var combo: KeyCombo
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> KeyRecorderNSView {
        let view = KeyRecorderNSView()
        view.onChange = { newCombo in
            combo = newCombo
            isRecording = false
        }
        view.onToggleRecording = { recording in
            isRecording = recording
        }
        view.combo = combo
        return view
    }

    func updateNSView(_ nsView: KeyRecorderNSView, context: Context) {
        nsView.combo = combo
        nsView.isRecordingExternally = isRecording
        nsView.needsDisplay = true
    }
}

/// NSView that toggles into "waiting for key" mode when clicked, then
/// captures the next keyDown and reports it via `onChange`. Esc cancels.
final class KeyRecorderNSView: NSView {

    var combo: KeyCombo = .defaultRegion { didSet { needsDisplay = true } }
    var onChange: ((KeyCombo) -> Void)?
    var onToggleRecording: ((Bool) -> Void)?

    var isRecordingExternally: Bool = false {
        didSet { needsDisplay = true }
    }
    private var isRecording: Bool = false {
        didSet {
            needsDisplay = true
            onToggleRecording?(isRecording)
            if isRecording { window?.makeFirstResponder(self) }
        }
    }

    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }

    override func mouseDown(with event: NSEvent) {
        isRecording.toggle()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        if Int(event.keyCode) == kVK_Escape {
            isRecording = false
            return
        }
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        // Require at least one modifier so users can't accidentally bind
        // plain "A" and lose it globally.
        guard !flags.isEmpty else {
            NSSound.beep()
            return
        }
        let newCombo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: flags)
        combo = newCombo
        isRecording = false
        onChange?(newCombo)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        let bg = NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.25)
                     : NSColor.controlBackgroundColor).setFill()
        bg.fill()

        (isRecording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        bg.lineWidth = 1
        bg.stroke()

        let text: String
        if isRecording {
            text = "Type shortcut…"
        } else {
            text = combo.displayString
        }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor
        ]
        let string = NSAttributedString(string: text, attributes: attrs)
        let size = string.size()
        let origin = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        string.draw(at: origin)
    }
}
