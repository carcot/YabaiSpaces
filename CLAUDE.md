# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

YabaiIndicator is a macOS menu bar app that displays clickable space/workspaces indicators. It integrates with [Yabai](https://github.com/koekeishiya/yabai) (a tiling window manager) for space switching and window management.

## Build and Test Commands

### Building
```bash
# Build the project
xcodebuild -project YabaiIndicator.xcodeproj -scheme YabaiIndicator -configuration Debug build

# Build for release
xcodebuild -project YabaiIndicator.xcodeproj -scheme YabaiIndicator -configuration Release build
```

### Testing
```bash
# Run unit tests
xcodebuild test -project YabaiIndicator.xcodeproj -scheme YabaiIndicator -destination 'platform=macOS'

# Run specific test
xcodebuild test -project YabaiIndicator.xcodeproj -scheme YabaiIndicator -destination 'platform=macOS' -only-testing:YabaiIndicatorTests/YabaiIndicatorTests/testExample
```

### Opening in Xcode
```bash
open YabaiIndicator.xcodeproj
```

## Architecture

### Core Components

**Entry Point & App Lifecycle**
- `YabaiIndicatorApp.swift` - SwiftUI `@main` app struct, delegates to `YabaiAppDelegate`
- `YabaiAppDelegate.swift` - Main application delegate, manages:
  - NSStatusItem (menu bar icon) for Preferences/Quit menu
  - Floating panel that appears on hotkey (Option+Command+Space) for on-demand space switching
  - Global hotkey using Carbon RegisterEventHotKey for reliable system-wide hotkey
  - Socket server for receiving refresh commands from Yabai
  - Observers for space/display change notifications
  - Combine publishers for reactive UI updates

**Data Layer**
- `Models/SpacesModel.swift` - `SpaceModel` is the central `ObservableObject` holding `spaces`, `windows`, and `displays`
- `Models/SpaceType.swift` - Enum for space types (standard, fullscreen, divider)
- `Models/ButtonStyle.swift` - Enum for UI button styles (numeric, windows)

**Connectors (Data Sources)**
- `Connectors/NativeClient.swift` - Queries spaces/displays using private SkyLight framework (no Yabai dependency for basic functionality)
- `Connectors/YabaiClient.swift` - Communicates with Yabai via UNIX socket for space switching and window queries
- `SocketClient.c/h` - C implementation for Yabai socket protocol communication

**UI Layer**
- `ContentView.swift` - SwiftUI view rendering space buttons in the menu bar
- `SettingsView.swift` - Preferences window with toggle options
- `ImageGenerator.swift` - Generates NSImage for space indicators (numeric text or window previews)

### Integration Patterns

**Yabai Communication (two-way)**
1. App → Yabai: `YabaiClient` sends commands via `SocketClient.c` (UNIX domain socket at `/tmp/yabai_$USER.socket`)
2. Yabai → App: Yabai signals send "refresh" commands to app's socket server at `/tmp/yabai-indicator.socket`

**SkyLight Framework**
- Private macOS framework accessed via `SkyLightConnector.h`
- Provides `SLSCopyManagedDisplaySpaces()` and `SLSCopyManagedDisplays()` for querying state without Yabai
- Requires `SYSTEM_LIBRARY_DIR/PrivateFrameworks` in search paths

**State Flow**
```
Yabai signals → Socket Server → receiverQueue → NativeClient/YabaiClient → SpaceModel → SwiftUI updates
Workspace notifications → NSWorkspace.observers → refresh methods → SpaceModel
```

### Bridging

`YabaiIndicator-Bridging-Header.h` exposes C functions to Swift:
- `send_message()` from `SocketClient.c` for Yabai communication
- SkyLight functions for display/space queries

### Configuration

UserDefaults (registered via `defaults.plist`):
- `showDisplaySeparator` - Show divider between displays
- `showCurrentSpaceOnly` - Hide inactive spaces
- `buttonStyle` - Numeric vs window preview mode

### Floating Panel Feature

**Hotkey**: Option+Command+Space shows/hides a floating panel at mouse position

- Panel displays space indicators and can be used to switch spaces
- Clicking any space button switches to that space
- Any click (inside or outside panel) hides the panel after a brief delay
- Implemented using Carbon RegisterEventHotKey for reliable global hotkey support
- Works even when app is not frontmost (requires Accessibility permissions)

### Key Dependencies

- **BlueSocket** (Swift Package) - Socket server for receiving Yabai signals
- **SkyLight.framework** (private) - Display/space queries
- **Carbon.framework** - Global hotkey registration
- **Cocoa/AppKit** - NSStatusItem, NSImage, NSPanel, menu bar integration
