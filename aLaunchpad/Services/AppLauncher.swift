import AppKit

enum AppLauncher {
    /// Async wrapper around NSWorkspace's openApplication.
    static func launch(_ item: AppItem) async throws {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        _ = try await NSWorkspace.shared.openApplication(at: item.url,
                                                         configuration: config)
    }
}
