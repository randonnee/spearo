import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: HotkeySettings
    @State private var isRecording = false
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

            // Hotkey row
            HStack {
                Text("Open Dialog")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                HotkeyRecorderButton(
                    keyCode: settings.keyCode,
                    modifiers: settings.modifiers,
                    isRecording: $isRecording,
                    onRecord: { keyCode, modifiers in
                        settings.update(keyCode: keyCode, modifiers: modifiers)
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.06))
            )
            .padding(.horizontal, 8)

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
            if key == "\u{1B}" && !isRecording { // Escape
                onBack()
                return true
            }
            return false
        }))
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
    let keyCode: UInt32
    let modifiers: UInt32
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
                Text(HotkeySettings.shared.displayString)
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
            // Ignore bare key presses — need a modifier
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
