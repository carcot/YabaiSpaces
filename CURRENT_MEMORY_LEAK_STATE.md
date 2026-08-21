# Current Memory Leak State

**Date**: August 21, 2026  
**Status**: 🚨 **ACTIVE MEMORY LEAK** - Desktop wallpapers restoration caused regression

## Current Situation

### Memory Leak Confirmed
**Memory Usage Pattern:**
```
Startup: 75 MB
Panel opens: 81 → 91 → 97 → 103 → 108 → 114 → 119 → 120 → 126 MB
Total increase: 51 MB over multiple panel opens
```

**Leaks Tool Output:**
```
Process 17891: 84 leaks for 14544 total leaked bytes
ROOT LEAK: <CGImage 0xca4074f00> [320]
ROOT LEAK: <CGImage 0xca4075680> [320]
```

### What We Did Wrong
1. **Assumed direct CGImage drawing was safe**: Used `context.draw(wallpaperCG, in: rect)` thinking it would avoid the NSImage leaks
2. **Ignored the original fix**: Commit `ae254c4` removed wallpapers specifically because of CGImage leaks
3. **Insufficient testing**: Didn't run `leaks` tool during development, only checked basic functionality

### What Actually Happened
- **Commit `ce328c8`**: Had working wallpapers with NSImage drawing (caused leaks)
- **Commit `ae254c4`**: Removed wallpapers entirely to fix leaks (gray backgrounds)
- **Our fix**: Restored wallpapers with direct CGImage drawing (STILL LEAKS)

## The Core Problem

**Both approaches leak:**
```swift
// Original approach - leaks
let wallpaper = NSImage(cgImage: wallpaperCG, size: size)
wallpaper.draw(in: rect)  // CGImage leaks

// Our "fix" - still leaks  
context.draw(wallpaperCG, in: rect)  // CGImage leaks
```

The fundamental issue is that **any CGImage drawing in this context creates dependency leaks**, regardless of the drawing method.

## Current State of Files

### Wallpaper Loading Fix (COMMITTED BUT BROKEN)
- **Commit**: `4940905` "fix: restore desktop wallpapers in hybrid previews (memory-safe)"
- **Files modified**:
  - `PrivateWindowCapture.swift` - Multi-screen wallpaper loading
  - `ImageGenerator.swift` - Direct CGImage drawing (LEAKING)
  - `ButtonImageCache.swift` - Separate wallpaper cache
  - `YabaiClient.swift` - Fixed queryWindows logic
  - `WALLPAPER_LOADING_FIX.md` - Incorrect documentation
  - `SESSION_LOG.md` - Incorrect session history

### Memory Logging (WORKING)
- **Commit**: `0de1e29` "fix: add safety checks and improvements"
- **Status**: ✅ Working correctly, detected the leak
- **Output**: Shows 51 MB memory increase over panel opens
- **Method**: Uses `NSLog` (not unified logging)

## Technical Analysis

### Why Direct CGImage Drawing Leaks
Even though we used `context.draw(cgImage, in: rect)` instead of NSImage drawing, the CGImage dependencies are still being retained somewhere in the rendering pipeline.

### What Commit ae254c4 Actually Fixed
Looking at the original fix:
```swift
// BEFORE (leaking):
if let wallpaperCG = gPrivateWindowCapture.captureDesktopCG(...) {
    let wallpaper = NSImage(cgImage: wallpaperCG, size: size)
    wallpaper.draw(in: rect)
}

// AFTER (memory-safe):
context.setFillColor(NSColor(red: 0.3, green: 0.35, blue: 0.45, alpha: 1.0).cgColor)
context.fill(rect)
```

The solution was **removing wallpapers entirely**, not changing the drawing method.

## Summary

**We successfully restored wallpapers but reintroduced the exact memory leak that was fixed in commit `ae254c4`.** The direct CGImage drawing approach is not memory-safe, and we now have 84 CGImage leaks causing 51 MB of memory growth.

The logging system is working perfectly and detected the leak immediately, but the core wallpaper rendering approach needs to be completely reconsidered or reverted.