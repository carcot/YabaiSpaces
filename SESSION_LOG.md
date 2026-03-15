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

## 2025-03-14: Make Panel Hotkeys Toggle Between Show and Hide

### Problem
All panel hotkeys only showed the panel. Pressing the same key combination again would either move the panel (for mouse position) or re-show it (for centered), not hide it.

### Solution
Changed all three hotkey handlers to check panel visibility first and toggle appropriately:

**Toggle behavior for all hotkeys:**
- If panel is visible → hide panel
- If panel is hidden → show panel

**Affected hotkeys:**
- `Cmd+Option+Space` → toggles panel at mouse position
- `Cmd+Option+Ctrl+Space` → toggles centered panel
- Right Shift tap → toggles centered panel

### Files Modified
- `YabaiAppDelegate.swift`: Updated `togglePanel()`, centered hotkey handler, and Right Shift handler

### Testing
- Press hotkey → panel appears
- Press same hotkey again → panel disappears
- Works for all three hotkey combinations

## 2025-03-14: Composable Hotkey System Refactoring

### Problem
Hotkeys were implemented with three separate, duplicated classes:
- `GlobalHotkey` (Carbon RegisterEventHotKey for regular keys)
- `ModifierKeyHotkey` (CGEventTap for modifier keys like Shift)
- `HotkeyEventDispatcher` (Carbon event handler)

Actions were hardcoded in each handler, making it difficult to:
- Add new hotkeys without duplicating code
- Change what action a hotkey performs
- Add new positioning behaviors
- Eventually let users customize hotkeys in preferences

### Solution
Created a composable architecture where **key triggers** are separate from **actions**:

1. **New file: `Models/PanelHotkey.swift`**
   - `PanelPositioning` enum: `.atMouse(NSPoint)`, `.centered`
   - `PanelHotkeyAction` enum: `.toggle()`, `.show()`, `.hide()`
   - `PanelModifiers` struct: `moveMouseToCenter` option
   - `KeyTrigger` enum: `.immediate`, `.tap(threshold:)`, `.release`
   - `HotkeyBinding` struct: composes key + modifiers + action + trigger
   - `PanelHotkeyDelegate` protocol: interface for executing actions

2. **New file: `Managers/HotkeyManager.swift`**
   - `ComposableHotkey` class: unified CGEventTap-based handler for ALL keys
   - Respects `KeyTrigger` enum for any key (regular or modifier)
   - `HotkeyManager` singleton: registers bindings and executes actions

3. **Updated: `YabaiAppDelegate.swift`**
   - Removed `GlobalHotkey`, `ModifierKeyHotkey`, `HotkeyEventDispatcher` classes
   - Removed `setupGlobalHotkeys()` function
   - Added `setupDefaultHotkeys()` with declarative binding definitions
   - Conforms to `PanelHotkeyDelegate`

### KeyTrigger Behavior
- `.immediate`: Fires on key down (default for Cmd+Option+Space)
- `.tap(threshold:)`: Fires only on quick press-release within threshold (Right Shift)
- `.release`: Fires on key up, regardless of hold duration (unused, reserved for future)

### Benefits
- Adding new hotkey: one `HotkeyBinding` line, no new classes
- Changing behavior: modify binding parameters, no handler code changes
- Future user customization: bindings can be serialized from UserDefaults
- Single code path for all keys reduces bugs and duplication

### Files Modified
- **New:** `YabaiIndicator/Models/PanelHotkey.swift`
- **New:** `YabaiIndicator/Managers/HotkeyManager.swift`
- **Modified:** `YabaiIndicator/YabaiAppDelegate.swift`
- **Modified:** `YabaiIndicator.xcodeproj/project.pbxproj` (added new files)

### Testing
- Build: `xcodebuild -project YabaiIndicator.xcodeproj -scheme YabaiIndicator build`
- Verified: All three hotkeys work (Cmd+Option+Space, Cmd+Option+Ctrl+Space, Right Shift)
- Verified: Toggle behavior works on all three
- Verified: Right Shift tap behavior ignores holds and typing


## 2025-03-15: Thumbnail Pre-Capture on Panel Show

### Problem
Thumbnails were only captured AFTER switching spaces, not when opening
the panel. This meant the panel could show stale thumbnails if the user
had been working on the current space for a while.

### Solution
Pre-capture the current space's thumbnail immediately before showing the
panel (in `showPanel()` and `showPanelCentered()`).

### Performance Testing
Measured capture timing using `CFAbsoluteTimeGetCurrent()`:

- Total: 126-276ms (average ~177ms)
- queryDisplay: ~0.1ms (negligible)
- queryWindows: 29-125ms (variable, depends on window count)
- capture: 74-151ms (variable)

User testing confirmed ~140ms latency is acceptable for the tradeoff
of always-fresh thumbnails.

### Files Modified
- `YabaiIndicator/YabaiAppDelegate.swift`:
  - Added pre-capture in `showPanel()`
  - Added pre-capture in `showPanelCentered()`
  - Removed debug logging code

### Future Work
Make pre-capture configurable via preferences:
- "Instant panel" (no pre-capture, uses cached thumbnails)
- "Fresh thumbnails" (pre-capture, ~140ms latency)


## 2025-03-15: Cursor Centering and Restoration on Panel Show/Hide

### Changes
- Panel always centers on screen (changed Cmd+Option+Space from .atMouse to .centered)
- Cursor moves to center of current space's thumbnail when panel opens
- Cursor position saved when panel opens
- Cursor restored to original position when panel closes (Escape, toggle, click-outside)
- Cursor NOT restored after space selection (stays at center on new desktop)

### Implementation Details

**Cursor Positioning:**
- Uses same grid layout calculation as panel to find active thumbnail position
- Converts panel coordinates to screen coordinates for CGEvent
- Y-coordinate flip required: CGEvent uses top-left origin, Cocoa uses bottom-left

**Coordinate System Fix:**
```swift
// Cocoa (bottom-left) to CGEvent (top-left)
let flippedY = mainScreen.frame.height - point.y
let flippedPoint = CGPoint(x: point.x, y: flippedY)
```

**Files Modified:**
- `YabaiIndicator/YabaiAppDelegate.swift`:
  - Added `savedCursorPosition` and `hideWithoutRestore` properties
  - Added `saveCursorPosition()`, `restoreCursorPosition()`, `moveCursorToScreenCenter()`
  - Updated `moveMouseToPanelCenter()` to position at thumbnail center, not panel center
  - Updated `showPanel()` and `showPanelCentered()` to save cursor and move to thumbnail center
  - Updated `hidePanel()` to restore cursor after hiding
  - Updated `switchSpace()` to set `hideWithoutRestore = true`
  - Changed Cmd+Option+Space binding from `.atMouse` to `.centered`

### Behavior
1. Cmd+Option+Space → Panel centers, cursor to current thumbnail center
2. Escape → Panel closes, cursor returns to original position
3. Click space → Switches, panel closes, cursor stays at center (new desktop)
4. Cmd+Option+Ctrl+Space → Same as #1 (now redundant)
5. Right Shift tap → Same as #1

### Debug Logging
Added DEBUG logs for troubleshooting cursor positioning (can be removed later).

## 2025-03-15: Redesign Settings Window - Single Panel with Show/Hide Controls

### Problem
Settings window used TabView with separate "Menubar" and "Spaces Grid" tabs, making it unclear how to enable/disable each mode independently. User wanted unified controls.

### Solution
Redesigned settings as a single panel with:

1. **Section checkboxes** - "Show Menubar" and "Show Spaces Grid" toggles at top of each section
2. **Dimmed controls** - When section is unchecked, its controls are dimmed (40% opacity) and disabled, not hidden
3. **Auto-sizing window** - Window sizes itself to fit content using `NSHostingView.fittingSize`
4. **Segmented pickers** - Changed dropdowns to segmented controls for better visibility
5. **Reordered Cursor Position** - Now: "On Active Thumbnail", "Centered in Grid", "Stay Put"

### UI Layout
```
┌─────────────────────────────────────┐
│ ☑ Show Menubar                      │
│   ☑ Show Display Separator          │
│   ☐ Show Current Space Only         │
│   Button Style: [Numeric | Windows] │
│                                     │
│         ──────────────────           │
│                                     │
│ ☑ Show Spaces Grid                  │
│   Grid Position: [Centered | At Cursor] │
│   Cursor Position: [On Active | Centered | Stay] │
│   ☑ Save and Restore Cursor         │
└─────────────────────────────────────┘
```

### Files Modified
- `YabaiIndicator/SettingsView.swift`:
  - Removed TabView, replaced with VStack with two sections
  - Added `showMenubar` and `showPanel` @AppStorage properties
  - Manual padding/indentation: section headers at 16pt, children at 32pt
  - Centered 200pt divider between sections
  - Added disabled/opacity modifiers for dimming
  - Changed pickers to `.segmented` style
  - Reordered Cursor Position options
- `YabaiIndicator/YabaiAppDelegate.swift`:
  - Settings window now uses `fittingSize` to auto-size to content
  - Removed hardcoded window dimensions
- `YabaiIndicator/defaults.plist`:
  - Added `showMenubar = true` and `showPanel = true` defaults

### Future Work
Wire up `showMenubar` and `showPanel` to actually:
- Hide/show menubar status item
- Enable/disable panel hotkeys

## 2025-03-15: Fix Right Shift Double-Tap Issue

### Problem
Quick taps on Right Shift key registered twice, causing:
- Panel shows → immediately hides
- Or panel hides → immediately shows

User reported this started happening out of the blue after working fine previously.

### Root Cause Investigation
Initially suspected:
1. Hardware issue (wide Shift key with two actuators)
2. Electrical bounce/chatter needing debouncing

Debug logging revealed the actual cause: `setupDefaultHotkeys()` was being called
TWICE during app launch, creating TWO `ComposableHotkey` instances both listening
to Right Shift (keyCode 60):
- First instance handler: shows panel
- Second instance handler: hides panel

**Why two calls?**
Combine publisher for `gridPosition` (line 975) fires immediately during
`applicationDidFinishLaunching()`, calling `updateHotkeyPosition()` →
`setupDefaultHotkeys()`. Then the direct call at line 992 runs again.

### Solution
Made `setupDefaultHotkeys()` idempotent:
- Added `hasSetupHotkeys` flag to `YabaiAppDelegate`
- Guard clause at start of function returns early if already called
- `updateHotkeyPosition()` resets flag to allow re-registration when settings change

**Additional protection:**
Added 300ms handler cooldown in `ComposableHotkey` to block any edge case
duplicate releases (belt-and-suspenders).

### Files Modified
- `YabaiIndicator/YabaiAppDelegate.swift`:
  - Added `hasSetupHotkeys` property
  - Added guard to `setupDefaultHotkeys()`
  - Reset flag in `updateHotkeyPosition()`
- `YabaiIndicator/Managers/HotkeyManager.swift`:
  - Added `lastHandlerCallTime` and `handlerCooldown` to `ComposableHotkey`
  - Added cooldown check in tap trigger release handling
  - Added duplicate registration check in `register()`

### Testing
- Right Shift quick tap now reliably toggles panel once
- Cooldown prevents any rapid-fire duplicate handler calls
- Re-registration works when gridPosition setting changes

