# YabaiSpaces - Quick Context

## What is this?
macOS menu bar app that displays clickable space indicators. Integrates with Yabai for space switching.

## Current State
- **Version:** 1.8.0; see `docs/RELEASE_1.8.0.md` and `SESSION_LOG.md` for packaging/publication status
- **Status:** Universal Release app verified and installed locally; 50 automated tests pass. Physical-input and broader multi-monitor coverage remain limited.
- **Last work:** October 2026 - native Caps configuration, skhd handoff, manual window controls, cycling/border fixes, and ID-bearing focus tracking

## Key Files to Know
| File | Purpose |
|------|---------|
| `YabaiAppDelegate.swift` | App lifecycle, panel, hotkeys |
| `ContentView.swift` | Space button UI |
| `PrivateWindowCapture.swift` | Screenshot capture |
| `ImageGenerator.swift` | Button image generation |
| `HotkeyManager.swift` | Composable hotkey system |
| `WindowSwitching.swift` | Window history and derived recent-Space ordering |
| `CapsConfiguration.swift` | Reloadable TOML application/Space bindings |
| `WindowHandling.swift` | Manual move/resize and yabai-backed insertion |
| `Connectors/YabaiClient.swift` | Asynchronous focus/navigation and yabai integration |

## Build/Test
```bash
./build-dmg.sh
python3 -m unittest discover
```

## Important Gotchas
- **CGImage Leaks:** Always convert CGImage → PNG immediately, cache only PNG Data
- **Project Naming:** Xcode uses "YabaiIndicator", app branded as "YabaiSpaces"
- **Remote:** `origin` = your fork, `fork` = also your fork (historical)

## Next Steps
See README.md "Remaining limitations and future work" section. Builds do not install automatically; runtime changes require verified backup/install/restart. GitHub publication requires write access to the configured repository.

## Documentation
- `SESSION_LOG.md` - Detailed change history
- `MEMORY_LEAK_FIX.md` - Memory leak technical details
- `CLAUDE.md` - Claude-specific project guidance
