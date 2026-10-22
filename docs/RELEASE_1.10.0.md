# YabaiSpaces 1.10.0

Universal macOS app bundle for Apple Silicon and Intel. This release includes the accumulated changes since the published 1.1.1 release, including the locally deployed 1.8.0 focus-tracking work and the 1.9.0/1.10.0 thumbnail fixes.

**Distribution warning:** the app is signed with the existing **Apple Development** identity. It is **not Developer ID signed/notarized for public distribution**. Local signature and launch checks do not establish Gatekeeper acceptance on another Mac. Read the [installation and first-launch guide](https://github.com/carcot/YabaiSpaces/blob/v1.10.0/docs/INSTALLATION.md) before installing; do not disable Gatekeeper or SIP just to install YS.

## Changes

- Fresh outgoing thumbnails are captured immediately before YS-controlled Space departure, including panel selection, rather than retaining the image from panel opening. Capture finishes before focus changes, explicitly excludes YS overlays, and preserves the last clean cached image on failure. Window-ID conversion is checked to avoid oversized AppKit IDs crashing capture.
- Clicking anywhere on a thumbnail switches to its Space without selecting a window based on click location. The former hit-testing function and drag/click handler remain commented out as requested. Native MRU navigation and its window-selection rules are unchanged.
- Native CLI/skhd dispatch replaces migrated Python/Hammerspoon panel/navigation actions. Physical modifier taps still use Karabiner; no skhd rewrite or grabber migration is included. Left-Command tap has no YS action and Command-L remains an application shortcut.
- YS owns the renewable two-second Caps-letter prefix, direct F20 detection, application/window selection, and reloadable TOML app/Space bindings. Caps-period dismisses rather than cycles. Local Ghostty bindings are personal configuration, not a changed universal default.
- Recent-Space cycling deduplicates window MRU by Space and targets its most recently focused eligible window. Repeated cycling freezes candidates for a renewable two-second interval; confirmed manual focus and panel selection end cycling and update history.
- The focus border thins from three points to zero with its inner edge adjacent to the window. Mouse move/resize previews and optional nearest-tile-edge insertion use yabai's existing BSP tree, not an independent tiling engine.
- ID-bearing focus/destroy events, bounded diagnostics, asynchronous backend workers, live reconciliation, and owned signal repair improve focus tracking without promising exact producer chronology or persistent history.
- Installation, permissions, signing limits, skhd/Karabiner roles, and newer yabai SIP-enabled no-animation support are documented. The default **Windows** style means wallpaper/outlines; **Thumbnail** enables cached screenshots for both menu bar and panel. No user preview or animation setting was changed for this release.

## Download and verification

Release assets are `YabaiSpaces-1.10.0-Universal.dmg` and `YabaiSpaces-1.10.0-Universal.dmg.sha256`. The DMG contains **YabaiSpaces.app** plus an **Applications** shortcut. Download both files into the same directory, then verify:

```sh
shasum -a 256 -c YabaiSpaces-1.10.0-Universal.dmg.sha256
```

Expected SHA-256: `126d133d262778ac7bedcded7c6464ac2640f55a985ed1eb7f1e8950116b901b`.

All **53 automated tests passed with no skips** in 85.362 seconds, including real-pixel departure capture, checked window IDs, Space-only thumbnail clicks, focus tracking, cycling/border, Caps/configuration, native commands, window handling, and packaging regressions. An explicit **clean universal Release build** passed strict signature and arm64/x86_64 checks. Mounted DMG contents matched the build. The exact packaged app was installed locally with a verified working-app backup and matching designated requirement, restarted, and checked through healthy focus diagnostics and two actual panel open/close cycles.

## Requirements and limits

The tested environment is Apple Silicon, macOS **26.6.2**, yabai **7.1.25**, SIP enabled. Both architectures are packaged; Intel runtime compatibility, every physical shortcut/click, fullscreen applications, and multi-display scenarios are not exhaustively verified. Existing asset-catalog, unreachable-catch, and AppIntents metadata warnings remain unrelated to these fixes.

Current yabai supports fast Space focus without disabling SIP; indirect application/window-focus animation has a separate optional setting for setups without the scripting addition. This is an upstream yabai capability, not a new YS implementation or a guarantee for every OS version. See the [README](https://github.com/carcot/YabaiSpaces/blob/v1.10.0/README.md#sip-enabled-switching-and-no-animation-support).

Thumbnails are cached, not live video; they reset on restart. External Space switches bypass YS's pre-departure capture hook. Spaces without a captured desktop use outlines. Exact chronological focus reconstruction, persistent MRU, independent tiling, and live animated dragging are not included.

For upgrades, preserve the working app/configuration, quit YS, replace into a clean `/Applications/YabaiSpaces.app` destination, then launch and verify. Do not merge Release contents over an older Debug app. Restoring an app older than 1.8.0 also requires compatible yabai signal configuration. See the [installation guide](https://github.com/carcot/YabaiSpaces/blob/v1.10.0/docs/INSTALLATION.md) and [safe deployment notes](https://github.com/carcot/YabaiSpaces/blob/v1.10.0/docs/SAFE_DEVELOPMENT.md).
