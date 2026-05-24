import AppKit

/// In-memory NSImage cache keyed by app URL path.
/// NSWorkspace already caches at the system level, but holding strong refs in
/// SwiftUI avoids repeated allocations as views recycle during scrolling.
@MainActor
enum IconCache {
    private static var store: [String: NSImage] = [:]

    static func icon(for url: URL, size: CGFloat = 72) -> NSImage {
        let key = url.path
        if let cached = store[key] { return cached }
        let image = NSWorkspace.shared.icon(forFile: key)
        image.size = NSSize(width: size, height: size)
        store[key] = image
        return image
    }

    static func purge() {
        store.removeAll()
    }
}
