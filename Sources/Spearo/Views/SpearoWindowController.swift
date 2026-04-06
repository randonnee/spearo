import AppKit
import SwiftUI

// MARK: - Environment key for dialog dismissal

private struct DialogCloseKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var dialogClose: () -> Void {
        get { self[DialogCloseKey.self] }
        set { self[DialogCloseKey.self] = newValue }
    }
}

enum DialogPage {
    case slots
    case settings
}

class DialogNavigation: ObservableObject {
    @Published var page: DialogPage = .slots
}

struct SpearoRootView: View {
    @ObservedObject var manager: SpearoManager
    @ObservedObject var hotkeySettings: HotkeySettings
    @ObservedObject var navigation: DialogNavigation
    var onClose: () -> Void

    var body: some View {
        Group {
            switch navigation.page {
            case .slots:
                SpearoDialogView(
                    manager: manager,
                    onSettings: { navigation.page = .settings }
                )
            case .settings:
                SettingsView(settings: hotkeySettings)
            }
        }
        .environment(\.dialogClose, onClose)
    }
}

// NSPanel subclass that can become key window despite being borderless
class SpearoPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

class SpearoWindowController: NSWindowController {
    private var onClose: (() -> Void)?
    private var manager: SpearoManager
    private var eventMonitor: Any?
    private var workspaceObserver: Any?
    private var isDismissing = false
    private var previousApp: NSRunningApplication?
    let navigation = DialogNavigation()

    init(manager: SpearoManager, onClose: @escaping () -> Void) {
        self.manager = manager
        self.onClose = onClose
        self.previousApp = NSWorkspace.shared.frontmostApplication

        // Borderless, transparent panel — Spotlight style
        let panel = SpearoPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 0),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false

        // Vibrancy background view
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 14
        visualEffect.layer?.masksToBounds = true

        panel.contentView = visualEffect

        super.init(window: panel)

        // Wire up the root view that switches between slots and settings
        let contentView = SpearoRootView(
            manager: manager,
            hotkeySettings: HotkeySettings.shared,
            navigation: navigation,
            onClose: { [weak self] in
                self?.dismiss()
            }
        )
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        visualEffect.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])

        panel.delegate = self

        // Center horizontally, upper third of screen (like Spotlight)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelWidth: CGFloat = 560
            let x = screenFrame.midX - panelWidth / 2
            let y = screenFrame.maxY - screenFrame.height * 0.3
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Dismiss when clicking outside the panel
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.dismiss()
        }

        // Dismiss when frontmost app changes
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.dismiss()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func dismiss() {
        guard !isDismissing else { return }
        isDismissing = true

        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        window?.orderOut(nil)

        // Restore focus to the app that was active before the dialog opened
        if let app = previousApp, !app.isTerminated {
            app.activate()
        }

        let callback = onClose
        onClose = nil
        callback?()
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}

extension SpearoWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        dismiss()
    }
}
