import Carbon.HIToolbox
import Cocoa

class HotkeyManager {
    private var hotkeys: [EventHotKeyRef?] = []
    private var handlers: [UInt32: () -> Void] = [:]
    private var nextID: UInt32 = 1

    private static var instance: HotkeyManager?

    init() {
        HotkeyManager.instance = self
        installEventHandler()
    }

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
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

        if status == noErr {
            hotkeys.append(hotkeyRef)
            handlers[id] = handler
        } else {
            print("Failed to register hotkey (keyCode: \(keyCode), modifiers: \(modifiers)): \(status)")
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
        for hotkey in hotkeys {
            if let ref = hotkey {
                UnregisterEventHotKey(ref)
            }
        }
    }
}
