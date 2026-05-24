# Contributing to aLaunchpad

Thanks for taking the time to contribute! aLaunchpad is small and
single-maintainer, so a few short conventions go a long way.

## Development setup

You need:

- macOS 13 or later
- Xcode Command Line Tools (`xcode-select --install`) — provides `swiftc`,
  `lipo`, `codesign`, `sips`

That's it. There is no Xcode project, no `Package.swift`, no third-party
dependencies. Everything builds with `swiftc` driven by `build.sh`.

## Build

```bash
./build.sh                    # build for your host architecture
UNIVERSAL=1 ./build.sh        # build a universal (arm64 + x86_64) binary
open build/aLaunchpad.app     # run it
```

The build is ad-hoc signed at the end so it launches without quarantine
warnings during local iteration.

## Project layout

See the *Project structure* section of [README.md](README.md). The
architecture is strict MVVM:

- `Models/` — immutable value types
- `Services/` — system boundaries (filesystem, NSWorkspace, Carbon hotkeys)
- `ViewModels/` — `@MainActor` `ObservableObject`s, the only mutable state
- `Views/` — pure SwiftUI; events route up through closures
- `Window/` — `NSPanel` subclass and event monitors

Please keep new code in the right bucket. If something doesn't fit, raise
it in the PR and we can discuss.

## Coding style

- 4-space indentation, no tabs
- Follow Swift API design guidelines (camelCase, types in `UpperCamelCase`)
- Prefer `let` over `var`; prefer value types over reference types
- `@MainActor` everything that touches `NSImage`, `NSWorkspace`, or SwiftUI state
- No new dependencies — the goal is to stay pure Swift / SwiftUI / AppKit /
  Carbon. Open an issue first if you think one is truly needed.

## Pull requests

1. Fork and create a feature branch off `main`.
2. Keep PRs focused — one feature or fix per PR.
3. Run `./build.sh` and verify the app launches and behaves as expected
   before submitting.
4. Describe **why** the change is needed in the PR body, not just what.
5. If the change affects user-visible behavior, update `README.md` (and
   `README.zh-CN.md` if you read Chinese — otherwise note it in the PR and
   the maintainer will sync).

## Filing issues

When reporting a bug, include:

- macOS version (`sw_vers`)
- Mac architecture (`uname -m`)
- aLaunchpad version (menu bar → About, or the tag you built from)
- Exact reproduction steps
- What you expected vs. what happened

## Internationalization

Currently the UI has a handful of hard-coded Chinese strings (archive
toggle labels). A proper `Localizable.strings` extraction is a welcome
contribution — see issue tracker or open one.

## License

By contributing you agree your contributions are licensed under the
[MIT License](LICENSE) that covers the project.
