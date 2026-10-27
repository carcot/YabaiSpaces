# YabaiSpaces 1.12.0

Universal macOS app for Apple Silicon and Intel, including the 1.11.0 capture-memory fix and the shared screenshot service.

**Distribution warning:** Apple Development signed, **not Developer ID signed/notarized**. Local signature/launch checks do not establish Gatekeeper acceptance on another Mac. Read the [installation guide](https://github.com/carcot/YabaiSpaces/blob/v1.12.0/docs/INSTALLATION.md); do not disable Gatekeeper or SIP simply to install YS.

## Changes since 1.10.0

- Fix a severe full-screen capture-buffer leak: a long-running 1.10.0 process reached an 81.4 GB mostly-swapped physical footprint. The dynamically loaded excluded-window capture function now transfers its retained image reference correctly to Swift ownership. PNG-only caches alone did not release that reference.
- Route live screenshots through one serialized `ScreenshotCaptureService`: explicit request/result semantics, private plain/excluded system backends, per-request autorelease pools, shared scaling/PNG encoding, and no raw image handles in results. Wallpaper loading remains separate.
- Validate display IDs, target dimensions and exclusions before backend work. Check existing Screen Recording access without requesting it. Failed capture or nil/empty encoding fails closed, never retrying without exclusions or replacing clean cache data with a failed result.
- Remove dormant legacy screenshot helpers and unsafe alternate pointer declarations. Add guards against direct screenshot API bypasses, deterministic provider-release/failure checks, and real physical-footprint regressions for both capture modes.
- Preserve capture immediately before leaving a Space, YS-overlay exclusion, Space-only thumbnail clicks, window history, keyboard shortcuts and user settings. This is capture refactoring/hardening, not a new capture mode or navigation policy.
- Document the regression lesson, backend safety requirements, service architecture, installation and release limits.

## Package and verification

Assets: `YabaiSpaces-1.12.0-Universal.dmg` and `YabaiSpaces-1.12.0-Universal.dmg.sha256`. The DMG contains **YabaiSpaces.app** and an Applications shortcut. Download both assets to one directory, then verify:

```sh
shasum -a 256 -c YabaiSpaces-1.12.0-Universal.dmg.sha256
```

Expected SHA-256: `8b3e04abde085dad29bba11315297763ec01e2d02aac07097cd9dad3c8184b7b`.

All **56 tests passed with no skips in 132.644 seconds**. Separate plain-display and excluded-window workloads each grew by less than 1 MiB across 24 captures after warm-up; the old exclusion implementation grew roughly 534 MiB. Image-provider release counters verify success/failure cleanup and invalid requests. Real-pixel freshness/panel exclusion, pre-focus ordering, native commands, focus/history, Caps/configuration, border, window handling and packaging regressions pass. An explicit clean signed universal Release build passed signature/architecture checks; mounted DMG contents match that build. Its exact app was installed with a verified backup, matching designated requirement and clean replacement, then restarted. Forty panel cycles after warm-up changed physical footprint from **19.5 to 20.4 MiB**, with healthy native diagnostics. See the [service guide](https://github.com/carcot/YabaiSpaces/blob/v1.12.0/docs/CAPTURE_SERVICE.md) and [deployment records](https://github.com/carcot/YabaiSpaces/blob/v1.12.0/SESSION_LOG.md).

## Requirements and remaining limits

Tested on Apple Silicon, macOS 26.6.2, yabai 7.1.25, SIP enabled. Both architectures are packaged, but Intel runtime, every physical shortcut/click, fullscreen/multi-display cases and multi-day memory behavior are not exhaustively verified. Existing asset-catalog, NativeClient unreachable-catch and AppIntents metadata warnings are unchanged.

Short memory regressions do not prove globally zero leaks; the 1.11.0 investigation retained small unattributed dictionary allocations after eliminating capture-image leaks. Thumbnails/MRU remain in memory and reset on restart. External switches bypass YS's departure hook. Default **Windows** means wallpaper/outlines; **Thumbnail** enables cached screenshots shared by menu bar and panel. skhd/Karabiner roles and user configuration are unchanged. Current yabai's SIP-enabled no-animation behavior is documented, not reimplemented here.

For upgrades, back up the working app/configuration, quit YS, replace into a clean `/Applications/YabaiSpaces.app` destination, then launch and verify. Do not merge Release files over a Debug bundle. Rollback below 1.8.0 also requires compatible yabai signals. Verify actual panel/input behavior, not only CLI acknowledgment.
