# Session Log

## 2025-03-13: Fix Thumbnail Race Condition - Use SpaceID Instead of UUID

### Problem
Space thumbnails were being incorrectly associated - Space 9 and Space 12 both showed Space 9's thumbnail.

### Root Cause
Two issues:

1. **UUID-based identification was unreliable**: SkyLight's `uuid` field for spaces was sometimes empty or unstable, causing cache misses and incorrect associations.

2. **Race condition in async thumbnail loading**: In `ThumbnailSpaceButton.loadThumbnail()`, the async preview capture compared against `self.space.uuid` captured when the closure was created. When the view was reused for a different space after model updates, the stale captured value caused wrong thumbnails to be displayed.

### Solution

**Changed from UUID-based to SpaceID-based caching**:
- `Space.id64` (a stable UInt64 from SkyLight) is now used as the primary key for:
  - Thumbnail cache lookups (`ThumbnailCache.get(spaceId:)`)
  - Thumbnail display validation (`thumbnailSpaceId == space.spaceid`)
  - Active space tracking (`lastActiveSpaceId`)

**Fixed race condition**:
- Changed `loadThumbnail()` to check against current view state (`self.thumbnailSpaceId`) instead of captured value
- Only accept thumbnail if:
  - No thumbnail is loaded (`thumbnailSpaceId == 0`), OR
  - Loaded thumbnail is for the same space (`thumbnailSpaceId == targetSpaceId`)

### Files Modified
- `ContentView.swift`: Changed `thumbnailUUID` to `thumbnailSpaceId`, fixed async comparison
- `ThumbnailCache.swift`: Changed cache key from `String` (UUID) to `UInt64` (spaceId)
- `NativeClient.swift`: Removed UUID-based visibility comparison, use `id64` directly
- `YabaiAppDelegate.swift`: Changed `lastActiveSpaceUUID` to `lastActiveSpaceId`

### Testing
- Rapid space switching (especially spaces 9 and 12) now shows correct thumbnails
- Cache is properly invalidated when spaces change

## 2025-03-13: Add Hybrid Thumbnail Style - Desktop Wallpaper + Window Outlines

### Problem
Thumbnail style showed nothing (or poor preview) for spaces without cached thumbnails. The window-style preview was filled-in, not proper outlines, and lacked desktop backgrounds.

### Solution

**New hybrid preview style** for spaces without cached thumbnails:
- Displays actual desktop wallpaper as background (read from system preferences)
- Draws window outlines only (white strokes, no fill)
- No rounded corners - full rectangular thumbnail area

**Added notification-based cache updates**:
- `ThumbnailCache` now posts `.thumbnailDidCache` notification when thumbnail is cached
- `ThumbnailSpaceButton` listens for notifications and reloads when thumbnail becomes available
- Fixes issue where active space showed outlines instead of captured thumbnail on first panel open

### New Functions
- `generateHybridPreviewImage()` in `ImageGenerator.swift`: Generates desktop wallpaper + window outlines preview
- `drawWindowOutlines()` in `ImageGenerator.swift`: Draws window outlines only (copied from `drawWindows()`)
- `captureDesktop()` in `PrivateWindowCapture.swift`: Captures actual desktop wallpaper from system preferences
- `.thumbnailDidCache` notification in `ThumbnailCache.swift`: Posted when thumbnail is cached

### Files Modified
- `ContentView.swift`: Added `.onReceive()` for cache notifications, removed async preview capture
- `ImageGenerator.swift`: Added hybrid preview generation functions
- `PrivateWindowCapture.swift`: Added `captureDesktop()` to read wallpaper from NSWorkspace
- `ThumbnailCache.swift`: Added notification posting when thumbnail is cached

### Testing
- First panel open: all spaces show desktop wallpaper + window outlines
- Switching to space: real thumbnail captured and cached
- Subsequent panel opens: visited spaces show cached thumbnails, unvisited show hybrid preview
- Active space now immediately shows captured thumbnail (not outlines) on panel open

## 2025-03-13: Add Active Space Highlight Border

### Problem
No clear visual indication of which space is currently active in the floating panel.

### Solution
Added border-based highlight system:
- Active space: 2px system accent color border (blue by default)
- Inactive spaces: 1px subtle gray border
- Removed redundant black border from hybrid preview image generation
- Borders handled by SwiftUI overlay for consistent styling across all button types

### Files Modified
- `ContentView.swift`: Added unified border overlay (accent for active, gray for inactive)
- `ImageGenerator.swift`: Removed black border from `generateHybridPreviewImage()`

### Testing
- Active space clearly distinguished with accent color border
- Inactive spaces have subtle gray borders
- Cleaner appearance without double borders

## 2025-03-13: Add Keyboard Navigation to Floating Panel

### Problem
No way to navigate and select spaces using keyboard - mouse required.

### Solution
Added full keyboard navigation to the floating panel:

**Navigation:**
- Arrow keys (up/down/left/right) navigate between spaces with wrap-around
- Selection follows grid layout (respects column count)
- Selection persists during navigation session

**Selection:**
- Enter or Space: Switch to selected space and close panel
- Works even when current space is already selected (just closes panel)
- Escape: Close panel without switching

**Visual Feedback:**
- Selected space shows 4px accent color border (outermost)
- Active space shows 2px accent color border (inside selection border when both apply)
- Selection resets to current active space when panel opens

**Implementation:**
- Keyboard handling in `YabaiAppDelegate.handlePanelKeyEvent()`
- Notification-based communication to SwiftUI views
- Works with existing local event monitor for panel visibility

### Files Modified
- `YabaiAppDelegate.swift`: Added `handlePanelKeyEvent()`, `resetPanelSelection()`, extended key monitor
- `ContentView.swift`: Added selection state, notification handling, visual selection border

### Testing
- Arrow keys navigate with wrap-around at edges
- Enter/Space switches and closes panel
- Escape closes panel
- Selection highlight visible (4px accent border)
- Selection resets to active space when panel opens

## 2025-03-13: Add Wallpaper and Desktop Caching

### Problem
Panel opening had noticeable delay due to:
1. Wallpaper file being read on every hybrid preview generation
2. Desktop capture happening multiple times per panel open

### Solution
Added caching for wallpaper and desktop+icons images:

**Wallpaper caching:**
- `loadWallpaper()` reads wallpaper from NSWorkspace once and caches in `cachedWallpaper`
- `captureDesktop(display:targetSize:)` returns cached wallpaper (with resizing if needed)

**Desktop+icons caching:**
- `captureAndCacheDesktopWithIcons()` captures desktop from first display once
- `captureDesktopWithIcons(targetSize:)` returns cached desktop (with resizing if needed)
- Used by hybrid preview for more realistic background

### Files Modified
- `PrivateWindowCapture.swift`: Added `cachedWallpaper`, `cachedDesktop`, `loadWallpaper()`, `captureDesktopWithIcons()`, `captureAndCacheDesktopWithIcons()`, `clearCaches()`

### Testing
- Panel opens faster (wallpaper read once, not per space)
- Hybrid preview shows desktop background more accurately
- Desktop icons included in cached background (captureDisplay() includes desktop icons)

## 2025-03-13: Fix Hybrid Preview - Use Wallpaper Only

### Problem
Hybrid preview was capturing actual screen content including app windows. Every space showed the same screenshot of the current screen, making spaces indistinguishable.

### Root Cause
`captureDesktopWithIcons()` used `CGWindowListCreateImage` with nil window array, which captures the entire screen including all app windows. This was called for every space, resulting in identical thumbnails.

### Solution
Removed screen capture path entirely. Hybrid preview now:
- Uses cached wallpaper only (read once from NSWorkspace, cached in `cachedWallpaper`)
- Draws window outlines on top using Yabai window data
- No app windows in background
- Each space looks unique based on window layout from Yabai

### Files Modified
- `ImageGenerator.swift`: Removed `captureDesktopWithIcons()` call, simplified to use only cached wallpaper
- `PrivateWindowCapture.swift`: Removed unused `captureDesktopWithIcons()` function and `cachedDesktop` variable

### Testing
- Panel opens fast (wallpaper cached)
- Each space shows unique window outlines from Yabai data
- No app windows visible in background
