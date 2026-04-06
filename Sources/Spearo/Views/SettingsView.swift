import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: HotkeySettings
    @State private var isRecordingDialog = false
    @State private var isRecordingModifier = false
    @State private var recordingSlotIndex: Int? = nil
    var onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
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

            // Slot hotkey mode
            settingsRow(label: "Slot Hotkeys") {
                modePicker
            }

            // Modifier recorder for modifierNumber mode
            if settings.slotMode == .modifierNumber {
                Spacer().frame(height: 6)
                settingsRow(label: "Modifier") {
                    ModifierRecorderButton(
                        displayString: modifierDisplayString(settings.slotModifier),
                        isRecording: $isRecordingModifier,
                        onRecord: { modifiers in
                            settings.updateSlotModifier(modifiers)
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
                hintLabel("esc", "back")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(Color.clear)
        .background(KeyEventHandlingView(onKeyDown: { event in
            let key = event.charactersIgnoringModifiers ?? ""
            if key == "\u{1B}" && !isRecordingDialog && !isRecordingModifier && recordingSlotIndex == nil {
                onBack()
                return true
            }
            return false
        }))
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
                .foregroundColor(settings.slotMode == mode ? .white : .white.opacity(0.5))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(settings.slotMode == mode ? Color.accentColor.opacity(0.5) : Color.white.opacity(0.08))
        )
    }

    // MARK: - Custom bindings list

    private var customBindingsList: some View {
        VStack(spacing: 2) {
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
                .foregroundColor(.white.opacity(0.6))
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
                        .foregroundColor(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Shared components

    private func settingsRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
        )
        .padding(.horizontal, 8)
    }

    private func hintLabel(_ key: String, _ action: String) -> some View {
        HStack(spacing: 3) {
            Text(key)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.1))
                .cornerRadius(3)
            Text(action)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))
        }
    }
}

// MARK: - Hotkey Recorder Button

struct HotkeyRecorderButton: View {
    let displayString: String
    @Binding var isRecording: Bool
    let onRecord: (UInt32, UInt32) -> Void

    var body: some View {
        if isRecording {
            HStack(spacing: 4) {
                Text("Type shortcut...")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
            .background(HotkeyRecorderEventView(
                isRecording: $isRecording,
                onRecord: onRecord
            ))
        } else {
            Button {
                isRecording = true
            } label: {
                Text(displayString)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
}

// MARK: - NSView that captures key events for recording

struct HotkeyRecorderEventView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onRecord: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onRecord = { keyCode, modifiers in
            onRecord(keyCode, modifiers)
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.onRecord = { keyCode, modifiers in
            onRecord(keyCode, modifiers)
            isRecording = false
        }
        nsView.onCancel = {
            isRecording = false
        }
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

class HotkeyRecorderNSView: NSView {
    var onRecord: ((UInt32, UInt32) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Escape cancels recording
        if event.keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        // Require at least one modifier (Ctrl, Opt, Shift, or Cmd)
        let mods = carbonModifiers(from: event.modifierFlags)
        if mods == 0 {
            NSSound.beep()
            return
        }

        onRecord?(UInt32(event.keyCode), mods)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}

// MARK: - Modifier Recorder Button

struct ModifierRecorderButton: View {
    let displayString: String
    @Binding var isRecording: Bool
    let onRecord: (UInt32) -> Void

    var body: some View {
        if isRecording {
            HStack(spacing: 4) {
                Text("Press modifier + key...")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            )
            .background(ModifierRecorderEventView(
                isRecording: $isRecording,
                onRecord: onRecord
            ))
        } else {
            Button {
                isRecording = true
            } label: {
                Text(displayString)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
}

// MARK: - NSView that captures modifier keys for recording

struct ModifierRecorderEventView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onRecord: (UInt32) -> Void

    func makeNSView(context: Context) -> ModifierRecorderNSView {
        let view = ModifierRecorderNSView()
        view.onRecord = { modifiers in
            onRecord(modifiers)
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: ModifierRecorderNSView, context: Context) {
        nsView.onRecord = { modifiers in
            onRecord(modifiers)
            isRecording = false
        }
        nsView.onCancel = {
            isRecording = false
        }
        if isRecording {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

class ModifierRecorderNSView: NSView {
    var onRecord: ((UInt32) -> Void)?
    var onCancel: (() -> Void)?

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
        onRecord?(mods)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Intercept Cmd-key combos before AppKit routes them
        if event.modifierFlags.contains(.command) {
            let mods = carbonModifiers(from: event.modifierFlags)
            if mods != 0 {
                onRecord?(mods)
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
