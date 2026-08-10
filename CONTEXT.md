# YabaiSpaces - Quick Context

## What is this?
macOS menu bar app that displays clickable space indicators. Integrates with Yabai for space switching.

## Current State
- **Version:** 1.1.1 (universal binary published)
- **Status:** Stable, memory leaks fixed
- **Last work:** June 2026 - CGImage leak fix

## Key Files to Know
| File | Purpose |
|------|---------|
| `YabaiAppDelegate.swift` | App lifecycle, panel, hotkeys |
| `ContentView.swift` | Space button UI |
| `PrivateWindowCapture.swift` | Screenshot capture |
| `ImageGenerator.swift` | Button image generation |
| `HotkeyManager.swift` | Composable hotkey system |

## Build/Test
```bash
xcodebuild -project YabaiIndicator.xcodeproj -scheme YabaiIndicator -configuration Release build
```

## Important Gotchas
- **CGImage Leaks:** Always convert CGImage → PNG immediately, cache only PNG Data
- **Project Naming:** Xcode uses "YabaiIndicator", app branded as "YabaiSpaces"
- **Remote:** `origin` = your fork, `fork` = also your fork (historical)

## Next Steps
See README.md "Future Work" section

## Documentation
- `SESSION_LOG.md` - Detailed change history
- `MEMORY_LEAK_FIX.md` - Memory leak technical details
- `CLAUDE.md` - Claude-specific project guidance
