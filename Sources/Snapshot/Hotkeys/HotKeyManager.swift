import AppKit
import Carbon.HIToolbox

/// Registers global hotkeys with Carbon's `RegisterEventHotKey`, which works
/// without Accessibility permission and consumes the keystroke so it doesn't
/// leak to the focused app.
///
/// Thread-safety: all mutation happens on the main thread. The C callback
/// bounces straight back to main before invoking the stored handler.
final class HotKeyManager {

    /// Logical slot for each kind of hotkey. Lets callers re-register a
    /// particular binding without touching the others.
    enum Slot: UInt32, CaseIterable {
        case region = 1
        case fullScreen = 2
        case window = 3
    }

    // MARK: - Storage

    private struct Registration {
        let ref: EventHotKeyRef
        let handler: () -> Void
    }

    private var registrations: [UInt32: Registration] = [:]
    private var eventHandlerRef: EventHandlerRef?

    // Singleton so the Carbon C callback can find us without an `unsafeBitCast`
    // dance through `userData`.
    static let shared = HotKeyManager()

    private init() {
        installCarbonHandler()
    }

    // MARK: - Public API

    /// Register (or re-register) the hotkey for a given slot. Returns `false`
    /// if Carbon refused the binding — typically because another app has
    /// already claimed it (`eventHotKeyExistsErr`).
    @discardableResult
    func register(_ slot: Slot, combo: KeyCombo, handler: @escaping () -> Void) -> Bool {
        unregister(slot)

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: OSType(0x534E_4150), // 'SNAP'
            id: slot.rawValue
        )
        let status = RegisterEventHotKey(
            combo.keyCode,
            combo.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            return false
        }
        registrations[slot.rawValue] = Registration(ref: ref, handler: handler)
        return true
    }

    func unregister(_ slot: Slot) {
        guard let reg = registrations.removeValue(forKey: slot.rawValue) else { return }
        UnregisterEventHotKey(reg.ref)
    }

    func unregisterAll() {
        for slot in Slot.allCases { unregister(slot) }
    }

    // MARK: - Carbon plumbing

    private func installCarbonHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                guard let event else { return noErr }
                var id = EventHotKeyID()
                let err = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &id
                )
                guard err == noErr else { return err }
                DispatchQueue.main.async {
                    HotKeyManager.shared.registrations[id.id]?.handler()
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )
    }
}
