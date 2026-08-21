# Memory Leak Fix Documentation

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
