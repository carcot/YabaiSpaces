# Current Memory Leak State

## Release status

The thumbnail-capture memory regression is fixed for YabaiSpaces 1.1.5. Space thumbnails are generated from a single public display capture instead of private per-window WindowServer captures.

## Root cause

The previous `captureSpace()` implementation called the private `CGWindowListCreateImage` API for every visible window and composited the results. Each panel open retained about 16.3 MB of Mach-message-backed memory even after the Swift and Core Graphics objects went out of scope. The retained memory was below the application object layer and could not be resolved by adding local autorelease pools or clearing image caches.

## Fix

`captureSpace()` now:

1. Resolves the target `CGDirectDisplayID`.
2. Captures the display once with the public `CGDisplayCreateImage` API.
3. Scales the display image to the thumbnail size.
4. Encodes the scaled image as PNG data.

This is the same display-capture technique proven in commit `1eef6ce`. The old private capture helpers remain available to other code, but the space-thumbnail path no longer invokes them.

## Verification

- Swift parsing passed after the implementation change.
- A clean build completed successfully.
- All 6 Xcode tests passed.
- A correctly signed runtime capture generated an 8,829-byte PNG for space 9.
- Resident memory was 102,784 KB before opening the panel and 102,656 KB afterward, with no capture-related increase.
- The tested application used bundle identifier `com.carcot.YabaiSpaces` and Team ID `7CJ3BM3AGT`.
- The 1.1.5 DMG mounted read-only and passed image checksum verification.
- The packaged executable contains both `x86_64` and `arm64` slices and reports version `1.1.5`.
- DMG SHA-256: `840862db7c5b9ab1a20c43eb0b086e37260e44faf7443d2f24b497237fefba32`.

The app has an embedded hardened-runtime signature with the expected bundle ID and Team ID. Strict trust evaluation on the build host reports `CSSMERR_TP_NOT_TRUSTED`, so the local signing certificate chain is not currently suitable for a trusted public distribution without renewal or notarization.

## Known tradeoff

The public API captures the current display as a whole. It avoids the WindowServer resource retention of private per-window capture, but it does not independently reconstruct the contents of a non-visible space. Cached thumbnails remain the mechanism for representing spaces that are not currently displayed.
