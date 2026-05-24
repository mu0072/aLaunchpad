import AppKit
import Carbon.HIToolbox

/// Registers a global Option+Space hotkey via the Carbon HotKey API.
/// Falls back silently if registration fails (caller still gets the menu bar item).
final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let callback: () -> Void
    private let hotKeyID = EventHotKeyID(signature: OSType(0x4F504144), id: 1) // 'OPAD'

    init(callback: @escaping () -> Void) {
        self.callback = callback
    }

    func register() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let installStatus = InstallEventHandler(GetApplicationEventTarget(),
                                                hotkeyHandler,
                                                1,
                                                &spec,
                                                selfPtr,
                                                &eventHandler)
        guard installStatus == noErr else { return }

        // Option(⌥) + Space — keyCode 49.
        let modifiers: UInt32 = UInt32(optionKey)
        RegisterEventHotKey(UInt32(kVK_Space),
                            modifiers,
                            hotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &hotKeyRef)
    }

    fileprivate func fire() {
        DispatchQueue.main.async { [weak self] in
            self?.callback()
        }
    }

    deinit {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let handler = eventHandler { RemoveEventHandler(handler) }
    }
}

private func hotkeyHandler(_ nextHandler: EventHandlerCallRef?,
                           _ event: EventRef?,
                           _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let userData = userData else { return noErr }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    manager.fire()
    return noErr
}
