import AppKit
import SwiftUI

/// Owns the borderless launcher panel and its show/hide lifecycle.
@MainActor
final class WindowManager {
    private var panel: LauncherPanel?
    private let viewModel: LauncherViewModel
    private var escMonitor: Any?
    private var outsideClickMonitor: Any?
    private var scrollMonitor: Any?
    private var swipeAccumX: CGFloat = 0
    private var swipeInFlight: Bool = false

    init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
    }

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = ensurePanel()
        guard let screen = NSScreen.main else { return }

        // Centered 90% of the workspace (visibleFrame already respects the
        // menu bar and Dock). With the larger icon grid we no longer need to
        // fill the screen — a floating panel reads better.
        let visible = screen.visibleFrame
        let width = (visible.width * 0.9).rounded()
        let height = (visible.height * 0.9).rounded()
        let originX = visible.origin.x + ((visible.width - width) / 2).rounded()
        let originY = visible.origin.y + ((visible.height - height) / 2).rounded()
        panel.setFrame(NSRect(x: originX, y: originY, width: width, height: height),
                       display: true)

        viewModel.resetTransientState()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installEscMonitor()
        installOutsideClickMonitor()
        installScrollMonitor()
    }

    func hide() {
        panel?.orderOut(nil)
        removeEscMonitor()
        removeOutsideClickMonitor()
        removeScrollMonitor()
    }

    // MARK: - Panel

    private func ensurePanel() -> LauncherPanel {
        if let panel { return panel }

        let style: NSWindow.StyleMask = [.borderless, .nonactivatingPanel]
        let panel = LauncherPanel(contentRect: .zero,
                                  styleMask: style,
                                  backing: .buffered,
                                  defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true               // shadow now hugs the rounded shape
        panel.titleVisibility = .hidden
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow

        let root = ContentView(viewModel: viewModel) { [weak self] in
            self?.hide()
        }
        panel.contentView = NSHostingView(rootView: root)
        self.panel = panel
        return panel
    }

    // MARK: - Esc key handling

    private func installEscMonitor() {
        removeEscMonitor()
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isVisible == true else { return event }
            switch event.keyCode {
            case 53: // Escape
                self.hide()
                return nil
            case 125: // Down
                self.viewModel.selectDown()
                return nil
            case 126: // Up
                self.viewModel.selectUp()
                return nil
            case 124: // Right
                if event.modifierFlags.contains(.command) {
                    self.viewModel.nextPage()
                } else {
                    self.viewModel.selectRight()
                }
                return nil
            case 123: // Left
                if event.modifierFlags.contains(.command) {
                    self.viewModel.prevPage()
                } else {
                    self.viewModel.selectLeft()
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removeEscMonitor() {
        if let m = escMonitor {
            NSEvent.removeMonitor(m)
            escMonitor = nil
        }
    }

    // MARK: - Outside-click dismissal

    /// Global monitors fire ONLY for events outside this app, so any click in
    /// another app / the desktop / the Dock triggers a hide. Clicks inside
    /// the launcher go through the local Esc monitor + SwiftUI gestures.
    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.hide()
        }
    }

    private func removeOutsideClickMonitor() {
        if let m = outsideClickMonitor {
            NSEvent.removeMonitor(m)
            outsideClickMonitor = nil
        }
    }

    // MARK: - Two-finger swipe paging

    /// Trackpad two-finger horizontal swipe → page navigation. We accumulate
    /// `scrollingDeltaX` across the gesture and fire ONE page change per
    /// distinct swipe (gated by `swipeInFlight`) so a long flick doesn't blow
    /// through several pages.
    private func installScrollMonitor() {
        removeScrollMonitor()
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.panel?.isVisible == true else { return event }

            // Ignore regular mouse-wheel scrolls — only handle trackpad/Magic
            // Mouse precise deltas to avoid hijacking vertical scroll for users
            // on a discrete wheel.
            guard event.hasPreciseScrollingDeltas else { return event }

            // Skip if this is mostly a vertical scroll (we don't want a small
            // horizontal jitter on a vertical swipe to flip pages).
            if abs(event.scrollingDeltaY) > abs(event.scrollingDeltaX) * 1.5 {
                return event
            }

            switch event.phase {
            case .began:
                self.swipeAccumX = 0
                self.swipeInFlight = false
            case .changed:
                self.swipeAccumX += event.scrollingDeltaX
                let threshold: CGFloat = 50
                if !self.swipeInFlight {
                    if self.swipeAccumX <= -threshold {
                        self.viewModel.nextPage()
                        self.swipeInFlight = true
                    } else if self.swipeAccumX >= threshold {
                        self.viewModel.prevPage()
                        self.swipeInFlight = true
                    }
                }
            case .ended, .cancelled:
                self.swipeAccumX = 0
                self.swipeInFlight = false
            default:
                break
            }
            // Always swallow precise horizontal-ish scrolls so they don't leak
            // into any underlying scroll view.
            return nil
        }
    }

    private func removeScrollMonitor() {
        if let m = scrollMonitor {
            NSEvent.removeMonitor(m)
            scrollMonitor = nil
        }
        swipeAccumX = 0
        swipeInFlight = false
    }
}

/// NSPanel subclass that can take key focus despite being borderless.
final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
