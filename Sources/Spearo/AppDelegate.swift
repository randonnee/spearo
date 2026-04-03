import SwiftUI
import AppKit
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager!
    private var spearoManager: SpearoManager!
    private var spearoWindowController: SpearoWindowController?
    private let hotkeySettings = HotkeySettings.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

        // Ensure we have a bundle identifier (needed when running outside .app bundle)
        if Bundle.main.bundleIdentifier == nil {
            let defaults = UserDefaults.standard
            defaults.set("com.spearo.app", forKey: "CFBundleIdentifier")
        }

        spearoManager = SpearoManager.shared
        hotkeyManager = HotkeyManager()

        setupMenuBar()
        setupHotkeys()

        // Re-register the dialog hotkey when settings change
        hotkeySettings.onChange = { [weak self] in
            self?.registerDialogHotkey()
            self?.refreshMenu()
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.trianglehead.swap", accessibilityDescription: "Spearo")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Spearo", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let addItem = NSMenuItem(title: "Add Current App (Ctrl+Shift+A)", action: #selector(addCurrentApp), keyEquivalent: "")
        addItem.target = self
        menu.addItem(addItem)

        let dialogLabel = "Open Spearo (\(hotkeySettings.displayString))"
        let dialogItem = NSMenuItem(title: dialogLabel, action: #selector(openSpearoDialog), keyEquivalent: "")
        dialogItem.target = self
        menu.addItem(dialogItem)

        menu.addItem(NSMenuItem.separator())

        // Show current assignments
        for i in 0..<spearoManager.visibleSlotCount {
            let slot = spearoManager.slots[i]
            let label = slot != nil ? slot!.name : "(empty)"
            let item = NSMenuItem(title: "F\(i + 1): \(label)", action: nil, keyEquivalent: "")
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit Spearo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func refreshMenu() {
        setupMenuBar()
    }

    private func setupHotkeys() {
        // F1-F12 for app switching
        let fKeys: [Int] = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
            kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12
        ]
        for (index, keyCode) in fKeys.enumerated() {
            let slotIndex = index
            hotkeyManager.register(keyCode: UInt32(keyCode), modifiers: 0) { [weak self] in
                self?.switchSlot(slotIndex)
            }
        }

        // Ctrl+Shift+A to add current app
        let ctrlShift: UInt32 = UInt32(controlKey | shiftKey)
        hotkeyManager.register(keyCode: UInt32(kVK_ANSI_A), modifiers: ctrlShift) { [weak self] in
            self?.addCurrentApp()
        }

        // Configurable dialog hotkey
        registerDialogHotkey()
    }

    private func registerDialogHotkey() {
        hotkeyManager.register(
            name: "openDialog",
            keyCode: hotkeySettings.keyCode,
            modifiers: hotkeySettings.modifiers
        ) { [weak self] in
            self?.openSpearoDialog()
        }
    }

    private func switchSlot(_ index: Int) {
        // Dismiss the dialog first so it doesn't fight for focus
        dismissDialog()
        spearoManager.switchToSlot(index)
    }

    @objc private func addCurrentApp() {
        spearoManager.addCurrentApp()
        refreshMenu()
    }

    @objc private func openSpearoDialog() {
        if spearoWindowController != nil {
            dismissDialog()
            return
        }
        spearoWindowController = SpearoWindowController(manager: spearoManager) { [weak self] in
            self?.refreshMenu()
            self?.spearoWindowController = nil
        }
    }

    private func dismissDialog() {
        guard let controller = spearoWindowController else { return }
        spearoWindowController = nil
        controller.dismiss()
    }
}
