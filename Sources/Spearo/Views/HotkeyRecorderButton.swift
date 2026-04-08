import Carbon.HIToolbox
import SwiftUI

struct HotkeyRecorderButton: View {
    let displayString: String
    @Binding var isRecording: Bool
    let onRecord: (UInt32, UInt32) -> Void

    var body: some View {
        if isRecording {
            HStack(spacing: 4) {
                Text("Type shortcut...")
                    .font(.system(size: 12))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
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

final class HotkeyRecorderNSView: NSView {
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
