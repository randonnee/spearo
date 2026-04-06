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

        // Re-register slot hotkeys when slot settings change
        hotkeySettings.onSlotHotkeysChanged = { [weak self] in
            self?.registerSlotHotkeys()
            self?.refreshMenu()
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if let svgURL = Bundle.module.url(forResource: "spear-tip", withExtension: "svg"),
               let icon = NSImage(contentsOf: svgURL) {
                icon.isTemplate = true
                icon.size = NSSize(width: 18, height: 18)
                button.image = icon
            }
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

        // Show current assignments with correct hotkey labels
        for i in 0..<spearoManager.visibleSlotCount {
            let slot = spearoManager.slots[i]
            let appLabel = slot != nil ? slot!.name : "(empty)"
            let hotkeyLabel = hotkeySettings.slotLabel(i)
            let item = NSMenuItem(title: "\(hotkeyLabel): \(appLabel)", action: nil, keyEquivalent: "")
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit Spearo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func refreshMenu() {
        setupMenuBar()
    }

    private func setupHotkeys() {
        // Slot hotkeys (F1-F12, Modifier+Number, or custom)
        registerSlotHotkeys()

        // Ctrl+Shift+A to add current app
        let ctrlShift: UInt32 = UInt32(controlKey | shiftKey)
        hotkeyManager.register(name: "addApp", keyCode: UInt32(kVK_ANSI_A), modifiers: ctrlShift) { [weak self] in
            self?.addCurrentApp()
        }

        // Configurable dialog hotkey
        registerDialogHotkey()
    }

    private func registerSlotHotkeys() {
        // Unregister all existing slot hotkeys
        hotkeyManager.unregisterAll(prefix: "slot.")

        // Register based on current mode
        for i in 0..<12 {
            guard let binding = hotkeySettings.bindingForSlot(i) else { continue }
            let slotIndex = i
            hotkeyManager.register(
                name: "slot.\(i)",
                keyCode: binding.keyCode,
                modifiers: binding.modifiers
            ) { [weak self] in
                self?.switchSlot(slotIndex)
            }
        }
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

    @objc private func openSettings() {
        if let controller = spearoWindowController {
            controller.navigation.page = .settings
        } else {
            spearoWindowController = SpearoWindowController(manager: spearoManager) { [weak self] in
                self?.refreshMenu()
                self?.spearoWindowController = nil
            }
            spearoWindowController?.navigation.page = .settings
        }
    }

    private func dismissDialog() {
        guard let controller = spearoWindowController else { return }
        spearoWindowController = nil
        controller.dismiss()
    }
}
