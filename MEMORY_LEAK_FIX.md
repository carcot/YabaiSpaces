# Memory Leak Fix Documentation

## Regression lesson: protect the invariant, not just the old implementation

The October regression was the same class of resource-lifetime failure returning through a new backend, not an old patch being removed. The earlier repair avoided a leaking capture route and retained PNG-only caches. When overlay exclusion introduced another capture API, that cache policy remained, but the new function pointer did not consume its original Create-rule image reference. Converting an image to PNG is not sufficient if the source allocation is still owned elsewhere.

The previous source guards and timing/pixel tests could pass while every capture retained another full-screen buffer. They protected output and one implementation choice, not the broader resource-lifetime invariant. Every added/replaced capture backend must preserve bounded physical-footprint growth as well as correct pixels, exclusions, timing and failure behavior. A new call site or branch must inherit the safety requirements even when it does not reuse the old API. The 1.11.0 real-capture memory regression closes the demonstrated excluded-window-path gap; it is not proof that every possible future backend is covered.

### Current shared boundary

Live desktop-thumbnail requests converge on `YabaiAppDelegate.captureThumbnail(for:)` → `PrivateWindowCapture.captureSpace(...)`. In 1.12.0 that adapter delegates to `ScreenshotCaptureService`, which owns both private backends and the PNG/lifetime pipeline. The original regression occurred **inside the earlier shared function**, when a new branch was added. Another public wrapper alone would not have prevented it.

Wallpaper loading is different: `ImageGenerator` calls `captureDesktopCG(...)`, which loads the wallpaper file rather than photographing the desktop. The legacy private `captureWindow`/`captureDisplay` helpers were inactive and were removed in 1.12.0, not enabled as new capture modes.

### Shared capture service — implemented in 1.12.0

A stronger shared capture service is now implemented, following the previously documented proposal. See [architecture and backend coverage](docs/CAPTURE_SERVICE.md). Its boundaries are:

- Route all live-screen screenshot requests through one service; UI/navigation code supplies an explicit display, thumbnail size and exclusions, not raw capture API calls. Add other source kinds only when needed, with explicit semantics rather than a large ambiguous mode switch.
- Keep platform capture calls and their ownership adapters private. Each backend must convert retained Create/Copy results to correctly owned Swift references immediately; it must not escape unbalanced handles. Keep scaling/PNG encoding and temporary-object lifetime management inside the service, returning only PNG `Data` or an explicit failure to callers/caches.
- Preserve the departure contract: capture the correct outgoing display before focus changes, exclude YS overlays, never relabel destination pixels, and preserve the prior clean cache on failure. A fallback is permitted only if it preserves those semantics; silently dropping exclusions is not acceptable.
- Keep wallpaper-file loading and UI image rendering as separate operations, even if they share encoding utilities. They are not interchangeable with a screenshot and must not become a misleading success fallback.
- Exercise every supported backend/mode with ownership/failure tests, repeated-capture physical-footprint checks after warm-up, and the applicable actual-pixel/order/exclusion tests. Report unavailable Screen Recording checks as skips, not proof of safety. An API-name/source guard or PNG-only return type is not sufficient evidence of bounded memory.

The intended benefit is a small, auditable ownership boundary and reusable backend acceptance tests, not a promise that centralization eliminates bugs. The original proposal was implemented in a subsequent user-authorized change: private plain/excluded system backends, checked request/result semantics, a per-request lifetime/scaling/PNG pipeline, removal of unused legacy capture helpers, and memory checks for both modes plus deterministic ownership/failure tests. Wallpaper remains separate, sharing image-processing utilities rather than becoming a screenshot fallback. No new capture mode or departure-timing policy was introduced.

## October 27, 2026 regression — 1.11.0

Version 1.9.0 added `CGWindowListCreateImageFromArray` capture to exclude YS overlays while preserving fresh departure-time screenshots. Its dynamically loaded function pointer incorrectly returned an ARC-managed `CGImage?`. Unlike a directly imported annotated Core Graphics Create function, that pointer did not communicate ownership of the returned +1 reference. Every capture leaked its original image reference and the associated full-screen Mach-message-backed pixel buffers. Keeping only PNG data in caches did not release the original reference.

The long-running installed 1.10.0 process had an **81.4 GB physical footprint**, mostly swapped out, while RSS was only about 57 MB. `leaks` reported 18,917 leaked heap objects totaling 3,062,464 bytes, including many CGImage/CGDataProvider roots; those small heap totals do not include the approximately 81 GB of leaked image-buffer mappings. RSS alone therefore concealed the problem. The original leak report and memory maps were saved before restarting the existing app to reclaim memory.

The fix gives only the active exclusion-capture function pointer an explicit `Unmanaged<CGImage>?` result and immediately calls `takeRetainedValue()` to transfer its Create-rule reference to ARC. No capture fallback, exclusion policy, cache format, thumbnail timing, window selection or keyboard behavior changed. See [Apple's Core Foundation ownership guidance](https://developer.apple.com/documentation/swift/working-with-core-foundation-types). The standing [departure-thumbnail contract](EXTERNAL_SWITCH_CAPTURE_NOTES.md#required-thumbnail-timing-contract) remains mandatory; reverting to a stale or panel-contaminated image is not a memory fix.

Added `test_excluded_capture_memory_stays_bounded` to the existing thumbnail tests. It uses the production capture implementation, warms four real exclusion captures, then measures `task_vm_info.phys_footprint` across 24 more captures, each in an autorelease pool. It permits bounded warm-up/caching growth, not one full-screen buffer retained per call. Before the fix it grew **559,923,584 bytes** and failed; afterward the targeted run grew **786,432 bytes**, and the full-suite run grew **802,816 bytes**, both below the 32 MiB local limit. The test skips explicitly if existing Screen Recording permission is absent; it never requests authorization. All **54 tests passed with no skips in 102.417 seconds**, including real-pixel freshness/panel exclusion and capture-before-switch ordering. A clean signed universal Release build succeeded; installation and actual-app soak measurements are recorded in [SESSION_LOG.md](SESSION_LOG.md).

Diagnostic records: `/private/tmp/YS-leaks-20261027-before.txt`, `/private/tmp/YS-vmmap-20261027-before.txt`, `/private/tmp/YS-vmmap-20261027-full-before.txt`, `/private/tmp/YS-capture-memory-before-20261027.log`, `/private/tmp/YS-capture-memory-after-20261027.log`, and `/private/tmp/YS-memory-fix-tests-20261027.log`. Temporary records are not permanent recovery storage. A short bounded regression does not establish a multi-day leak-free guarantee or eliminate unrelated framework allocations; do not interpret a nonzero system-framework leak count alone as recurrence of this full-screen-buffer leak.

During 1.11.0 verification, six warm-up panel cycles followed by 40 actual panel open/close cycles changed physical footprint from **19.4 to 20.7 MiB**. A later scan at **22.9 MiB** reported no leaked CGImage/CGDataProvider roots, but still found 144 small NSMutableDictionary-related objects totaling 10,368 bytes. Those objects were not stack-attributed; this is not a claim of zero application/framework leaks. No separate 1.11.0 DMG was produced; its fix is included in 1.12.0.

The June 2026 findings below are historical and describe a different capture implementation. Their statement that active capture always avoids window-list capture no longer describes 1.9.0 and later.

## June 2026 investigation (historical)

## Current Summary

The verified memory leak was in active-space thumbnail capture, not in wallpaper-backed hybrid previews.

The leaking path used private SkyLight capture APIs:

```text
YabaiAppDelegate.showPanelCentered
YabaiAppDelegate.captureThumbnail(for:)
PrivateWindowCapture.captureSpace
PrivateWindowCapture.captureWindow / captureDisplay
SLWindowListCreateImage
```

`leaks` with `MallocStackLogging=1` showed leaked `<CGImage>` roots allocated under SkyLight's `SLWindowListCreateImage` path.

## Correct Release Note

### Memory Leak Fix

This release fixes the verified thumbnail-capture memory leak that caused excessive RAM consumption when repeatedly opening the spaces panel.

### Changes

- Replaced private SkyLight window/display thumbnail capture with public `CGDisplayCreateImage()` active-display capture.
- Preserved real thumbnails for the active visible space.
- Preserved wallpaper-backed hybrid previews for unvisited spaces.
- Kept thumbnail and wallpaper cache entries as PNG `Data` instead of long-lived `CGImage` or `NSImage` objects.
- Removed hotkey registration debug logging in the 1.1.1 cleanup release.

### Verified Metrics

The verified reproducer was: launch with `MallocStackLogging=1`, trigger the panel hotkey 40 times, then run `leaks <pid>`.

| Metric | Before Verified Fix | After Verified Fix |
|--------|---------------------|--------------------|
| Leaks | 205 | 0 |
| Leaked memory | 35,424 bytes | 0 bytes |
| Physical footprint | 610.5M | 43.8M |
| Peak physical footprint | Not recorded for old run | 50.8M |

Longer-running spot checks after the fix also reported `0 leaks for 0 total leaked bytes` with the app footprint in the 25-29M range after several hours.

## What Was Superseded

The older release-note text claimed:

- 96% reduction in CGImage leaks, from 1911 to 73.
- 95% reduction in leaked memory, from 311KB to 14.8KB.
- 94% reduction in physical footprint, from 7.0G to 434M.

Those numbers are historical investigation data, not the current verified fix. They came from earlier aggregate `leaks` runs and static ownership analysis around CoreGraphics rendering, PNG conversion, and image cache storage. That work reduced risk and remains useful, but the independently verified reproducer showed the active leak was the private SkyLight thumbnail capture path.

## Fix Details

### PrivateWindowCapture.swift

`captureSpace()` now captures the currently visible display with `CGDisplayCreateImage()`, scales it to thumbnail size, and immediately converts the result to PNG data:

```swift
func captureSpace(windows: [Window], display: Display, targetSize: CGSize) -> Data? {
    return captureQueue.sync {
        guard let displayID = getDisplayID(for: display.index),
              let displayImage = CGDisplayCreateImage(displayID),
              let scaledImage = scaleImage(displayImage, to: targetSize) else {
            return nil
        }

        return cgImageToPNG(scaledImage)
    }
}
```

This avoids `captureWindow()`, `captureDisplay()`, and the private SkyLight `SLWindowListCreateImage` path for active-space thumbnails.

### Image Cache Ownership

The cache strategy still stores rendered images as PNG `Data` and decodes fresh short-lived images when needed. This avoids long-lived ownership of `CGImage` and `NSImage` objects.

### Wallpaper Hybrid Previews

Wallpaper-backed hybrid previews are preserved. Wallpaper thumbnails are cached as PNG `Data`, keyed by display ID, thumbnail size, and wallpaper path.

## Additional Fixes Kept

- `ComposableHotkey` uses unretained CGEventTap user data because `HotkeyManager` owns the hotkey object lifetime.
- `ComposableHotkey.deinit` invalidates the event tap, removes its run loop source, and clears retained references.
- `CarbonHotkey.deinit` unregisters the Carbon hotkey.
- `SocketClient.c` frees request buffers and closes sockets on early failure paths.

## Verification Procedure

```bash
# Build the app
xcodebuild -project YabaiIndicator.xcodeproj -scheme YabaiIndicator -configuration Release build

# Run with malloc stack logging when investigating leaks
MallocStackLogging=1 ~/Library/Developer/Xcode/DerivedData/.../Build/Products/Release/YabaiIndicator.app/Contents/MacOS/YabaiIndicator &

# Check baseline leaks
PID=$(pgrep -f YabaiIndicator | head -1)
leaks $PID

# Trigger the panel repeatedly, then check again
osascript -e 'repeat 40 times' \
  -e 'tell application "System Events" to key code 49 using {command down, option down, control down, shift down}' \
  -e 'delay 0.08' \
  -e 'end repeat'
leaks $PID
```

Expected result for the verified fix:

```text
Process <PID>: 0 leaks for 0 total leaked bytes.
```

## Date

Last updated: June 21, 2026
