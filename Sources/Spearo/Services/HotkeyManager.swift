import Carbon.HIToolbox
import Cocoa

class HotkeyManager {
    private var hotkeys: [UInt32: EventHotKeyRef] = [:]
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1

    /// Map from a caller-defined name to the registered hotkey ID, for re-registration.
    private var namedHotkeys: [String: UInt32] = [:]

    private static var instance: HotkeyManager?

    init() {
        HotkeyManager.instance = self
        installEventHandler()
    }

    /// Register a hotkey. Returns the internal ID.
    @discardableResult
    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> UInt32 {
        let id = nextID
        nextID += 1

        let hotkeyID = EventHotKeyID(signature: OSType(0x5350_5245), id: id)
        var hotkeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status == noErr, let ref = hotkeyRef {
            hotkeys[id] = ref
            handlers[id] = handler
        } else {
            print("Failed to register hotkey (keyCode: \(keyCode), modifiers: \(modifiers)): \(status)")
        }

        return id
    }

    /// Register a hotkey with a name so it can be re-registered later.
    func register(name: String, keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        // Unregister previous binding for this name, if any
        unregister(name: name)

        let id = register(keyCode: keyCode, modifiers: modifiers, handler: handler)
        namedHotkeys[name] = id
    }

    /// Unregister a single named hotkey.
    func unregister(name: String) {
        if let oldID = namedHotkeys[name], let ref = hotkeys[oldID] {
            UnregisterEventHotKey(ref)
            hotkeys.removeValue(forKey: oldID)
            handlers.removeValue(forKey: oldID)
        }
        namedHotkeys.removeValue(forKey: name)
    }

    /// Unregister all named hotkeys whose name starts with the given prefix.
    func unregisterAll(prefix: String) {
        let matching = namedHotkeys.keys.filter { $0.hasPrefix(prefix) }
        for name in matching {
            unregister(name: name)
        }
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotkeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )
            guard status == noErr else { return status }

            DispatchQueue.main.async {
                HotkeyManager.instance?.handlers[hotkeyID.id]?()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handler,
            1,
            &eventType,
            nil,
            nil
        )
    }

    deinit {
        for (_, ref) in hotkeys {
            UnregisterEventHotKey(ref)
        }
    }
}
