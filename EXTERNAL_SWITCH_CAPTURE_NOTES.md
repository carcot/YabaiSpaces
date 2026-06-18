# External Switch Thumbnail Capture - Implementation Notes

## Current Behavior
Thumbnails are only captured when switching spaces via the YabaiSpaces panel (clicking on a space button). This works correctly - the app captures the space being LEFT before switching to the new space.

## Desired Behavior
Thumbnails should also be captured when switching spaces via external methods (keyboard shortcuts, trackpad gestures, Yabai commands, etc.).

## What We Tried

### 1. NSWorkspace.activeSpaceDidChangeNotification Observer
**Location**: `YabaiAppDelegate.onSpaceChanged()`

**Approach**: When the notification fires, capture the space that's currently marked as `active` in `spaceModel.spaces`.

**Problem**: By the time the notification fires, `spaceModel.spaces` has already been updated (likely by Yabai signals arriving before the OS notification), so the space marked as `active` is the NEW space, not the OLD space.

### 2. Track lastActiveSpaceId Before Model Update
**Location**: `YabaiAppDelegate.onSpaceRefresh()`

**Approach**: Store the current active space ID in `lastActiveSpaceId` before querying new spaces. Use this stored ID to find the old space when `onSpaceChanged()` fires.

**Problem**: `onSpaceRefresh()` is called from multiple places (Yabai signals, socket server, etc.). If it's called before `onSpaceChanged()` fires, `lastActiveSpaceId` gets updated to the NEW space before we can use it to find the OLD space.

### 3. Combine Subscriber on spaceModel.$spaces
**Location**: `YabaiAppDelegate.applicationDidFinishLaunching()`

**Approach**: Subscribe to changes in `spaceModel.spaces` using Combine. Detect when the `active` flag changes from one space to another, and capture the space that was previously active.

**Problem**: The subscriber fires AFTER the `@Published` property has been updated, so by the time we detect the change, the model already shows the new state. We can only capture correctly if we track the previous active space ID before the update, which has the same timing issue as approach #2.

## Root Cause
The fundamental issue is that `spaceModel.spaces` gets updated by multiple mechanisms:
1. Yabai signals (via socket server)
2. `NSWorkspace.activeSpaceDidChangeNotification`
3. Direct queries (from `onSpaceRefresh()`)

These updates can happen in any order, and often the Yabai signal updates the model BEFORE the OS notification fires. This means by the time we can react to the space change, the model already reflects the new state.

## Potential Next Steps

If revisiting this in the future, consider these approaches:

1. **Pre-Update Hook**: Modify `onSpaceRefresh()` to detect if the active space is changing BEFORE updating the model, and capture the old space at that moment. This requires knowing the old state before querying the new state.

2. **Separate Tracking**: Maintain a separate "previous active space" variable that's updated atomically when the model changes, ensuring we always know which space was active before the current update.

3. **CGShieldingWindowLevel Capture**: Use a screen capture method that works even when the space is no longer active, allowing us to capture the old space after the switch has occurred.

4. **Window Server Events**: Investigate using lower-level macOS window server events to detect space changes earlier in the notification chain.

5. **Yabai Signal Timing**: If Yabai signals are arriving before OS notifications, consider adding a delay to the signal handler or filtering out duplicate updates.

## Current State
- Thumbnail capture works correctly for panel-initiated switches
- External switches update the UI but do NOT capture thumbnails
- Reserved variables (`lastActiveSpaceId`, `didCaptureBeforeSwitch`, `spaceChangeCancellable`) remain in code for future use
