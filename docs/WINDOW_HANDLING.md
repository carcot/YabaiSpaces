# Window controls — 1.3.0

YS supplies manual controls; yabai remains the only layout owner. No HyprMac daemon, virtual workspace system, automatic YS layout engine, Caps remapping, or input-service reconfiguration is installed.

## Try it

- Hold **Control + Option**, then left-drag anywhere inside a window to move it.
- Hold **Control + Option**, then right-drag to resize from its bottom-right corner.
- YS displays a blue preview; the actual window changes **on release**, not continuously during dragging. A movement under five points does nothing. Escape cancels; release the mouse before starting again.
- On a BSP-tiled Space, left-drag onto another tiled window to insert beside its nearest edge. Empty desktop/self-drops do nothing. Targets must be on the same Space.
- Right-dragging a tiled window adjusts its bottom/right tree boundaries through yabai. Boundaries at the outside of a layout may not be resizable.
- YS menu → **Window controls** enables/disables mouse controls and exposes tiling, floating, and split actions. Disabling mouse controls persists across restarts; command actions remain available.

Existing Caps-prefix jumps, Caps holds, Command navigation, ordinary mouse actions, and yabai's Fn-drag controls are unchanged. YS deliberately does not use the Caps modifier for these gestures.

## Tiling is opt-in

All twelve Spaces were using `float` when this feature was developed. Installation leaves them that way. Movement/resizing works without enabling tiling.

**Tile current Space (automatic BSP)** explicitly asks yabai to arrange that Space and manage new windows there. This is real automatic tiling by yabai, not just a visual grouping. Do not enable it if you want that Space to stay completely manual. **Stop tiling current Space** stops management but does not restore the previous floating positions. Layout choices follow yabai's existing lifetime/configuration behavior; YS does not rewrite yabairc.

## Commands

Invoke the installed executable directly (or your existing YS wrapper):

```sh
/Applications/YabaiSpaces.app/Contents/MacOS/YabaiIndicator window move-left
/Applications/YabaiSpaces.app/Contents/MacOS/YabaiIndicator window wider
/Applications/YabaiSpaces.app/Contents/MacOS/YabaiIndicator handling off
```

`window move-left|move-right|move-up|move-down` moves a free window by 40 points. `window wider|narrower|taller|shorter` changes size by 40 points. Additional actions: `window toggle-float`, `window toggle-split`, `space tile`, `space untile`, `handling on`, `handling off`. No keyboard bindings for these commands are installed. CLI acknowledgment means queued, not necessarily applied; rejected operations are logged by YS.

## Architecture and safety

`WindowHandling.swift` separates geometry, the injected/testable yabai backend, and event/preview handling. A serial worker samples visible windows/Space layouts every half second. The event tap never performs yabai IPC; it starts only from a snapshot under one second old and the frontmost on-screen window under the pointer. IPC/AX failures do not block normal mouse delivery. No third-party window is moved until release.

The backend re-queries before applying a drag, rejecting changed source identity/geometry/Space/layout. Insertions additionally require unchanged eligible membership/geometry in the source Space and an unobscured target at release. Hidden, minimized, fullscreen, zoomed, sticky, nonstandard, and non-AX windows are excluded. Stack layouts are not handled unless the window itself floats. Panel opening and YS Space departures cancel the preview before thumbnail capture. Cancellation retains consumption of the captured button through its release so the app does not receive an unmatched mouse-up.

Insertion uses yabai `--insert` followed by `--warp`, not a parallel tree. Because `--insert` toggles, YS first requests the opposite edge, then the intended edge, ensuring the desired direction is set regardless of a previous insertion marker. A failed warp attempts to clear YS's marker. These are separate IPC requests, not an atomic transaction: concurrent external layout commands can still race. YS does not reconstruct or overwrite a tree after a failure.

Preview rectangles are placement hints, not exact final geometry: yabai owns split ratios/gaps and apps impose minimum sizes. Removing a tile from its old position can change the target's available area. Resize clamps the requested dimensions to at least 160×100 points; application constraints may be larger. Multi-monitor coordinates preserve the Quartz global origin and convert only the overlay to AppKit coordinates. Cross-Space insertion, live animated dragging, resize-handle selection, screen-edge snapping, and layout restoration are not implemented in this first version.

## HyprMac reuse

`PlacementTarget.resolve` adapts `HyprMac/Tiling/TiledDragTarget.swift` from [HyprMac commit 1ea990a0f0be30a5e0f0a05ce98cabffc832f373](https://github.com/zacharytgray/HyprMac/tree/1ea990a0f0be30a5e0f0a05ce98cabffc832f373): finite-frame filtering, unique-target selection, normalized nearest-edge distances, and deterministic ties. Types were renamed and IDs widened for YS. The rest of HyprMac's drag transaction code depends on its own tree/cache/window-management system and was not imported. The MIT notice is retained in `YabaiIndicator/HyprMac-LICENSE.txt` and copied into the app bundle's Resources.

## Verification

`test_window_handling.py` compiles/executes the production Swift implementation with a fake backend: all edges, negative screen coordinates, overlap/self/invalid-target rejection, excluded windows, movement thresholds, minimum dimensions, free/tiled command construction, insertion sequencing, failure cleanup, stale source/target/layout rejection, and Escape/button-release cancellation. It never posts global input or changes real windows. `test_native_commands.py` covers every new wire command and rejects malformed commands. `test_thumbnail_capture.py` checks that the handling preview is cancelled before departure capture.

The first clean signed Xcode build succeeded. Existing asset-size/unassigned-icon and unreachable-catch warnings remain unrelated. Deployment and live-test results are recorded in `SESSION_LOG.md`; a passing harness is not evidence of physical mouse or multi-monitor correctness.
