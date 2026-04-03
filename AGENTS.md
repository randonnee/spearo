# Spearo

Spearo is a macOS menu-bar app for instant app switching using function keys. It lets you assign running applications to F1-F12 slots and switch to them with a single keypress — no Cmd+Tab cycling.

## How It Works

- Spearo runs as a **menu-bar-only** app (no dock icon, no main window).
- Users assign apps to **slots** (F1 through F12). Pressing a function key activates/launches that app.
- **Ctrl+Shift+A** adds the currently focused app to the next empty slot.
- **Ctrl+Shift+D** opens the **Spearo dialog** — a floating Spotlight-style panel for managing slots with vim-like keybindings (j/k to move, d to delete, x to cut, p to paste, v for visual selection, Enter to switch, Esc to close).
- Slot assignments persist via `UserDefaults`.

## Tech Stack

- **Swift 5.9**, **SwiftUI + AppKit**, Swift Package Manager
- Targets **macOS 13+**
- Global hotkeys via Carbon `RegisterEventHotKey` API
- Requires **Accessibility permissions** (for global hotkey capture)

## Build & Run

```
swift build              # debug build
./build.sh               # release build + .app bundle
open Spearo.app          # run (then grant Accessibility in System Settings)
```

## Code Overview

```
Sources/Spearo/
  SpearoApp.swift              # @main entry point; menu-bar app with no window
  AppDelegate.swift            # Sets up status bar menu, registers hotkeys, manages dialog lifecycle
  Info.plist                   # Bundle config (LSUIElement=true hides dock icon)

  Models/
    SpearoSlot.swift           # Codable model: bundleIdentifier + display name

  Services/
    HotkeyManager.swift        # Wraps Carbon RegisterEventHotKey; maps key combos to callbacks
    SpearoManager.swift         # Singleton managing 12 slots: switching, adding, reordering, persistence

  Views/
    SpearoDialogView.swift     # SwiftUI dialog with vim keybindings (j/k/d/x/p/v/G/gg)
    SpearoWindowController.swift  # NSPanel (floating, borderless, vibrancy) hosting the dialog; auto-dismisses on click-outside or app switch
```

### Key flows

**Hotkey registration:** `AppDelegate.setupHotkeys()` registers F1-F12 (no modifiers) and Ctrl+Shift+A/D through `HotkeyManager.register()`. Each registration calls Carbon's `RegisterEventHotKey` and stores a callback keyed by a unique ID.

**App switching:** `SpearoManager.switchToSlot()` looks up the slot's bundle identifier, finds the running app via `NSRunningApplication`, and activates it. If the app isn't running, it launches it via `NSWorkspace`.

**Dialog lifecycle:** `AppDelegate.openSpearoDialog()` creates a `SpearoWindowController` which instantiates a borderless `NSPanel` with `NSVisualEffectView` for the translucent background, hosts `SpearoDialogView` inside it, and auto-dismisses on outside click or app-switch notification.

**Slot persistence:** `SpearoManager` encodes the `[SpearoSlot?]` array to JSON and stores it in `UserDefaults` under the key `spearo.slots`.
