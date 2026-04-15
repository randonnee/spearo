import AppKit
import Carbon.HIToolbox
import Foundation

// MARK: - Slot hotkey mode

enum SlotHotkeyMode: String, Codable, CaseIterable {
    case fKeys          // F1-F12 (no modifiers)
    case modifierNumber // Modifier+1 through Modifier+0 (+ - =) for 12 slots
    case custom         // User-defined per-slot hotkey
}

/// A single key binding: key code + modifier mask.
struct KeyBinding: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var modifierOrder: [UInt32]? = nil

    var displayString: String {
        var parts = orderedModifierLabels(modifierOrder, fallbackModifiers: modifiers)
        parts.append(keyCodeToString(keyCode))
        return parts.joined(separator: "+")
    }
}

/// Persisted settings for all configurable hotkeys.
class HotkeySettings: ObservableObject {
    static let shared = HotkeySettings()

    // MARK: - Dialog hotkey

    private let dialogKeyCodeKey = "spearo.dialogHotkey.keyCode"
    private let dialogModifiersKey = "spearo.dialogHotkey.modifiers"
    private let dialogModifierOrderKey = "spearo.dialogHotkey.modifierOrder"

    @Published var keyCode: UInt32 {
        didSet { saveDialog() }
    }

    @Published var modifiers: UInt32 {
        didSet { saveDialog() }
    }

    @Published var dialogModifierOrder: [UInt32] {
        didSet { saveDialog() }
    }

    // MARK: - Add App hotkey

    private let addAppKeyCodeKey = "spearo.addAppHotkey.keyCode"
    private let addAppModifiersKey = "spearo.addAppHotkey.modifiers"
    private let addAppModifierOrderKey = "spearo.addAppHotkey.modifierOrder"

    @Published var addAppKeyCode: UInt32 {
        didSet { saveAddApp() }
    }

    @Published var addAppModifiers: UInt32 {
        didSet { saveAddApp() }
    }

    @Published var addAppModifierOrder: [UInt32] {
        didSet { saveAddApp() }
    }

    // MARK: - Slot hotkey mode

    private let slotModeKey = "spearo.slotHotkeyMode"
    private let slotModifierKey = "spearo.slotModifier"
    private let slotModifierOrderKey = "spearo.slotModifierOrder"
    private let slotCustomBindingsKey = "spearo.slotCustomBindings"

    @Published var slotMode: SlotHotkeyMode {
        didSet { saveSlotSettings() }
    }

    /// Modifier mask used in .modifierNumber mode (default: Ctrl)
    @Published var slotModifier: UInt32 {
        didSet { saveSlotSettings() }
    }

    /// Ordered modifier flags for display (preserves user press order)
    @Published var slotModifierOrder: [UInt32] {
        didSet { saveSlotSettings() }
    }

    /// Per-slot custom key bindings (12 entries, nil = unbound)
    @Published var customBindings: [KeyBinding?] {
        didSet { saveSlotSettings() }
    }

    // MARK: - Callbacks

    /// Called after the dialog hotkey is changed.
    var onChange: (() -> Void)?

    /// Called after the add-app hotkey is changed.
    var onAddAppChanged: (() -> Void)?

    /// Called after slot hotkey configuration changes.
    var onSlotHotkeysChanged: (() -> Void)?

    /// Derive an ordered modifier list from a bitmask in canonical order.
    static func defaultOrder(for mods: UInt32) -> [UInt32] {
        let all: [UInt32] = [UInt32(controlKey), UInt32(optionKey), UInt32(shiftKey), UInt32(cmdKey)]
        return all.filter { mods & $0 != 0 }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        // Dialog hotkey
        let loadedDialogKeyCode: UInt32
        let loadedDialogModifiers: UInt32
        if defaults.object(forKey: dialogKeyCodeKey) != nil {
            loadedDialogKeyCode = UInt32(defaults.integer(forKey: dialogKeyCodeKey))
            loadedDialogModifiers = UInt32(defaults.integer(forKey: dialogModifiersKey))
        } else {
            loadedDialogKeyCode = UInt32(kVK_ANSI_D)
            loadedDialogModifiers = UInt32(controlKey | shiftKey)
        }
        keyCode = loadedDialogKeyCode
        modifiers = loadedDialogModifiers
        if let orderData = defaults.array(forKey: dialogModifierOrderKey) as? [Int] {
            dialogModifierOrder = orderData.map { UInt32($0) }
        } else {
            dialogModifierOrder = Self.defaultOrder(for: loadedDialogModifiers)
        }

        // Add App hotkey
        let loadedAddAppKeyCode: UInt32
        let loadedAddAppModifiers: UInt32
        if defaults.object(forKey: addAppKeyCodeKey) != nil {
            loadedAddAppKeyCode = UInt32(defaults.integer(forKey: addAppKeyCodeKey))
            loadedAddAppModifiers = UInt32(defaults.integer(forKey: addAppModifiersKey))
        } else {
            loadedAddAppKeyCode = UInt32(kVK_ANSI_A)
            loadedAddAppModifiers = UInt32(controlKey | shiftKey)
        }
        addAppKeyCode = loadedAddAppKeyCode
        addAppModifiers = loadedAddAppModifiers
        if let orderData = defaults.array(forKey: addAppModifierOrderKey) as? [Int] {
            addAppModifierOrder = orderData.map { UInt32($0) }
        } else {
            addAppModifierOrder = Self.defaultOrder(for: loadedAddAppModifiers)
        }

        // Slot mode
        if let raw = defaults.string(forKey: slotModeKey),
           let mode = SlotHotkeyMode(rawValue: raw) {
            slotMode = mode
        } else {
            slotMode = .fKeys
        }

        // Slot modifier for modifierNumber mode
        let loadedModifier: UInt32
        if defaults.object(forKey: slotModifierKey) != nil {
            loadedModifier = UInt32(defaults.integer(forKey: slotModifierKey))
        } else {
            loadedModifier = UInt32(controlKey)
        }
        slotModifier = loadedModifier

        // Slot modifier order (press order)
        if let orderData = defaults.array(forKey: slotModifierOrderKey) as? [Int] {
            slotModifierOrder = orderData.map { UInt32($0) }
        } else {
            // Derive from slotModifier in canonical order as fallback
            slotModifierOrder = Self.defaultOrder(for: loadedModifier)
        }

        // Custom bindings
        if let data = defaults.data(forKey: slotCustomBindingsKey),
           let decoded = try? JSONDecoder().decode([KeyBinding?].self, from: data) {
            customBindings = decoded
            while customBindings.count < 12 { customBindings.append(nil) }
        } else {
            customBindings = Array(repeating: nil, count: 12)
        }
    }

    // MARK: - Dialog hotkey

    func update(keyCode: UInt32, modifiers: UInt32, order: [UInt32]? = nil) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        dialogModifierOrder = order ?? Self.defaultOrder(for: modifiers)
        onChange?()
    }

    var displayString: String {
        KeyBinding(keyCode: keyCode, modifiers: modifiers, modifierOrder: dialogModifierOrder).displayString
    }

    private func saveDialog() {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: dialogKeyCodeKey)
        defaults.set(Int(modifiers), forKey: dialogModifiersKey)
        defaults.set(dialogModifierOrder.map { Int($0) }, forKey: dialogModifierOrderKey)
    }

    // MARK: - Add App hotkey

    func updateAddApp(keyCode: UInt32, modifiers: UInt32, order: [UInt32]? = nil) {
        self.addAppKeyCode = keyCode
        self.addAppModifiers = modifiers
        addAppModifierOrder = order ?? Self.defaultOrder(for: modifiers)
        onAddAppChanged?()
    }

    var addAppDisplayString: String {
        KeyBinding(keyCode: addAppKeyCode, modifiers: addAppModifiers, modifierOrder: addAppModifierOrder).displayString
    }

    private func saveAddApp() {
        let defaults = UserDefaults.standard
        defaults.set(Int(addAppKeyCode), forKey: addAppKeyCodeKey)
        defaults.set(Int(addAppModifiers), forKey: addAppModifiersKey)
        defaults.set(addAppModifierOrder.map { Int($0) }, forKey: addAppModifierOrderKey)
    }

    // MARK: - Slot hotkey settings

    func updateSlotMode(_ mode: SlotHotkeyMode) {
        slotMode = mode
        onSlotHotkeysChanged?()
    }

    func updateSlotModifier(_ modifier: UInt32, order: [UInt32]) {
        slotModifier = modifier
        slotModifierOrder = order
        onSlotHotkeysChanged?()
    }

    /// Display string for the slot modifier, using preserved press order.
    var slotModifierDisplayString: String {
        orderedModifierDisplayString(slotModifierOrder)
    }

    func updateCustomBinding(index: Int, keyCode: UInt32, modifiers: UInt32, order: [UInt32]? = nil) {
        guard index >= 0, index < 12 else { return }
        customBindings[index] = KeyBinding(
            keyCode: keyCode,
            modifiers: modifiers,
            modifierOrder: order ?? Self.defaultOrder(for: modifiers)
        )
        onSlotHotkeysChanged?()
    }

    func clearCustomBinding(index: Int) {
        guard index >= 0, index < 12 else { return }
        customBindings[index] = nil
        onSlotHotkeysChanged?()
    }

    private func saveSlotSettings() {
        let defaults = UserDefaults.standard
        defaults.set(slotMode.rawValue, forKey: slotModeKey)
        defaults.set(Int(slotModifier), forKey: slotModifierKey)
        defaults.set(slotModifierOrder.map { Int($0) }, forKey: slotModifierOrderKey)
        if let data = try? JSONEncoder().encode(customBindings) {
            defaults.set(data, forKey: slotCustomBindingsKey)
        }
    }

    // MARK: - Computed bindings for each slot

    /// Returns the key binding for a given slot index (0-11) based on the current mode.
    func bindingForSlot(_ index: Int) -> KeyBinding? {
        switch slotMode {
        case .fKeys:
            let fKeys: [Int] = [
                kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
                kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12
            ]
            guard index >= 0, index < fKeys.count else { return nil }
            return KeyBinding(keyCode: UInt32(fKeys[index]), modifiers: 0)

        case .modifierNumber:
            // 1-9, 0, -, = for slots 1-12
            let numberKeys: [Int] = [
                kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9, kVK_ANSI_0,
                kVK_ANSI_Minus, kVK_ANSI_Equal
            ]
            guard index >= 0, index < numberKeys.count else { return nil }
            return KeyBinding(keyCode: UInt32(numberKeys[index]), modifiers: slotModifier)

        case .custom:
            guard index >= 0, index < customBindings.count else { return nil }
            return customBindings[index]
        }
    }

    /// Short label for the slot badge in the dialog (e.g. "F1", "Ctrl+1", "Opt+A")
    func slotLabel(_ index: Int) -> String {
        if slotMode == .modifierNumber, let binding = bindingForSlot(index) {
            let modifierLabel = orderedModifierDisplayString(slotModifierOrder)
            return [modifierLabel, keyCodeToString(binding.keyCode)]
                .filter { !$0.isEmpty }
                .joined(separator: "+")
        }

        if let binding = bindingForSlot(index) {
            return binding.displayString
        }
        return "?"
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

/// Human-readable label for a Carbon modifier mask (canonical order).
func modifierDisplayString(_ mods: UInt32) -> String {
    var parts: [String] = []
    if mods & UInt32(controlKey) != 0 { parts.append("Ctrl") }
    if mods & UInt32(optionKey) != 0 { parts.append("Opt") }
    if mods & UInt32(shiftKey) != 0 { parts.append("Shift") }
    if mods & UInt32(cmdKey) != 0 { parts.append("Cmd") }
    return parts.joined(separator: "+")
}

/// Human-readable label for modifiers in a specific order.
func orderedModifierDisplayString(_ order: [UInt32]) -> String {
    orderedModifierLabels(order, fallbackModifiers: 0).joined(separator: "+")
}

func orderedModifierLabels(_ order: [UInt32]?, fallbackModifiers: UInt32) -> [String] {
    let normalizedOrder = {
        if let order, !order.isEmpty {
            return order
        }
        return HotkeySettings.defaultOrder(for: fallbackModifiers)
    }()

    let labels: [UInt32: String] = [
        UInt32(controlKey): "Ctrl",
        UInt32(optionKey): "Opt",
        UInt32(shiftKey): "Shift",
        UInt32(cmdKey): "Cmd",
    ]

    return normalizedOrder.compactMap { labels[$0] }
}
