<p align="center"><img src="assets/banner.svg" alt="lockDock" width="100%"></p>

# lockDock

A macOS menu bar app that **stops the Dock from jumping to another display** when the cursor hits the edge of a secondary screen.

## Features

- **Lock** that you can toggle on/off from the status bar icon.
- **Dock at the bottom, left or right**: the position is read automatically from the Dock settings.
- **Choose which display keeps the Dock** (default: the main display).
- **Adjustable margin**: 2, 4, 8, 16 or 32 px.
- **Hold ⌥ (Option)** to lift the lock for the duration of the gesture.
- **Launch at login** (checkbox in the menu).
- **Localized**: the menu follows the system language (English, French).

An edge shared between two displays stays crossable: only an outer edge of a protected display is blocked.

## Installation

1. Download `DockLock.zip` from the [Releases](https://github.com/DamienGdn/lockDock/releases) page and unzip it.
2. Move `DockLock.app` to `/Applications`.
3. The app is ad hoc signed (no Apple developer account), so on first launch use right-click → Open, or run:
   ```bash
   xattr -dr com.apple.quarantine /Applications/DockLock.app
   ```
4. Grant **Accessibility** access (System Settings → Privacy & Security → Accessibility), then relaunch the app.

## Build

```bash
./build.sh   # → build/DockLock.app and build/DockLock.zip
```

Requires the Xcode command line tools (`swiftc`) and macOS 13 or later.

## How it works

A `CGEventTap` watches cursor movement. When the cursor reaches the "Dock" edge of a protected display, it is held a few pixels back: the Dock, which triggers on contact with the edge, never sees that display.

## Limitations

- The relevant edge of protected displays can't be pointed at beyond the margin.
- Each rebuild changes the signature, so macOS may ask for the Accessibility permission again.
