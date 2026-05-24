import Foundation

/// Scans the well-known macOS application folders for `.app` bundles.
enum AppScanner {
    static var searchRoots: [URL] {
        let fm = FileManager.default
        return [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]
    }

    /// Filesystem paths the folder watcher should observe.
    static var watchPaths: [String] {
        searchRoots.map { $0.path }
    }

    /// Scan on a background priority and return a name-sorted, deduped list.
    static func scan() async -> [AppItem] {
        await Task.detached(priority: .userInitiated) {
            var seen = Set<String>()
            var items: [AppItem] = []
            for root in searchRoots {
                for url in enumerateApps(at: root) {
                    let bundle = Bundle(url: url)
                    let bundleID = bundle?.bundleIdentifier
                    let id = AppItem.makeID(bundleID: bundleID, url: url)
                    if !seen.insert(id).inserted { continue }
                    let name = displayName(for: url, bundle: bundle)
                    let dateAdded = creationDate(for: url)
                    items.append(AppItem(id: id,
                                         name: name,
                                         bundleIdentifier: bundleID,
                                         url: url,
                                         searchTokens: SearchTokens.build(from: name),
                                         dateAdded: dateAdded))
                }
            }
            // Default order is alphabetical; the VM re-sorts based on user choice.
            items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return items
        }.value
    }

    private static func creationDate(for url: URL) -> Date? {
        let values = try? url.resourceValues(forKeys: [.creationDateKey,
                                                       .contentModificationDateKey])
        return values?.creationDate ?? values?.contentModificationDate
    }

    private static func enumerateApps(at root: URL) -> [URL] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path) else { return [] }
        var results: [URL] = []
        let keys: [URLResourceKey] = [.isDirectoryKey]
        guard let enumerator = fm.enumerator(at: root,
                                             includingPropertiesForKeys: keys,
                                             options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return []
        }
        while let url = enumerator.nextObject() as? URL {
            if url.pathExtension == "app" {
                results.append(url)
                // .app is itself a package; don't recurse into it
                enumerator.skipDescendants()
            }
        }
        return results
    }

    private static func displayName(for url: URL, bundle: Bundle?) -> String {
        if let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !name.isEmpty {
            return name
        }
        if let name = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.isEmpty {
            return name
        }
        return url.deletingPathExtension().lastPathComponent
    }
}
