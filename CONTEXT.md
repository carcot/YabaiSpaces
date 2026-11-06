# YabaiSpaces - Quick Context

## What is this?
macOS menu bar app that displays clickable space indicators. Integrates with Yabai for space switching.

## Current State
- **Version:** 1.13.0 installed locally and packaged as a verified universal DMG; see `SESSION_LOG.md` for publication status. Runtime source matches 1.12.0 and retains the memory fix/shared capture service. Historical 1.10.0 has the capture leak.
- **Status:** Exact packaged clean signed universal Release app verified and installed/restarted; all 56 tests passed with no skips in 105.504 seconds. Both backend memory/pixel/timing checks and two actual panel cycles pass. Another real wake cycle and multi-day soak are not established by this fresh build.
- **Last work:** November 6, 2026 - committed/pushed the skhd recovery documentation, then prepared and installed the requested fresh 1.13.0 bundle. It does not bundle skhd or implement a new YS sleep/wake fix.

## Key Files to Know
| File | Purpose |
|------|---------|
| `YabaiAppDelegate.swift` | App lifecycle, panel, hotkeys |
| `ContentView.swift` | Space button UI |
| `PrivateWindowCapture.swift` | Screenshot capture |
| `docs/CAPTURE_SERVICE.md` | Shared capture boundary, backend ownership, validation and regression matrix |
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
- **Keyboard layers:** Local taps now use an experimental skhd remap agent/grabber plus pqrs VirtualHIDDevice; ordinary skhd separately dispatches YS commands. Healthy remap/socket/YS state does not prove that high-level skhd is running. See `docs/KEYBOARD_HANDLERS.md` and the latest `SESSION_LOG.md` recovery entry before restarting or changing keyboard ownership.
- **Installation:** Follow `docs/INSTALLATION.md` and `docs/RELEASE_1.13.0.md`; 1.13.0 retains the capture-memory fix and shared service. Builds use Apple Development signing, not notarized Developer ID distribution signing; check `SESSION_LOG.md` for publication status.
- **Preview modes:** Default Windows means wallpaper/outlines, not screenshots. Preferences → Button Style → Thumbnail enables cached screenshots for both menu bar and panel. No preference was changed by the documentation update.
- **SIP/no-animation:** Current yabai supports fast SIP-enabled `space --focus` (7.1.19+). The separate `skip_window_focus_animation` option (7.1.22+, improved 7.1.23) is only for setups without the scripting addition; locally it remains off. See README for upstream sources and limitations.
- **CGImage Leaks:** Always convert CGImage → PNG immediately, cache only PNG Data
- **Dynamic Create ownership:** Capture pointers resolved with `dlsym` need explicit retained-reference handling (`Unmanaged<CGImage>` plus `takeRetainedValue()`); PNG caches alone do not release an unbalanced original reference. Measure physical footprint, not just RSS.
- **Project Naming:** Xcode uses "YabaiIndicator", app branded as "YabaiSpaces"
- **Remote:** `origin` = your fork, `fork` = also your fork (historical)

## Next Steps
See README.md "Remaining limitations and future work" section. Builds do not install automatically; runtime changes require verified backup/install/restart. GitHub publication requires write access to the configured repository.

## Documentation
- `docs/INSTALLATION.md` - Fresh installation, permissions, preview modes, signing, optional shortcuts, upgrade/rollback and troubleshooting
- `SESSION_LOG.md` - Detailed change history
- `MEMORY_LEAK_FIX.md` - Memory leak technical details
- `CLAUDE.md` - Claude-specific project guidance
