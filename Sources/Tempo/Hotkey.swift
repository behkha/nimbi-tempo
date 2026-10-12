import AppKit
import Carbon

/// ⌃⌥P from any app: start or pause. A Carbon hot key, so it needs no Accessibility permission,
/// bound to the physical key (DESIGN.md 2.6).
@MainActor
final class Hotkey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(keyCode: UInt32 = UInt32(kVK_ANSI_P), modifiers: UInt32 = UInt32(controlKey | optionKey), action: @escaping () -> Void) {
        self.action = action
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, data in
            guard let data else { return noErr }
            let hotkey = Unmanaged<Hotkey>.fromOpaque(data).takeUnretainedValue()
            DispatchQueue.main.async { hotkey.action() }
            return noErr
        }, 1, &type, me, &handler)
        let id = EventHotKeyID(signature: OSType(0x544D_504F), id: 1)   // 'TMPO'
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref)
    }

    static let label = "⌃⌥P"
}
