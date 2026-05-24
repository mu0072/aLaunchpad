import Foundation
import CoreServices

/// Watches the macOS application folders via FSEvents and fires `onChange`
/// (on the main actor) when their contents change.
///
/// The FSEventStream's own `latency: 1.0` already coalesces bursts (e.g. the
/// many small writes that happen as a `.app` is dragged in or expanded from
/// a dmg) into a single callback per ~1 s, so no application-side debouncing
/// is needed on top.
@MainActor
final class AppFolderWatcher {
    private let paths: [String]
    private let onChange: @MainActor () -> Void
    private var stream: FSEventStreamRef?

    init(paths: [String], onChange: @escaping @MainActor () -> Void) {
        self.paths = paths
        self.onChange = onChange
    }

    deinit {
        // Tear down the stream directly — can't hop actors from deinit.
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }

    func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        // Directory-level events are enough — installing/removing a .app
        // creates or deletes a top-level directory under the watched root.
        let flags: FSEventStreamCreateFlags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes
        )

        guard let s = FSEventStreamCreate(
            kCFAllocatorDefault,
            fsEventsCallback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // latency seconds — natural coalescing window
            flags
        ) else {
            return
        }

        FSEventStreamSetDispatchQueue(s, .main)
        FSEventStreamStart(s)
        self.stream = s
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    /// Called from the C trampoline below. Already on the main queue because
    /// `FSEventStreamSetDispatchQueue(s, .main)` is set above.
    fileprivate nonisolated func handleEvent() {
        Task { @MainActor [weak self] in
            self?.onChange()
        }
    }
}

// FSEventStream's C callback can't capture context the Swift way, so we route
// through this trampoline and read the watcher out of `info` (set in start()).
private let fsEventsCallback: FSEventStreamCallback = {
    _, info, _, _, _, _ in
    guard let info else { return }
    let watcher = Unmanaged<AppFolderWatcher>.fromOpaque(info).takeUnretainedValue()
    watcher.handleEvent()
}
