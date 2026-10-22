# YabaiSpaces - Quick Context

## What is this?
macOS menu bar app that displays clickable space indicators. Integrates with Yabai for space switching.

## Current State
- **Version:** 1.10.0 installed locally and packaged as a verified universal DMG with SHA-256 checksum. The retained 1.8.0 DMG is historical. See `SESSION_LOG.md` for GitHub publication status.
- **Status:** Exact packaged Release app verified and installed locally; 53 automated tests pass with no skips, including Space-only thumbnail clicks and departure-capture regressions. Actual panel open/close verified; broader physical-input/multi-monitor coverage remains limited.
- **Last work:** October 22, 2026 - clean universal 1.10.0 package, verified backup/install/restart, current installation guide and release notes; GitHub publishing uses the authorized `carcot` account

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
- **Installation:** Follow `docs/INSTALLATION.md` and `docs/RELEASE_1.10.0.md`. The 1.10.0 package uses Apple Development signing, not notarized Developer ID distribution signing; check `SESSION_LOG.md` for publication status.
- **Preview modes:** Default Windows means wallpaper/outlines, not screenshots. Preferences → Button Style → Thumbnail enables cached screenshots for both menu bar and panel. No preference was changed by the documentation update.
- **SIP/no-animation:** Current yabai supports fast SIP-enabled `space --focus` (7.1.19+). The separate `skip_window_focus_animation` option (7.1.22+, improved 7.1.23) is only for setups without the scripting addition; locally it remains off. See README for upstream sources and limitations.
- **CGImage Leaks:** Always convert CGImage → PNG immediately, cache only PNG Data
- **Project Naming:** Xcode uses "YabaiIndicator", app branded as "YabaiSpaces"
- **Remote:** `origin` = your fork, `fork` = also your fork (historical)

## Next Steps
See README.md "Remaining limitations and future work" section. Builds do not install automatically; runtime changes require verified backup/install/restart. GitHub publication requires write access to the configured repository.

## Documentation
- `docs/INSTALLATION.md` - Fresh installation, permissions, preview modes, signing, optional shortcuts, upgrade/rollback and troubleshooting
- `SESSION_LOG.md` - Detailed change history
- `MEMORY_LEAK_FIX.md` - Memory leak technical details
- `CLAUDE.md` - Claude-specific project guidance
