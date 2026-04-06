import SwiftUI

@main
struct SpearoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // SwiftUI still requires a scene even though the app is menu-bar only.
        Settings {
            EmptyView()
        }
    }
}
