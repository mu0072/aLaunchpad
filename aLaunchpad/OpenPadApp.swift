import SwiftUI

@main
struct OpenPadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // App is driven by AppDelegate (menu bar + custom NSPanel).
        Settings { EmptyView() }
    }
}
