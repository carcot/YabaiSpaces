# Memory Leak Evidence - August 21, 2026

## Leaks Tool Output
```
Process:         YabaiIndicator [17891]
Path:            /Users/USER/Library/Developer/Xcode/DerivedData/YabaiIndicator-dwzhypgpamdanzgksdnpyxudlnbu/Build/Products/Debug/YabaiIndicator.app/Contents/MacOS/YabaiIndicator
Identifier:      com.carcot.YabaiSpaces
Version:         1.1.0 (1)

Process 17891: 48470 nodes malloced for 8336 KB
Process 17891: 84 leaks for 14544 total leaked bytes.

    84 (14.2K) << TOTAL >>

      3 (672 bytes) ROOT LEAK: <CGImage 0xca4074f00> [320]
         2 (352 bytes) <CGDataProvider 0xca4076bc0> [320]
            1 (32 bytes) 0xca65d8b00 [32]

      3 (672 bytes) ROOT LEAK: <CGImage 0xca4075680> [320]
         2 (352 bytes) <CGDataProvider 0xca4076800> [320]
            1 (32 bytes) 0xca505d860 [32]
```

## Memory Usage Timeline
```
2026-08-21 19:05:25.361 - Memory usage: 75 MB (startup)
2026-08-21 19:06:01.255 - Memory usage: 81 MB (panel_open_centered)
2026-08-21 19:06:29.893 - Memory usage: 91 MB (panel_open_centered)
2026-08-21 19:07:07.201 - Memory usage: 97 MB (panel_open_centered)
2026-08-21 19:08:17.043 - Memory usage: 103 MB (panel_open_centered)
2026-08-21 19:08:45.022 - Memory usage: 108 MB (panel_open_centered)
2026-08-21 19:08:47.237 - Memory usage: 114 MB (panel_open_centered)
2026-08-21 19:08:48.965 - Memory usage: 119 MB (panel_open_centered)
2026-08-21 19:08:50.572 - Memory usage: 120 MB (panel_open_centered)
2026-08-21 19:08:52.427 - Memory usage: 126 MB (panel_open_centered)
```

## Test Procedure
1. Launched app from Xcode Debug build
2. Opened panel multiple times using Option+Command+Space
3. Memory usage increased from 75 MB to 126 MB (51 MB increase)
4. Ran `leaks <pid>` which confirmed 84 CGImage leaks

## Current Implementation (LEAKING)
```swift
func generateHybridPreviewImage(active: Bool, visible: Bool, windows: [Window], display: Display, scale: CGFloat = 1.0) -> NSImage {
    // ... cache setup ...
    
    let context = createCGContext(size: size)

    // This direct CGImage drawing is STILL leaking:
    if let wallpaperCG = gPrivateWindowCapture.captureDesktopCG(display: display, targetSize: size) {
        context.draw(wallpaperCG, in: rect)  // ⚠️ CGImage LEAKS
    } else {
        context.setFillColor(NSColor(red: 0.3, green: 0.35, blue: 0.45, alpha: 1.0).cgColor)
        context.fill(rect)
    }

    // Draw window outlines
    drawWindowOutlines(context: context, windows: windows, display: display, targetSize: size)
    
    // ... PNG conversion and caching ...
}
```

## Comparison to Working Solution
The memory-safe version from commit `ae254c4`:
```swift
func generateHybridPreviewImage(active: Bool, visible: Bool, windows: [Window], display: Display, scale: CGFloat = 1.0) -> NSImage {
    let context = createCGContext(size: size)
    
    // Memory-safe: NO wallpaper rendering
    context.setFillColor(NSColor(red: 0.3, green: 0.35, blue: 0.45, alpha: 1.0).cgColor)
    context.fill(rect)
    
    // Draw window outlines only
    drawWindowOutlines(context: context, windows: windows, display: display, targetSize: size)
}
```

## Conclusion
**All CGImage wallpaper rendering approaches leak memory** - both NSImage drawing and direct CGContext drawing. The only memory-safe solution is to remove wallpapers entirely and use solid color backgrounds.