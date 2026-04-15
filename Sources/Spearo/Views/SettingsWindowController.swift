import SwiftUI
import AppKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private var onClose: (() -> Void)?

    init(settings: HotkeySettings, onClose: @escaping () -> Void) {
        self.onClose = onClose

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 380),
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
