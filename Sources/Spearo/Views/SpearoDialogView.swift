import SwiftUI

enum SelectMode {
    case none
    case visual    // v: range selection, j/k extends range, J/K shifts block
}

struct SpearoDialogView: View {
    @ObservedObject var manager: SpearoManager
    var onClose: () -> Void
    var onSettings: () -> Void

    @State private var selectedIndex: Int = 0
    @State private var commandBuffer: String = ""
    @State private var yankBuffer: SpearoSlot? = nil
    @State private var statusMessage: String? = nil
    @State private var selectMode: SelectMode = .none
    @State private var visualAnchor: Int = 0  // anchor index for V mode

    /// The contiguous range of selected indices
    private var selectedRange: ClosedRange<Int>? {
        switch selectMode {
        case .none:
            return nil
        case .visual:
            let lo = min(visualAnchor, selectedIndex)
            let hi = max(visualAnchor, selectedIndex)
            return lo...hi
        }
    }

    var body: some View {
        let visibleCount = manager.visibleSlotCount

        VStack(spacing: 0) {
            // Slot list
            VStack(spacing: 2) {
                ForEach(0..<visibleCount, id: \.self) { index in
                    SlotRow(
                        index: index,
                        slot: manager.slots[index],
                        isCursor: index == selectedIndex,
                        isInSelection: selectedRange?.contains(index) == true
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // Status / hint bar
            if let msg = statusMessage {
                Text(msg)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            } else if selectMode == .visual {
                HStack(spacing: 16) {
                    hintLabel("j/k", "select")
                    hintLabel("J/K", "shift")
                    hintLabel("d", "delete")
                    hintLabel("esc", "cancel")
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            } else {
                HStack(spacing: 16) {
                    hintLabel("j/k", "move")
                    hintLabel("d", "delete")
                    hintLabel("x", "cut")
                    hintLabel("p", "paste")
                    hintLabel("v", "select")
                    hintLabel("\u{23CE}", "switch")
                    hintLabel("\u{2318},", "settings")
                    hintLabel("esc", "close")
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .background(Color.clear)
        .background(KeyEventHandlingView(onKeyDown: handleKey))
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

    private func flashStatus(_ message: String) {
        statusMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            statusMessage = nil
        }
    }

    // MARK: - Selection movement

    /// Shift a contiguous block of slots by one position in the given direction.
    /// Returns the new cursor index after the shift.
    private func shiftSelection(direction: Int) {
        guard let range = selectedRange else { return }
        let lo = range.lowerBound
        let hi = range.upperBound
        let maxIndex = manager.visibleSlotCount - 1

        if direction < 0 && lo <= 0 { return }
        if direction > 0 && hi >= maxIndex { return }

        var newSlots = manager.slots
        if direction < 0 {
            // Shift block up: swap the slot above the block with each slot in the block
            let aboveIndex = lo - 1
            let above = newSlots[aboveIndex]
            for i in lo...hi {
                newSlots[i - 1] = newSlots[i]
            }
            newSlots[hi] = above
        } else {
            // Shift block down: swap the slot below the block with each slot in the block
            let belowIndex = hi + 1
            let below = newSlots[belowIndex]
            for i in stride(from: hi, through: lo, by: -1) {
                newSlots[i + 1] = newSlots[i]
            }
            newSlots[lo] = below
        }

        manager.setSlots(newSlots)

        selectedIndex += direction
        visualAnchor += direction
    }

    // MARK: - Key handling

    private func handleKey(_ event: NSEvent) -> Bool {
        let key = event.charactersIgnoringModifiers ?? ""
        let maxIndex = manager.visibleSlotCount - 1

        // Handle select mode keys first
        if selectMode != .none {
            switch key {
            case "j":
                commandBuffer = ""
                // Extend selection down
            if selectMode == .visual {
                selectedIndex = min(selectedIndex + 1, maxIndex)
            }
            return true

        case "k":
            commandBuffer = ""
            // Extend selection up
            if selectMode == .visual {
                selectedIndex = max(selectedIndex - 1, 0)
            }
                return true

            case "J":
                commandBuffer = ""
                shiftSelection(direction: 1)
                return true

            case "K":
                commandBuffer = ""
                shiftSelection(direction: -1)
                return true

            case "d", "\u{7F}": // d or delete/backspace
                commandBuffer = ""
                if let range = selectedRange {
                    let names = range.compactMap { manager.slots[$0]?.name }
                    for i in range {
                        manager.removeSlot(i)
                    }
                    selectMode = .none
                    selectedIndex = min(range.lowerBound, manager.visibleSlotCount - 1)
                    if !names.isEmpty {
                        flashStatus("Deleted \(names.joined(separator: ", "))")
                    }
                }
                return true

            case "\u{1B}", "v", "V": // Escape or toggle off
                commandBuffer = ""
                selectMode = .none
                return true

            default:
                return false
            }
        }

        // Normal mode
        switch key {
        case "j":
            commandBuffer = ""
            selectedIndex = min(selectedIndex + 1, maxIndex)
            return true

        case "k":
            commandBuffer = ""
            selectedIndex = max(selectedIndex - 1, 0)
            return true

        case "g":
            if commandBuffer == "g" {
                selectedIndex = 0
                commandBuffer = ""
            } else {
                commandBuffer = "g"
            }
            return true

        case "G":
            commandBuffer = ""
            selectedIndex = maxIndex
            return true

        case "v", "V":
            commandBuffer = ""
            visualAnchor = selectedIndex
            selectMode = .visual
            return true

        case "d":
            commandBuffer = ""
            let deleted = manager.slots[selectedIndex]
            manager.removeSlot(selectedIndex)
            if let d = deleted {
                flashStatus("Deleted \(d.name)")
            }
            return true

        case "y":
            if commandBuffer == "y" {
                yankBuffer = manager.slots[selectedIndex]
                commandBuffer = ""
                if let y = yankBuffer {
                    flashStatus("Yanked \(y.name)")
                }
            } else {
                commandBuffer = "y"
            }
            return true

        case "p":
            commandBuffer = ""
            if let yanked = yankBuffer {
                let current = manager.slots[selectedIndex]
                var newSlots = manager.slots
                newSlots[selectedIndex] = yanked
                manager.setSlots(newSlots)
                yankBuffer = current
                let label = HotkeySettings.shared.slotLabel(selectedIndex)
                flashStatus("Placed \(yanked.name) at \(label)")
            } else {
                flashStatus("Nothing to paste")
            }
            return true

        case "x":
            commandBuffer = ""
            let deleted = manager.slots[selectedIndex]
            yankBuffer = deleted
            manager.removeSlot(selectedIndex)
            if let d = deleted {
                flashStatus("Cut \(d.name)")
            }
            return true

        case "\r": // Enter
            commandBuffer = ""
            manager.switchToSlot(selectedIndex)
            onClose()
            return true

        case "\u{1B}": // Escape
            commandBuffer = ""
            onClose()
            return true

        case ",":
            if event.modifierFlags.contains(.command) {
                commandBuffer = ""
                onSettings()
                return true
            }
            return false

        default:
            if !key.isEmpty {
                commandBuffer = ""
            }
            return false
        }
    }
}

// MARK: - Slot Row

struct SlotRow: View {
    let index: Int
    let slot: SpearoSlot?
    let isCursor: Bool
    let isInSelection: Bool

    private var slotLabel: String {
        HotkeySettings.shared.slotLabel(index)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Hotkey badge
            Text(slotLabel)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(isCursor ? .white : .white.opacity(0.45))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 5)
                .frame(minWidth: 28, minHeight: 22, maxHeight: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isCursor ? Color.accentColor.opacity(0.6) : Color.white.opacity(0.08))
                )

            // App icon
            appIconView
                .frame(width: 28, height: 28)

            // App name
            Text(slot?.name ?? "Empty")
                .font(.system(size: 14, weight: slot != nil ? .medium : .regular))
                .foregroundColor(slot != nil ? .white.opacity(0.9) : .white.opacity(0.25))

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowBackground)
        )
        .contentShape(Rectangle())
    }

    private var rowBackground: Color {
        if isInSelection {
            return Color.accentColor.opacity(0.2)
        } else if isCursor {
            return Color.white.opacity(0.12)
        } else {
            return Color.clear
        }
    }

    @ViewBuilder
    private var appIconView: some View {
        if let slot = slot {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: slot.bundleIdentifier) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "app")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.4))
            }
        } else {
            Image(systemName: "circle.dashed")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.15))
        }
    }
}

// MARK: - Key Event Handler

struct KeyEventHandlingView: NSViewRepresentable {
    var isActive: Bool = true
    let onKeyDown: (NSEvent) -> Bool

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.onKeyDown = onKeyDown
        if isActive {
            DispatchQueue.main.async {
                view.window?.makeFirstResponder(view)
            }
        }
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.onKeyDown = onKeyDown
        if isActive {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

class KeyCaptureView: NSView {
    var onKeyDown: ((NSEvent) -> Bool)?

    override var acceptsFirstResponder: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Intercept Cmd-key shortcuts before AppKit routes them to menus
        if event.modifierFlags.contains(.command) {
            if onKeyDown?(event) == true {
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if onKeyDown?(event) != true {
            super.keyDown(with: event)
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}
