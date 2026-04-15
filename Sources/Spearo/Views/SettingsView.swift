import Carbon.HIToolbox
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: HotkeySettings
    @StateObject private var launchAtLogin = LaunchAtLoginManager.shared
    @State private var isRecordingDialog = false
    @State private var isRecordingAddApp = false
    @State private var isRecordingModifier = false
    @State private var recordingSlotIndex: Int? = nil

    private var isAnyRecording: Bool {
        isRecordingDialog || isRecordingAddApp || isRecordingModifier || recordingSlotIndex != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Dialog hotkey
            settingsRow(label: "Open Dialog") {
                HotkeyRecorderButton(
                    displayString: settings.displayString,
                    isRecording: Binding(
                        get: { isRecordingDialog },
                        set: { isRecordingDialog = $0 }
                    ),
                    onRecord: { keyCode, modifiers, order in
                        settings.update(keyCode: keyCode, modifiers: modifiers, order: order)
                    }
                )
            }

            Spacer().frame(height: 6)

            // Add App hotkey
            settingsRow(label: "Add App") {
                HotkeyRecorderButton(
                    displayString: settings.addAppDisplayString,
                    isRecording: $isRecordingAddApp,
                    onRecord: { keyCode, modifiers, order in
                        settings.updateAddApp(keyCode: keyCode, modifiers: modifiers, order: order)
                    }
                )
            }

            Spacer().frame(height: 6)

            settingsRow(label: "Start at Login") {
                Toggle("", isOn: Binding(
                    get: { launchAtLogin.isEnabled },
                    set: { launchAtLogin.setEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }

            if launchAtLogin.requiresApproval || launchAtLogin.errorMessage != nil {
                Spacer().frame(height: 4)
                startupStatusRow
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
                    HotkeyRecorderButton(
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
        }
        .background(Color.clear)
        .padding(.vertical, 8)
        .onAppear { launchAtLogin.refreshStatus() }
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
                onRecord: { keyCode, modifiers, order in
                    settings.updateCustomBinding(index: index, keyCode: keyCode, modifiers: modifiers, order: order)
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

    private var startupStatusRow: some View {
        Text(startupStatusText)
            .font(.system(size: 11))
            .foregroundColor(Color(nsColor: .secondaryLabelColor))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.horizontal, 8)
    }

    private var startupStatusText: String {
        if let errorMessage = launchAtLogin.errorMessage {
            return errorMessage
        }

        if launchAtLogin.requiresApproval {
            return "Startup is enabled, but macOS still needs approval in Login Items."
        }

        return ""
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
}
