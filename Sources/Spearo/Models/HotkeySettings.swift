import AppKit
import Carbon.HIToolbox
import Foundation

/// Persisted settings for the configurable dialog-open hotkey.
class HotkeySettings: ObservableObject {
    static let shared = HotkeySettings()

    private let keyCodeKey = "spearo.dialogHotkey.keyCode"
    private let modifiersKey = "spearo.dialogHotkey.modifiers"

    /// Carbon virtual key code (e.g. kVK_ANSI_D = 0x02)
    @Published var keyCode: UInt32 {
        didSet { save() }
    }

    /// Carbon modifier mask (e.g. controlKey | shiftKey)
    @Published var modifiers: UInt32 {
        didSet { save() }
    }

    /// Called after the hotkey is changed so the app delegate can re-register.
    var onChange: (() -> Void)?

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: keyCodeKey) != nil {
            keyCode = UInt32(defaults.integer(forKey: keyCodeKey))
            modifiers = UInt32(defaults.integer(forKey: modifiersKey))
        } else {
            // Default: Ctrl+Shift+D
            keyCode = UInt32(kVK_ANSI_D)
            modifiers = UInt32(controlKey | shiftKey)
        }
    }

    func update(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        onChange?()
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: keyCodeKey)
        defaults.set(Int(modifiers), forKey: modifiersKey)
    }

    // MARK: - Display helpers

    /// Human-readable label like "Ctrl+Shift+D"
    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("Ctrl") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("Opt") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("Shift") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("Cmd") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined(separator: "+")
    }
}

// MARK: - Key code to string mapping

func keyCodeToString(_ keyCode: UInt32) -> String {
    let map: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
        UInt32(kVK_Space): "Space", UInt32(kVK_Return): "Return",
        UInt32(kVK_Tab): "Tab", UInt32(kVK_Escape): "Esc",
        UInt32(kVK_ANSI_Minus): "-", UInt32(kVK_ANSI_Equal): "=",
        UInt32(kVK_ANSI_LeftBracket): "[", UInt32(kVK_ANSI_RightBracket): "]",
        UInt32(kVK_ANSI_Backslash): "\\", UInt32(kVK_ANSI_Semicolon): ";",
        UInt32(kVK_ANSI_Quote): "'", UInt32(kVK_ANSI_Comma): ",",
        UInt32(kVK_ANSI_Period): ".", UInt32(kVK_ANSI_Slash): "/",
        UInt32(kVK_ANSI_Grave): "`",
    ]
    return map[keyCode] ?? "Key(\(keyCode))"
}

/// Convert NSEvent modifier flags to Carbon modifier mask.
func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var mods: UInt32 = 0
    if flags.contains(.control) { mods |= UInt32(controlKey) }
    if flags.contains(.option) { mods |= UInt32(optionKey) }
    if flags.contains(.shift) { mods |= UInt32(shiftKey) }
    if flags.contains(.command) { mods |= UInt32(cmdKey) }
    return mods
}
