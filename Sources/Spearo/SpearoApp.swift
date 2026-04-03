import SwiftUI

@main
struct SpearoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use a menu bar app pattern — no main window
        Settings {
            EmptyView()
        }
    }
}
