import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: HotkeySettings
    @Environment(\.dismiss) private var dismiss
    @State private var isRecordingDialog = false
    @State private var isRecordingAddApp = false
    @State private var isRecordingModifier = false
    @State private var recordingSlotIndex: Int? = nil

    private var isAnyRecording: Bool {
        isRecordingDialog || isRecordingAddApp || isRecordingModifier || recordingSlotIndex != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(nsColor: .labelColor))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Dialog hotkey
            settingsRow(label: "Open Dialog") {
                HotkeyRecorderButton(
                    displayString: settings.displayString,
                    isRecording: Binding(
                        get: { isRecordingDialog },
                        set: { isRecordingDialog = $0 }
                    ),
                    onRecord: { keyCode, modifiers in
                        settings.update(keyCode: keyCode, modifiers: modifiers)
                    }
                )
            }

            Spacer().frame(height: 6)

            // Add App hotkey
            settingsRow(label: "Add App") {
                HotkeyRecorderButton(
                    displayString: settings.addAppDisplayString,
                    isRecording: $isRecordingAddApp,
                    onRecord: { keyCode, modifiers in
                        settings.updateAddApp(keyCode: keyCode, modifiers: modifiers)
                    }
                )
            }

            Spacer().frame(height: 6)

            // Slot hotkey mode
            settingsRow(label: "Slot Hotkeys") {
                modePicker
            }

            // Modifier recorder for modifierNumber mode
            if settings.slotMode == .modifierNumber {
                Spacer().frame(height: 6)
                settingsRow(label: "Modifier") {
                    ModifierRecorderButton(
                        displayString: settings.slotModifierDisplayString,
                        isRecording: $isRecordingModifier,
                        onRecord: { modifiers, order in
                            settings.updateSlotModifier(modifiers, order: order)
                        }
                    )
                }
            }

            // Per-slot custom bindings
            if settings.slotMode == .custom {
                Spacer().frame(height: 8)
                customBindingsList
            }

            Spacer().frame(height: 16)

            // Hint bar
            HStack(spacing: 16) {
                hintLabel("esc", "close")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(Color.clear)
        .background(KeyEventHandlingView(isActive: !isAnyRecording, onKeyDown: { event in
            let key = event.charactersIgnoringModifiers ?? ""
            if key == "\u{1B}" && !isRecordingDialog && !isRecordingAddApp && !isRecordingModifier && recordingSlotIndex == nil {
                dismiss()
                return true
            }
            return false
        }))
        .onChange(of: isRecordingDialog) { HotkeyManager.setSuspended(isAnyRecording) }
        .onChange(of: isRecordingAddApp) { HotkeyManager.setSuspended(isAnyRecording) }
        .onChange(of: isRecordingModifier) { HotkeyManager.setSuspended(isAnyRecording) }
        .onChange(of: recordingSlotIndex) { HotkeyManager.setSuspended(isAnyRecording) }
        .onDisappear { HotkeyManager.setSuspended(false) }
    }

    // MARK: - Mode picker

    private var modePicker: some View {
        HStack(spacing: 4) {
            modeButton("F-Keys", mode: .fKeys)
            modeButton("Mod+Num", mode: .modifierNumber)
            modeButton("Custom", mode: .custom)
        }
    }

    private func modeButton(_ label: String, mode: SlotHotkeyMode) -> some View {
        Button {
            settings.updateSlotMode(mode)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(settings.slotMode == mode ? .white : Color(nsColor: .secondaryLabelColor))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(settings.slotMode == mode ? Color.accentColor.opacity(0.85) : Color(nsColor: .controlBackgroundColor).opacity(0.95))
        )
    }

    // MARK: - Custom bindings list

    private let customBindingsColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    private var customBindingsList: some View {
        LazyVGrid(columns: customBindingsColumns, spacing: 8) {
            ForEach(0..<12, id: \.self) { index in
                customSlotRow(index: index)
            }
        }
        .padding(.horizontal, 8)
    }

    private func customSlotRow(index: Int) -> some View {
        HStack {
            Text("Slot \(index + 1)")
                .font(.system(size: 12))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                .frame(width: 50, alignment: .leading)

            Spacer()

            HotkeyRecorderButton(
                displayString: settings.customBindings[index]?.displayString ?? "Unset",
                isRecording: Binding(
                    get: { recordingSlotIndex == index },
                    set: { newVal in recordingSlotIndex = newVal ? index : nil }
                ),
                onRecord: { keyCode, modifiers in
                    settings.updateCustomBinding(index: index, keyCode: keyCode, modifiers: modifiers)
                }
            )

            if settings.customBindings[index] != nil {
                Button {
                    settings.clearCustomBinding(index: index)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.8))
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: - Shared components

    private func settingsRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(Color(nsColor: .secondaryLabelColor))
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
        )
        .padding(.horizontal, 8)
    }

    private func hintLabel(_ key: String, _ action: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Color(nsColor: .labelColor))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.9))
                .cornerRadius(3)
            Text(action)
                .font(.system(size: 10))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
        }
    }
}

// MARK: - Modifier Recorder Button

struct ModifierRecorderButton: View {
    let displayString: String
    @Binding var isRecording: Bool
    let onRecord: (UInt32, [UInt32]) -> Void

    @State private var liveDisplayString: String = ""

    var body: some View {
        if isRecording {
            HStack(spacing: 4) {
                if !liveDisplayString.isEmpty {
                    Text(liveDisplayString)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color(nsColor: .labelColor))
                } else {
                    Text("Press modifiers, then release...")
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
            .background(ModifierRecorderEventView(
                isRecording: $isRecording,
                onRecord: onRecord,
                onLiveDisplay: { display in
                    liveDisplayString = display
                }
            ))
            .onDisappear {
                liveDisplayString = ""
            }
        } else {
            Button {
                liveDisplayString = ""
                isRecording = true
            } label: {
                Text(displayString)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(nsColor: .labelColor))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.95))
            )
        }
    }
}

// MARK: - NSView that captures modifier keys for recording

struct ModifierRecorderEventView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onRecord: (UInt32, [UInt32]) -> Void
    var onLiveDisplay: ((String) -> Void)?

    func makeNSView(context: Context) -> ModifierRecorderNSView {
        let view = ModifierRecorderNSView()
        view.onRecord = { modifiers, order in
            onRecord(modifiers, order)
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        view.onLiveDisplay = onLiveDisplay
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: ModifierRecorderNSView, context: Context) {
        nsView.onRecord = { modifiers, order in
            onRecord(modifiers, order)
            isRecording = false
        }
        nsView.onCancel = {
            isRecording = false
        }
        nsView.onLiveDisplay = onLiveDisplay
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

class ModifierRecorderNSView: NSView {
    var onRecord: ((UInt32, [UInt32]) -> Void)?
    var onCancel: (() -> Void)?
    var onLiveDisplay: ((String) -> Void)?

    // Track the peak modifier combination while keys are held
    private var peakModifiers: UInt32 = 0
    // Track the order modifiers are pressed for display
    private var orderedModifiers: [UInt32] = []

    private static let modifierLabels: [(flag: UInt32, label: String)] = [
        (UInt32(controlKey), "Ctrl"),
        (UInt32(optionKey), "Opt"),
        (UInt32(shiftKey), "Shift"),
        (UInt32(cmdKey), "Cmd"),
    ]

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Escape cancels recording
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        // Require at least one modifier
        let mods = carbonModifiers(from: event.modifierFlags)
        if mods == 0 {
            NSSound.beep()
            return
        }

        // Record just the modifiers (ignore which key was pressed)
        let order = orderedModifiers
        peakModifiers = 0
        orderedModifiers = []
        onRecord?(mods, order.isEmpty ? HotkeySettings.defaultOrder(for: mods) : order)
    }

    override func flagsChanged(with event: NSEvent) {
        let currentMods = carbonModifiers(from: event.modifierFlags)

        // Detect newly pressed modifiers and append them in press order
        for (flag, _) in Self.modifierLabels {
            if currentMods & flag != 0 && !orderedModifiers.contains(flag) {
                orderedModifiers.append(flag)
            }
        }

        if currentMods != 0 {
            // Still holding modifier(s) — accumulate into peak and update live display
            peakModifiers |= currentMods
            let display = orderedModifiers.compactMap { flag in
                Self.modifierLabels.first(where: { $0.flag == flag })?.label
            }.joined(separator: "+")
            onLiveDisplay?(display)
        } else if peakModifiers != 0 {
            // All modifiers released — record the full combination with press order
            let result = peakModifiers
            let order = orderedModifiers
            peakModifiers = 0
            orderedModifiers = []
            onRecord?(result, order)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Intercept Cmd-key combos before AppKit routes them
        if event.modifierFlags.contains(.command) {
            let mods = carbonModifiers(from: event.modifierFlags)
            if mods != 0 {
                let order = orderedModifiers
                peakModifiers = 0
                orderedModifiers = []
                onRecord?(mods, order.isEmpty ? HotkeySettings.defaultOrder(for: mods) : order)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}
