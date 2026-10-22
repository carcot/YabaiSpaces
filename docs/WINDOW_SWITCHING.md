# Native application and window switching

Version 1.8.0 adds [ID-bearing focus tracking](FOCUS_TRACKING.md): raw signal events are retained separately from eligible-window MRU, with asynchronous query/command workers, guarded live reconciliation, and a one-second safety check. `YabaiSpaces focus status` exposes bounded diagnostics. Receipt order is not guaranteed chronological order; reconciliation repairs current focus but cannot reconstruct missed intermediate changes. YS's own windows and dialogs remain outside navigation targets. Cycling still freezes candidates for two seconds and ends on a confirmed external focus change.

## SIP-enabled transitions

Current yabai can focus Spaces without the Dock scripting addition or disabling SIP. Direct Space focus and switches caused indirectly by application/window focus have different animation paths; `window_animation_duration` is not the Space-transition control. See the [README's versioned no-animation guidance](../README.md#sip-enabled-switching-and-no-animation-support) before enabling `skip_window_focus_animation`, which is only for setups without the scripting addition. The documentation update did not enable it locally. [Installation and permissions](INSTALLATION.md) are separate from YS's MRU/cycling policies below.

## Thumbnail clicks — 1.10.0

Clicking anywhere on a thumbnail switches to its Space without selecting a window based on the click position. The previous `findWindowAt` implementation and coordinate-based drag/click handler remain in block comments in `ContentView.swift`, at the user's request. The active handler is a plain tap calling `switchSpace()` without a target window ID. Destination focus is left to normal yabai/macOS Space switching; this does not add a new MRU-selection policy for panel clicks. Native MRU commands, keyboard selection, focus-history updates, and departure-time thumbnail capture are unchanged.

## Thinning border — 1.7.0

The cycling border starts at up to three points and thins linearly with the remaining two-second deadline, reaching zero at expiry. Repeated cycling renews the deadline and restores the corresponding thickness. Refreshes of the same deadline do not restart the countdown.

The transparent overlay keeps fixed three-point padding around the actual window. A shape-layer outline moves its centerline outward by half its current stroke width, keeping the stroke's inner edge against the window as it thins. This avoids a growing gap that would result from simply reducing the old layer's borderWidth. The border follows frame changes with no added movement, show/hide, or implicit layer animation. The thinning itself updates every 50 milliseconds; panel suppression, thumbnail exclusion, focus behavior, and cycle cancellation are unchanged.

The AppKit regression checks positive decreasing thickness, midpoint/expiry behavior, renewal, and stroke-edge adjacency on every side before and after window movement. Deployment details are in SESSION_LOG.md.

## October 5 correction and cycling border — 1.6.0

Verified focus produced by a YS cycling command is explicitly marked as cycling focus. Only those transitions keep window MRU frozen. A different focus observed from outside that command ends the cycle, commits its final selected window, and immediately promotes the newly focused window. Thus mouse clicks, external shortcuts, and panel selection affect the same window history used for deduplicated Space traversal. Repeated refreshes of the already-selected window do not end cycling. No eligible focused window, navigation failure, or a cycle with no target ends the session.

The two-second deadline is renewed on each processed cycling command. A dispatch timer expires and commits history even if no new focus event or command arrives; the old implementation waited for another observation. The timer shares the model's deadline with the UI. Scope changes commit the preceding cycle before creating a new frozen list. Eligible windows are still filtered, closed windows pruned, and Space candidates still select the first (most recently focused) window per Space from that frozen window history. Empty Spaces are excluded. Startup history remains in memory and starts from live query order; it is not persisted across restarts.

An orange, three-point border follows the verified focused window during a cycle and disappears when its deadline expires or the cycle ends. It is a transparent nonactivating, mouse-ignoring panel and follows window movement without taking focus. It is hidden while the Spaces panel is visible and before outgoing thumbnail captures. It does not mark the Caps-letter waiting interval or ordinary application jumps. Geometry and expiry refresh on the main run loop; a blocked main thread can delay drawing/removal until it resumes.

Caps-period and `jump .` no longer invoke window cycling. An unmodified period during the Caps prefix is consumed and dismisses it, avoiding accidental punctuation. The global Command-L shortcut was removed from skhd. Right-Command tap still cycles recent Spaces; Right-Option tap still cycles windows in the current Space. Existing Command-period is retained.

Regression verification covers full window/Space traversal, cycling focus versus manual focus, unchanged-focus observations, pruning, no-target cancellation, deadline renewal, automatic expiration without new events, and controller border callbacks. An AppKit test exercises the actual border against a temporary background window, including movement, expiry, renewal, mouse/focus behavior, and panel suppression. Thumbnail checks assert that the border is hidden before capture. Deployment results are recorded in SESSION_LOG.md.

## October 1 audit (fixed in 1.6.0)

Ordering is not exhaustively correct. A compiled reproducer using the production WindowSwitching engine and the controller's Caps-period cancellation sequence found that three windows A/B/C yield B → A → B on repeated Caps-period presses. The `JumpCommand` period route cancels before and after every step, promoting the selected window immediately and restarting traversal each time. This can prevent reaching C. The ordinary `window next-in-space` cycle does not have those extra cancellations. No ordering implementation was changed in this audit.

At the time of this audit, focus observations had no provenance: manually clicking another window during an active cycle was treated like a cycling-induced focus change, so MRU remained frozen until expiry/cancellation. Version 1.6.0 distinguishes verified cycling focus and ends the cycle on other focus changes. Startup history is still seeded from query order and lost on restart, as described below.

Left-Command tap no longer generates the Command-F19 cycling trigger. Its Karabiner rule was removed on October 1, preserving Right-Command tap, Command-L/period chords, Caps mappings, and normal Command holding. See SESSION_LOG.md for backup and load verification.

September 14 update: the existing Option-F19 and Command-L/period direct shortcuts now use skhd → YS. See [SHORTCUT_MIGRATION.md](SHORTCUT_MIGRATION.md) for the active mapping and the separate `space next-recent` command. This supersedes the original no-shortcuts-installed deployment notes below.

The installed YS executable accepts these commands through its existing same-user socket:

```sh
YabaiSpaces app next-in-space
YabaiSpaces app previous-in-space
YabaiSpaces app next-across-spaces
YabaiSpaces app previous-across-spaces
YabaiSpaces window next-in-space
YabaiSpaces window previous-in-space
YabaiSpaces window next-across-spaces
YabaiSpaces window previous-across-spaces
```

For skhd or BetterTouchTool shell actions, use the full executable path `/Applications/YabaiSpaces.app/Contents/MacOS/YabaiIndicator` followed by the same arguments. No new shortcuts were installed: existing Hammerspoon, Karabiner, skhd and BTT configuration remains unchanged, including right-Shift/F18 and Hyper-Space. These commands are available now; migrating existing shortcuts is a separate step.

## Selection semantics

- `app` selects one eligible window per application process, choosing that application's most recently used eligible window. It skips other windows of the currently focused application. Applications without an eligible window are not launched or unhidden.
- `window` visits individual eligible windows, including multiple windows belonging to one application.
- `in-space` restricts candidates to the current Space. `across-spaces` includes all Spaces, including the current one; it does not mean always skip to a different Space.
- Next/previous traverse MRU order forwards/backwards with wraparound. Empty lists, a sole current window, or a sole current application are no-ops.
- Only standard, non-minimized, non-hidden windows with valid IDs, processes and Spaces are eligible. Dialogs and desktop/background windows are excluded.

YS owns a new in-memory focus history, updated through the existing yabai window-refresh signals. It cannot import Hammerspoon's private historical ordering: startup seeds from yabai's current query order and promotes the focused window, then learns observed focus changes. Restarting YS resets this history, not Hammerspoon's history.

## Two-second cycling

Hammerspoon's former Command-L/period cycling modes froze MRU reordering and reset their two-second timeout on repeated presses. The native engine freezes candidate order, extends the deadline on every command with a target, and promotes the final observed focus when the interval expires. The old Command double-tap prefix path did not freeze history; its behavior was not identical. As of 1.6.0, expiration uses a timer and external focus changes end cycling immediately. Changing application/window mode or in-Space scope starts a new cycle. Direction changes keep the same cycle. Closed/ineligible windows are pruned; newly discovered windows enter the next cycle. Failure ends the cycle.

Panel selection explicitly ends the active cycle instead of waiting for the timeout, including confirmation of the already-active Space. Cancellation and history observation run on the controller's serial queue without blocking the main thread. Subsequent focus events promote the destination window normally, and the panel switch also requests a fresh observation after its delayed Space-model refresh. Thumbnail clicks no longer request a location-selected window-focus step. Opening, moving the selection within, or dismissing the panel without selecting does not itself end cycling.

`space next-recent` derives its candidates from the frozen window history, retaining only the first eligible window per Space. It cycles those representative windows with wraparound, restoring each Space's most recently focused eligible window. For history A1, B1, A2, C1, the cycle is A1 → B1 → C1 → A1; duplicate Space entries cannot trap traversal. This remains window history, not an independent Space history; empty Spaces do not participate.

Hammerspoon's separate next-Space behavior is not the same as cycling all windows across Spaces. Its implementation and bindings remain untouched, as do previous-Space navigation, Caps Lock, terminal Tab, and input-driver ownership.

## Execution and failure handling

Native argument validation happens before GUI initialization. The server accepts only the eight explicit switching messages, alongside the existing panel and refresh messages. It dismisses an open panel, then schedules switching on a serial background queue. Window observation and switching share that queue so rapid commands cannot race one another. No new key detector is installed.

The controller queries live candidates and current Space, focuses a different Space only when necessary, verifies the transition, revalidates the target, focuses it, then verifies the actual focused window. Transition/focus polling is bounded to one second each and does not block the main UI thread. It uses the existing yabai connector without rewriting rendering or Space-switching UI code. There is no synthetic keyboard input, permission reset, or automatic retry after failure. A failed or disappearing target is logged and cancels the cycle; an already-completed Space transition is not undone automatically.

CLI success still means `ok queued`, not completed focus. Execution failures are recorded in YabaiSpaces logs. The two-second policy applies to processed commands; a delayed/busy backend may therefore lengthen perceived gesture timing.

## Verification and recovery

All 34 focused tests passed. Live checks verified `app next-in-space` and `window previous-in-space` switched windows 135 → 108 within Space 11; `app previous-across-spaces` and `window previous-across-spaces` switched window 1060 in Space 7 → window 1071 in Space 12. Application tests additionally verified the PID changed. Original window 1060 was restored. These checks observed actual yabai focus state, not merely socket acknowledgments or synthetic keys. SIP remained enabled and yabai animation duration remained zero. This is not exhaustive visual or physical-shortcut testing.

`python3 -m unittest test_window_switching test_native_commands test_panel_commands test_merge_regressions test_run` covers pure MRU selection, timeout/wraparound, app grouping, filtering, removal, empty lists, all eight native wire messages, and production controller execution with a fake backend. Controller tests exercise same-Space focus, cross-Space ordering, failed transitions, disappearing targets, focus timeout, and recovery after failure. Existing panel/transport/merge/launcher regressions remain included.

The isolated signed Debug build is `YabaiSpaces-build.De3uLb`. It passes strict verification against the installed app's designated signing requirement. Backup: `~/Library/Application Support/YabaiSpaces/Backups/window-switching-20260913.naJBcW/`, containing previous, original, and new signed apps. To roll back, quit YS and restore the previous app to `/Applications/YabaiSpaces.app`; no input configuration restoration is needed because none changed. The old binary does not support the new switching commands.
