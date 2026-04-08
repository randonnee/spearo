import SwiftUI

@main
struct SpearoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var hotkeySettings = HotkeySettings.shared

    var body: some Scene {
        // SwiftUI still requires a scene even though the app is menu-bar only.
        Settings {
            SettingsView(settings: hotkeySettings)
                .frame(width: 460)
                .padding(.vertical, 8)
        }
    }
}
