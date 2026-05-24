import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var windowManager: WindowManager!
    private var viewModel: LauncherViewModel!
    private var hotkeyManager: HotkeyManager?
    private var folderWatcher: AppFolderWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // .regular keeps a Dock icon so the user can right-click → Options →
        // Keep in Dock. The custom launcher panel still works the same.
        NSApp.setActivationPolicy(.regular)

        viewModel = LauncherViewModel()
        windowManager = WindowManager(viewModel: viewModel)

        hotkeyManager = HotkeyManager { [weak self] in
            self?.windowManager.toggle()
        }
        hotkeyManager?.register()

        buildStatusBar()
        viewModel.rescan()

        // FSEvents watcher: auto-rescan when /Applications, /System/Applications,
        // or ~/Applications change (install / uninstall / rename).
        folderWatcher = AppFolderWatcher(paths: AppScanner.watchPaths) { [weak self] in
            self?.viewModel.rescan()
        }
        folderWatcher?.start()

        // Launching the app from Dock / Finder / Spotlight should immediately
        // open the launcher panel — otherwise the user needs a second action
        // (menu bar or hotkey) just to see anything.
        windowManager.show()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        windowManager.show()
        return true
    }

    // MARK: - Menu bar

    private func buildStatusBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "square.grid.3x3.fill",
                                   accessibilityDescription: "aLaunchpad")
        }

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open aLaunchpad",
                                  action: #selector(openLauncher),
                                  keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let rescanItem = NSMenuItem(title: "Rescan Applications",
                                    action: #selector(rescan),
                                    keyEquivalent: "r")
        rescanItem.target = self
        menu.addItem(rescanItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit aLaunchpad",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    @objc private func openLauncher() {
        windowManager.show()
    }

    @objc private func rescan() {
        viewModel.rescan()
    }
}
