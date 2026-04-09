import SwiftUI
import AppKit
import Carbon.HIToolbox

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyManager: HotkeyManager!
    private var spearoManager: SpearoManager!
    private var spearoWindowController: SpearoWindowController?
    private var settingsWindowController: SettingsWindowController?
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
        }

        // Re-register the add-app hotkey when settings change
        hotkeySettings.onAddAppChanged = { [weak self] in
            self?.registerAddAppHotkey()
        }

        // Re-register slot hotkeys when slot settings change
        hotkeySettings.onSlotHotkeysChanged = { [weak self] in
            self?.registerSlotHotkeys()
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
        menu.delegate = self
        statusItem.menu = menu
    }

    private func setupHotkeys() {
        // Slot hotkeys (F1-F12, Modifier+Number, or custom)
        registerSlotHotkeys()

        // Configurable add-app hotkey
        registerAddAppHotkey()

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

    private func registerAddAppHotkey() {
        hotkeyManager.register(
            name: "addApp",
            keyCode: hotkeySettings.addAppKeyCode,
            modifiers: hotkeySettings.addAppModifiers
        ) { [weak self] in
            self?.addCurrentApp()
        }
    }

    private func switchSlot(_ index: Int) {
        // Dismiss the dialog first so it doesn't fight for focus
        dismissDialog()
        spearoManager.switchToSlot(index)
    }

    @objc private func addCurrentApp() {
        spearoManager.addCurrentApp()
    }

    @objc private func openSpearoDialog() {
        if spearoWindowController != nil {
            dismissDialog()
            return
        }
        spearoWindowController = makeDialogController()
    }

    @objc private func openSettings() {
        if let controller = settingsWindowController {
            controller.showWindow(nil)
            controller.window?.makeKeyAndOrderFront(nil)
        } else {
            settingsWindowController = SettingsWindowController(
                settings: hotkeySettings,
                onClose: { [weak self] in
                    self?.settingsWindowController = nil
                }
            )
            settingsWindowController?.showWindow(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func dismissDialog() {
        guard let controller = spearoWindowController else { return }
        spearoWindowController = nil
        controller.dismiss()
    }

    private func makeDialogController() -> SpearoWindowController {
        SpearoWindowController(
            manager: spearoManager,
            onClose: { [weak self] in
                self?.spearoWindowController = nil
            }
        )
    }

}

private final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var onClose: (() -> Void)?

    init(settings: HotkeySettings, onClose: @escaping () -> Void) {
        self.onClose = onClose

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 320),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.center()

        let contentView = SettingsView(settings: settings)
            .frame(width: 460)
            .padding(.vertical, 8)
        window.contentView = NSHostingView(rootView: contentView)

        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        let callback = onClose
        onClose = nil
        callback?()
    }
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        menu.addItem(NSMenuItem(title: "Spearo", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let addLabel = "Add Current App (\(hotkeySettings.addAppDisplayString))"
        let addItem = NSMenuItem(title: addLabel, action: #selector(addCurrentApp), keyEquivalent: "")
        addItem.target = self
        menu.addItem(addItem)

        let dialogLabel = "Open Spearo (\(hotkeySettings.displayString))"
        let dialogItem = NSMenuItem(title: dialogLabel, action: #selector(openSpearoDialog), keyEquivalent: "")
        dialogItem.target = self
        menu.addItem(dialogItem)

        menu.addItem(NSMenuItem.separator())

        for i in 0..<spearoManager.visibleSlotCount {
            let slot = spearoManager.slots[i]
            let appLabel = slot != nil ? slot!.name : "(empty)"
            let hotkeyLabel = hotkeySettings.slotLabel(i)
            let item = NSMenuItem(title: "\(hotkeyLabel): \(appLabel)", action: nil, keyEquivalent: "")
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(title: "Quit Spearo", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)
    }
}
