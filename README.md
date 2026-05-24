# aLaunchpad

> A fast, keyboard-first **macOS app launcher** — a hybrid of Launchpad and Spotlight with **pinyin search**, archive support, and **0% CPU when idle**. Pure Swift / SwiftUI / AppKit. No Electron, no dependencies.

[English](README.md) · [简体中文](README.zh-CN.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/macOS-13.0+-blue.svg)](#requirements)
[![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon%20%7C%20Intel-lightgrey.svg)](#requirements)
[![Release](https://img.shields.io/github/v/release/mu0072/aLaunchpad?include_prereleases)](https://github.com/mu0072/aLaunchpad/releases)
[![Stars](https://img.shields.io/github/stars/mu0072/aLaunchpad?style=social)](https://github.com/mu0072/aLaunchpad/stargazers)

A free, open-source alternative to Spotlight / Alfred / Raycast for users who just want a **classic Launchpad-style paged grid** with great keyboard support and Chinese pinyin search built in.

---

## Contents

- [Download](#download)
- [Quick Start](#quick-start)
- [Features](#features)
- [Keyboard & Mouse](#keyboard--mouse)
- [Build from Source](#build-from-source)
- [Project Structure](#project-structure)
- [Architectural Decisions](#architectural-decisions)
- [FAQ](#faq)
- [Known Limitations](#known-limitations)
- [Roadmap](#roadmap)
- [Uninstall](#uninstall)
- [Contributing](#contributing)
- [License](#license)

---

## Download

Grab the latest `aLaunchpad.zip` or `aLaunchpad.dmg` from the [**Releases**](https://github.com/mu0072/aLaunchpad/releases) page. Both contain the same universal binary (Apple Silicon + Intel).

### First launch (macOS Gatekeeper)

aLaunchpad is **ad-hoc signed** (not notarized by Apple), so the first time you open it macOS will refuse with *"Apple cannot verify aLaunchpad is free of malware"*. To allow it:

1. Try to open the app once. It gets blocked — that's expected.
2. Open **System Settings → Privacy & Security**.
3. Scroll to the **Security** section and click **Open Anyway** next to the aLaunchpad notice.
4. Confirm in the next dialog. From then on the app opens normally.

Or, from Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/aLaunchpad.app
```

---

## Quick Start

1. **Download** `aLaunchpad.zip` from [Releases](https://github.com/mu0072/aLaunchpad/releases), unzip, drag `aLaunchpad.app` into `/Applications`.
2. **Open it once** (see Gatekeeper note above).
3. Press **⌥ + Space** anywhere to toggle the launcher.
4. **Type** to filter — try `wx` to find 微信, `chrome` to find Chrome.
5. **Enter** to launch, **Esc** to dismiss.

That's it. No accounts, no permissions prompts, no background daemon.

---

## Requirements

- macOS 13 Ventura or later
- Apple Silicon (arm64) or Intel (x86_64) Mac

---

## Features

### Core
- **Scans all macOS app sources** — `/Applications`, `/System/Applications`, `~/Applications`. Dedupes by `bundleIdentifier`, falls back to path.
- **Auto-refresh via FSEvents** — installing or uninstalling an app triggers a rescan automatically within ~1 s (the FSEventStream's coalescing latency). No need to relaunch or hit "Rescan Applications" manually. Selection is preserved across rescans if the previously-selected app still exists.
- **Floating translucent panel** — 90% × 90% centered HUD-blur panel with 10pt rounded corners and proper window shadow.
- **Classic Launchpad-style paged grid** — fixed 8 columns × 4 rows per page (32 apps) with a dot indicator at the bottom. Page count is computed from the visible app list; only one page → no dots. 88pt icons, fixed 2-line label, **row spacing computed dynamically from available height** so the grid always fills evenly between the search bar and the dot row.
- **Async scanning** — runs on a detached background priority task; never blocks the main thread.
- **Icon cache** — in-memory `NSImage` cache keyed by app path; recycled across scroll passes.

### Search
- **Live filtering** as you type, auto-focused on open.
- **Pinyin matching** — `微信` is found by typing `weixin` or `wx`. Powered by `CFStringTransform(kCFStringTransformMandarinLatin)`; tokens are precomputed at scan time so every keystroke is just a few `String.contains` checks.
- **Substring + initials** — both full pinyin (`wei xin`) and initials (`wx`) match.

### Favorites & Archive
- **Favorites** are pushed to the front of the paged list, so they always occupy the first page.
- **Archive** (v1.2) — hover any app icon and click the small `archivebox` button in its top-right corner to move it out of the main grid. The 📦 icon next to the sort button opens the archived-apps view (in-place switch, same panel); click the small button again in archive view to restore. Archived apps still appear in main-view search results, rendered dimmed with a small corner badge, and Enter launches them normally.
- v1.1 users: the old `Hide` mechanism is replaced. Existing `aLaunchpad.hidden` data is migrated automatically to `aLaunchpad.archived` on first launch.
- All preferences persist to `UserDefaults` keyed under `aLaunchpad.*`.

### Sort
- **Name (A → Z)** — default
- **Name (Z → A)**
- **Date Added (Newest)** — uses filesystem creation date via `URLResourceKey.creationDateKey`
- **Date Added (Oldest)**
- Selection persists across launches.

### Window behavior
- Borderless, non-activating `NSPanel` subclass that still accepts key focus
- HUD material (`.hudWindow`) backdrop blur + 25% dark overlay
- Floats over all spaces and full-screen apps
- 10pt rounded corners matching macOS standard zoomed-window radius
- 90% × 90% of the visible workspace, centered (respects menu bar + Dock)
- Click-through prevention via a non-hit-testing visual layer with a click-eater below
- Outside-click dismissal via `NSEvent.addGlobalMonitorForEvents`
- Trackpad swipe paging via accumulated horizontal `.scrollWheel` deltas

### Menu bar
A persistent menu bar item (▦ SF Symbol) with:
- Open aLaunchpad
- Rescan Applications
- Quit aLaunchpad

### App icon
Programmatically drawn brushed silver gradient with a 3×3 grid of dark-charcoal-outlined cells and a soft ice-white center accent — same color family as macOS System Settings. Generated at all 10 macOS-required icon sizes by `Scripts/MakeIcon.swift`; no external image assets.

### Launch behavior
- Fresh launch (Dock / Finder / Spotlight) opens the launcher panel automatically.
- Already running: clicking the Dock icon re-opens the panel (`applicationShouldHandleReopen`).
- Closing the panel (Esc / outside click / app launch) does NOT quit the app — it stays in the menu bar.

### Power profile
- **0.0% CPU** when the panel is hidden (verified)
- No timers, no polling, no FSEvents watcher (active only while visible), no network
- Global event monitors are installed only while the panel is visible and removed on hide
- ~150 MB resident memory (typical SwiftUI app + cached icons)

---

## Keyboard & Mouse

### Keyboard
| Key | Action |
|---|---|
| ⌥ + Space | Toggle the launcher panel (global hotkey) |
| ← / → | Move selection by one column; auto-flips the page when crossing the boundary |
| ↑ / ↓ | Move selection by one row |
| ⌘ + ← / ⌘ + → | Jump to the previous / next page |
| Enter | Launch the currently-selected app |
| Esc | Hide the launcher |

### Mouse / Trackpad
| Gesture | Action |
|---|---|
| Click app icon | Launch the app, hide the launcher |
| Right-click app icon | Context menu — Add/Remove Favorites · Archive / Unarchive · Reveal in Finder |
| Hover or keyboard-select an app icon | Small archive / unarchive button floats in its top-right corner |
| Two-finger swipe (trackpad / Magic Mouse) | Flip to the previous / next page |
| Click a dot in the page indicator | Jump to that page |
| Click blank area in launcher | Hide the launcher |
| Click any other app / desktop / Dock | Hide the launcher |
| 📦 icon at right of search row | Toggle the archived-apps view |
| ↕ icon at right of search row | Sort menu — Name (A→Z / Z→A) · Date Added (Newest / Oldest) |

---

## Build from Source

### Prerequisites

- macOS 13+
- Xcode Command Line Tools (`xcode-select --install`)

### Build

```bash
git clone https://github.com/mu0072/aLaunchpad.git
cd aLaunchpad
./build.sh
```

Produces `build/aLaunchpad.app` for your host architecture. The script auto-generates the app icon if `aLaunchpad/Resources/AppIcon.icns` is missing.

### Build a universal binary (arm64 + x86_64)

```bash
UNIVERSAL=1 ./build.sh
```

This is how the official Releases are built.

### Regenerate the icon manually

```bash
./make_icon.sh
```

### Install locally

```bash
cp -R build/aLaunchpad.app /Applications/
open /Applications/aLaunchpad.app
```

### Keep in Dock

1. Open the app (Dock icon will appear)
2. Right-click the Dock icon → **Options → Keep in Dock**

macOS gives no visual feedback for "Keep in Dock" — verify by quitting the app and checking the icon stays in the Dock.

---

## Project Structure

```
aLaunchpad/                              # project root
├── README.md                            # this file (English)
├── README.zh-CN.md                      # Chinese version
├── LICENSE                              # MIT
├── CONTRIBUTING.md                      # how to contribute
├── build.sh                             # one-shot build → build/aLaunchpad.app
├── make_icon.sh                         # generates AppIcon.icns
├── set_icon.sh                          # sets the .app's Finder icon
├── Scripts/
│   └── MakeIcon.swift                   # programmatic icon drawing
├── .github/workflows/
│   └── release.yml                      # CI: build + publish on `v*` tag
└── aLaunchpad/                          # Swift sources
    ├── Info.plist                       # bundle config
    ├── OpenPadApp.swift                 # @main entry
    ├── AppDelegate.swift                # @MainActor — menu bar + lifecycle
    ├── Resources/
    │   └── AppIcon.icns                 # generated by make_icon.sh (gitignored)
    ├── Models/
    │   ├── AppItem.swift                # value-type app model + dateAdded
    │   └── Pinyin.swift                 # CFStringTransform + SearchTokens
    ├── Services/
    │   ├── AppScanner.swift             # async filesystem scan + dedup
    │   ├── AppLauncher.swift            # NSWorkspace async/await launch
    │   ├── AppFolderWatcher.swift       # FSEventStream → auto-rescan
    │   ├── HotkeyManager.swift          # Carbon ⌥Space global hotkey
    │   └── IconCache.swift              # @MainActor NSImage cache
    ├── ViewModels/
    │   └── LauncherViewModel.swift      # @MainActor MVVM center
    ├── Views/
    │   ├── ContentView.swift            # root view + click-eater layers
    │   ├── AppGridView.swift            # paged 8×4 grid + dynamic row spacing
    │   ├── AppIconView.swift            # icon + label + selection ring + ctx menu
    │   ├── SearchBar.swift              # top-centered search field
    │   ├── SortMenuButton.swift         # ↕ icon menu
    │   ├── ArchiveToggleButton.swift    # 📦 icon, toggles archive view
    │   └── VisualEffectView.swift       # NSVisualEffectView bridge
    └── Window/
        └── WindowManager.swift          # LauncherPanel + event monitors
```

Architecture is strict MVVM:
- **Models** — immutable value types, no side effects, testable in isolation
- **Services** — system boundaries (filesystem, NSWorkspace, Carbon), individually mockable
- **ViewModels** — `@MainActor` `ObservableObject`, the only mutable state holder
- **Views** — pure SwiftUI rendering; all events route up through closures

---

## Architectural Decisions

### Why a custom `NSPanel` instead of a SwiftUI `Window`?

SwiftUI's `Window` and `WindowGroup` scenes don't expose enough panel configuration on macOS 13. We need:
- Non-activating (clicks don't tear focus from the underlying app's editor)
- Can become key (so the search field accepts input)
- Floats above full-screen apps
- Borderless with custom-clipped corners

A `NSPanel` subclass (`LauncherPanel`) with `NSHostingView<ContentView>` is the only reliable path.

### Why a global event monitor instead of `windowDidResignKey`?

`NSEvent.addGlobalMonitorForEvents` fires only for events that happen **outside** the receiving app's process. That's exactly the semantics we want for outside-click dismissal — no risk of false-positives from in-app menus, popovers, or right-clicks. `windowDidResignKey` would over-trigger on any focus change including transient menus.

### Why three separate click layers in `ContentView`?

```
┌─ VisualEffectView (allowsHitTesting=false)  — visuals only, never eats clicks
├─ Color (opacity 0.0001 + onTapGesture)       — click-eater, dismisses on tap
└─ VStack { searchRow, AppGridView, ... }      — real controls
```

SwiftUI gesture priority puts child gestures (icon `.onTapGesture`, search field, sort menu, dot indicator) above the parent click-eater, so clicks that land on a real control go to that control, and only blank-area clicks fall through to the dismiss handler.

### Why pages instead of a vertical scroll view?

Earlier versions wrapped the grid in a `ScrollView`. Once we matched classic Launchpad with a fixed-grid paged layout, scrolling became redundant — every visible row is a real row, and the user can flip pages with arrow keys, ⌘←/→, two-finger swipe, or the dot indicator. Removing the scroll view also removed a layer of click swallowing inside the panel.

### Why a dynamic row-spacing formula?

`LazyVGrid` only takes a static `spacing:` parameter, so a fixed value leaves an obvious gap below the last row when the grid is shorter than the available area. The grid now reads `geo.size.height` from a `GeometryReader`, knows the rendered cell height (icon 88 + label 30 + paddings = 138pt), and computes `spacing = (height − rows × cellHeight) / (rows − 1)` clamped to `[8, 48]`. The cell uses a fixed-height label frame so every row really is the same height.

### Why Carbon for the global hotkey?

`NSEvent.addGlobalMonitorForEvents` only fires when the app is **not** key — useless for "press ⌥Space anytime, even when focused on Safari, to open the launcher." Carbon's `RegisterEventHotKey` is the only sanctioned macOS API for true global hotkeys without accessibility-permission prompts.

### Why programmatic icon generation?

So the repo has zero binary assets. Anyone cloning the project gets a self-contained build; `./build.sh` runs `./make_icon.sh` on demand. Color and shape are ~30 lines of Swift in `Scripts/MakeIcon.swift` — change values, rebuild, done.

---

## FAQ

**Q: How is this different from Spotlight / Alfred / Raycast?**
A: aLaunchpad does one thing — *launching installed apps* — with a classic Launchpad-style paged grid. No file search, no calculator, no web search, no plugins. If you only ever used Spotlight to open apps, this replaces that with a faster keyboard flow and pinyin support, at zero idle CPU.

**Q: Does it support pinyin search?**
A: Yes. Type `wx` to find 微信, `chrome` to find Chrome. Tokens are precomputed at scan time via `CFStringTransform`, so search is instant regardless of how many apps you have.

**Q: Does it run on Intel Macs?**
A: Yes. Release builds are universal (arm64 + x86_64). Local `./build.sh` builds for your host architecture only by default; use `UNIVERSAL=1 ./build.sh` for both.

**Q: Why 0% CPU when hidden?**
A: No timers, no polling, no background scanning. The FSEvents watcher and global event monitors are installed only while the panel is visible and removed on hide. Idle cost is essentially the menu bar item.

**Q: Will it ask for Accessibility / Full Disk Access permissions?**
A: No. The Carbon global hotkey API doesn't require Accessibility, and app scanning uses public `Bundle` / filesystem APIs on standard `/Applications` paths.

**Q: How do I remove the "Apple cannot verify" warning?**
A: See [First launch (macOS Gatekeeper)](#first-launch-macos-gatekeeper). Short version: open System Settings → Privacy & Security → *Open Anyway*.

**Q: Can I change the global hotkey from ⌥Space?**
A: Not yet — see [Roadmap](#roadmap). PRs welcome.

---

## Known Limitations

| Limitation | Workaround |
|---|---|
| Not notarized by Apple | Allow the first launch in System Settings (see [Gatekeeper](#first-launch-macos-gatekeeper)) |
| No hotkey conflict UI | If ⌥Space is taken by another app, registration silently fails; menu bar still works |
| Page size hard-coded 8×4 | No preference panel yet to change columns / rows per page |
| No usage-frequency ranking | All apps weighted equally; no MRU sort |
| Single screen | Uses `NSScreen.main`; multi-monitor layouts always show on the primary |

---

## Roadmap

1. **Custom hotkey UI** — Preferences pane to rebind from ⌥Space
2. **Multi-monitor** — show on the screen containing the cursor
3. **Icon LRU + disk cache** — bound memory on machines with hundreds of apps
4. **Usage-based ranking** — surface frequently launched apps first
5. **Configurable page grid** — preference to change columns/rows per page
6. **Drag-to-reorder + drag-between-pages** — closer to the original Launchpad ordering model
7. **Developer ID signing + notarization** — drop the Gatekeeper prompt
8. **Tests** — unit tests for `AppScanner`, `SearchTokens.matches`, `LauncherViewModel`
9. **Localization** — extract hard-coded Chinese UI strings into `Localizable.strings`

---

## Uninstall

```bash
pkill -x aLaunchpad
rm -rf /Applications/aLaunchpad.app

# Remove preferences (favorites, archive, sort, etc.)
defaults delete local.alaunchpad.app 2>/dev/null

# Remove from Launch Services database
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister \
  -u /Applications/aLaunchpad.app 2>/dev/null
```

---

## Contributing

PRs and issues welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, style, and PR conventions.

Built with macOS native frameworks only:
- SwiftUI (UI)
- AppKit (`NSPanel`, `NSVisualEffectView`, `NSWorkspace`, `NSStatusItem`, `NSHostingView`)
- Foundation (`Bundle`, `URLResourceKey`, `UserDefaults`)
- Carbon HIToolbox (`RegisterEventHotKey`)
- Core Foundation (`CFStringTransform` for pinyin)

No third-party dependencies.

---

## License

Released under the [MIT License](LICENSE).
