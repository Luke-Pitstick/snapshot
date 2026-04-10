# Snapshot

A lightweight, keyboard-first macOS screenshot tool written in Swift.

- **Menu-bar only** — no Dock icon, ~560 KB binary.
- **Customizable global hotkeys** for region / full-screen / window capture.
- **Drag-to-select region overlay** that matches the native feel (dim backdrop, live dimensions, multi-monitor).
- **Floating thumbnail** after capture (drag out, Save As…, open in Preview, auto-dismiss) or straight-to-clipboard — user choice in Settings, with an override modifier for per-capture toggling.
- Built on **ScreenCaptureKit** (`SCScreenshotManager`) — requires macOS 14 Sonoma or newer.

## Requirements

- macOS 14.0 or newer
- Swift 5.9+ toolchain (`swift --version`)
- On first launch, grant **Screen Recording** permission in
  *System Settings → Privacy & Security → Screen Recording*, then relaunch.

## Build

```bash
# Debug build (for iteration from the terminal)
swift build

# Release build + .app bundle at ./build/Snapshot.app
make app

# Build, bundle, and launch
make run

# Clean
make clean
```

The Makefile bundles the SwiftPM executable into a proper `.app` with the
`Info.plist` from `Sources/Snapshot/Resources/Info.plist` (which sets
`LSUIElement=YES` and declares the Screen Recording usage description), then
ad-hoc codesigns it so macOS will run it.

## Default hotkeys

| Action              | Shortcut   |
|---------------------|------------|
| Capture region      | ⌃⇧⌘4      |
| Capture full screen | ⌃⇧⌘3      |
| Capture window      | ⌃⇧⌘5      |

All three are rebindable in **Settings → Hotkeys**. Requires at least one
modifier (⌘/⌥/⌃/⇧). If a combo is already claimed by another app or the
system, registration fails silently — pick a different one.

## Destination

**Settings → General → Default destination** controls what happens after a
capture:

- **Floating Thumbnail** (default) — a small preview card appears in the
  bottom-right. Drag it into Finder/Slack/Mail, right-click for Save As…,
  click to open in Preview, or wait for auto-dismiss.
- **Copy to Clipboard** — silently places PNG + TIFF on the pasteboard.

**Override modifier** (default ⌥) flips the destination for a single
capture: hold it while pressing a hotkey to get the non-default behavior.

## Project layout

```
snapshot/
├── Package.swift                       # SPM executable target, macOS 14+
├── Makefile                            # build → bundle → codesign
├── Sources/Snapshot/
│   ├── SnapshotApp.swift               # @main, MenuBarExtra + Settings scene
│   ├── AppDelegate.swift               # boots AppCoordinator, sets accessory mode
│   ├── AppCoordinator.swift            # owns capture + router + hotkey registration
│   ├── Menu/MenuBarContent.swift       # status-bar menu
│   ├── Hotkeys/
│   │   ├── KeyCombo.swift              # keyCode + modifiers, @AppStorage-ready
│   │   ├── HotKeyManager.swift         # Carbon RegisterEventHotKey wrapper
│   │   └── HotKeyRecorderView.swift    # SwiftUI hotkey recorder
│   ├── Capture/
│   │   ├── CaptureMode.swift
│   │   ├── CaptureCoordinator.swift    # orchestrates a single capture
│   │   ├── ScreenCaptureService.swift  # ScreenCaptureKit wrapper
│   │   ├── PermissionsChecker.swift    # TCC Screen Recording helpers
│   │   ├── RegionSelectionController.swift
│   │   ├── SelectionOverlayWindow.swift
│   │   ├── SelectionOverlayView.swift  # drag-to-draw with marching ants
│   │   └── WindowPickerController.swift
│   ├── Result/
│   │   ├── CaptureResult.swift
│   │   ├── ResultRouter.swift          # clipboard vs thumbnail
│   │   ├── ThumbnailWindowController.swift
│   │   └── ThumbnailView.swift
│   ├── Settings/
│   │   ├── Preferences.swift           # @AppStorage-backed model
│   │   └── SettingsView.swift          # SwiftUI tabs: General / Hotkeys / Output
│   └── Resources/Info.plist
└── README.md
```

## Notes

- Global hotkeys go through Carbon's `RegisterEventHotKey`, which does **not**
  require Accessibility permission and consumes the event (so the combo
  doesn't leak to the focused app).
- Multi-monitor region selection works per display — drag on the monitor you
  want; the overlay spans all screens but the final rect is captured from the
  display where the drag started.
- The app is unsandboxed. That's deliberate — simplifies ScreenCaptureKit
  usage and Save As… across arbitrary folders. Revisit if you ever want to
  ship via the Mac App Store.

## License

MIT.
