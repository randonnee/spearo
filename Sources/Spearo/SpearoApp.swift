import SwiftUI

@main
struct SpearoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Menu bar only — no main window.
        // Settings are accessible inside the Spearo dialog (Cmd+,).
    }
}
