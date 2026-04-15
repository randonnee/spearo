import Carbon.HIToolbox
import SwiftUI

struct HotkeyRecorderButton: View {
    enum RecorderMode {
        case hotkey(onRecord: (UInt32, UInt32, [UInt32]) -> Void)
        case modifiers(onRecord: (UInt32, [UInt32]) -> Void)
    }

    let displayString: String
    @Binding var isRecording: Bool
    let mode: RecorderMode

    @State private var liveDisplayString: String = ""

    init(
        displayString: String,
        isRecording: Binding<Bool>,
        onRecord: @escaping (UInt32, UInt32, [UInt32]) -> Void
    ) {
        self.displayString = displayString
        self._isRecording = isRecording
        self.mode = .hotkey(onRecord: onRecord)
    }

    init(
        displayString: String,
        isRecording: Binding<Bool>,
        onRecord: @escaping (UInt32, [UInt32]) -> Void
    ) {
        self.displayString = displayString
        self._isRecording = isRecording
        self.mode = .modifiers(onRecord: onRecord)
    }

    var body: some View {
        if isRecording {
            HStack(spacing: 4) {
                if !liveDisplayString.isEmpty {
                    Text(liveDisplayString)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color(nsColor: .labelColor))
                } else {
                    Text(recordingPrompt)
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
            .background(HotkeyRecorderEventView(
                isRecording: $isRecording,
                mode: mode,
                onLiveDisplay: { liveDisplayString = $0 }
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
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.7), lineWidth: 1)
            )
        }
    }

    private var recordingPrompt: String {
        switch mode {
        case .hotkey:
            return "Type shortcut..."
        case .modifiers:
            return "Press modifiers, then release..."
        }
    }
}

// MARK: - NSView that captures key events for recording

struct HotkeyRecorderEventView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let mode: HotkeyRecorderButton.RecorderMode
    var onLiveDisplay: ((String) -> Void)?

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        configure(view)
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        configure(nsView)
    }

    private func configure(_ view: HotkeyRecorderNSView) {
        switch mode {
        case let .hotkey(onRecord):
            view.onRecordHotkey = { keyCode, modifiers, order in
                onRecord(keyCode, modifiers, order)
                isRecording = false
            }
            view.onRecordModifiers = nil

        case let .modifiers(onRecord):
            view.onRecordHotkey = nil
            view.onRecordModifiers = { modifiers, order in
                onRecord(modifiers, order)
                isRecording = false
            }
        }

        view.onCancel = {
            isRecording = false
        }
        view.onLiveDisplay = onLiveDisplay

        if isRecording {
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
        }
    }
}

final class HotkeyRecorderNSView: NSView {
    var onRecordHotkey: ((UInt32, UInt32, [UInt32]) -> Void)?
    var onRecordModifiers: ((UInt32, [UInt32]) -> Void)?
    var onCancel: (() -> Void)?
    var onLiveDisplay: ((String) -> Void)?

    private var peakModifiers: UInt32 = 0
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

        // Require at least one modifier (Ctrl, Opt, Shift, or Cmd)
        let mods = carbonModifiers(from: event.modifierFlags)
        if mods == 0 {
            NSSound.beep()
            return
        }

        let order = currentModifierOrder(for: mods)
        resetModifierTracking()

        if onRecordModifiers != nil {
            onRecordModifiers?(mods, order)
            return
        }

        onRecordHotkey?(UInt32(event.keyCode), mods, order)
    }

    override func flagsChanged(with event: NSEvent) {
        let currentMods = carbonModifiers(from: event.modifierFlags)

        for (flag, _) in Self.modifierLabels {
            if currentMods & flag != 0 && !orderedModifiers.contains(flag) {
                orderedModifiers.append(flag)
            }
        }

        if currentMods != 0 {
            peakModifiers |= currentMods
            onLiveDisplay?(orderedModifierDisplayString(orderedModifiers))
            return
        }

        guard peakModifiers != 0, onRecordModifiers != nil else { return }

        let result = peakModifiers
        let order = currentModifierOrder(for: result)
        resetModifierTracking()
        onRecordModifiers?(result, order)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }

        let mods = carbonModifiers(from: event.modifierFlags)
        guard mods != 0 else {
            return super.performKeyEquivalent(with: event)
        }

        let order = currentModifierOrder(for: mods)
        resetModifierTracking()

        if onRecordModifiers != nil {
            onRecordModifiers?(mods, order)
        } else {
            onRecordHotkey?(UInt32(event.keyCode), mods, order)
        }

        return true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    private func currentModifierOrder(for modifiers: UInt32) -> [UInt32] {
        let filtered = orderedModifiers.filter { modifiers & $0 != 0 }
        return filtered.isEmpty ? HotkeySettings.defaultOrder(for: modifiers) : filtered
    }

    private func resetModifierTracking() {
        peakModifiers = 0
        orderedModifiers = []
        onLiveDisplay?("")
    }
}
