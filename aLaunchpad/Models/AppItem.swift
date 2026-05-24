import Foundation
import AppKit

/// Lightweight, value-typed model for a discovered macOS application.
struct AppItem: Identifiable, Hashable {
    let id: String                // stable key: bundle ID, or absolute path if missing
    let name: String
    let bundleIdentifier: String?
    let url: URL
    let searchTokens: SearchTokens
    /// File system creation date — used for "Date Added" sort.
    let dateAdded: Date?

    static func makeID(bundleID: String?, url: URL) -> String {
        if let b = bundleID, !b.isEmpty { return b }
        return url.standardizedFileURL.path
    }
}
