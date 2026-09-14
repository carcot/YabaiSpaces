# Native application and window switching

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

The existing `.hammerspoon/focus-window.lua` freezes MRU reordering while cycling and resets its two-second timeout on repeated presses. The native engine follows that timing: it freezes candidate order, extends the deadline on every command, and promotes the final observed focus when the interval expires. The expiration is processed on the next observation/command rather than installing a separate timer. Changing application/window mode or in-Space scope starts a new cycle. Direction changes keep the same cycle. Closed/ineligible windows are pruned; newly discovered windows enter the next cycle. Failure cancels the cycle.

Hammerspoon's separate next-Space behavior is not the same as cycling all windows across Spaces. Its implementation and bindings remain untouched, as do previous-Space navigation, Caps Lock, terminal Tab, and input-driver ownership.

## Execution and failure handling

Native argument validation happens before GUI initialization. The server accepts only the eight explicit switching messages, alongside the existing panel and refresh messages. It dismisses an open panel, then schedules switching on a serial background queue. Window observation and switching share that queue so rapid commands cannot race one another. No new key detector is installed.

The controller queries live candidates and current Space, focuses a different Space only when necessary, verifies the transition, revalidates the target, focuses it, then verifies the actual focused window. Transition/focus polling is bounded to one second each and does not block the main UI thread. It uses the existing yabai connector without rewriting rendering or Space-switching UI code. There is no synthetic keyboard input, permission reset, or automatic retry after failure. A failed or disappearing target is logged and cancels the cycle; an already-completed Space transition is not undone automatically.

CLI success still means `ok queued`, not completed focus. Execution failures are recorded in YabaiSpaces logs. The two-second policy applies to processed commands; a delayed/busy backend may therefore lengthen perceived gesture timing.

## Verification and recovery

All 34 focused tests passed. Live checks verified `app next-in-space` and `window previous-in-space` switched windows 135 → 108 within Space 11; `app previous-across-spaces` and `window previous-across-spaces` switched window 1060 in Space 7 → window 1071 in Space 12. Application tests additionally verified the PID changed. Original window 1060 was restored. These checks observed actual yabai focus state, not merely socket acknowledgments or synthetic keys. SIP remained enabled and yabai animation duration remained zero. This is not exhaustive visual or physical-shortcut testing.

`python3 -m unittest test_window_switching test_native_commands test_panel_commands test_merge_regressions test_run` covers pure MRU selection, timeout/wraparound, app grouping, filtering, removal, empty lists, all eight native wire messages, and production controller execution with a fake backend. Controller tests exercise same-Space focus, cross-Space ordering, failed transitions, disappearing targets, focus timeout, and recovery after failure. Existing panel/transport/merge/launcher regressions remain included.

The isolated signed Debug build is `YabaiSpaces-build.De3uLb`. It passes strict verification against the installed app's designated signing requirement. Backup: `~/Library/Application Support/YabaiSpaces/Backups/window-switching-20260913.naJBcW/`, containing previous, original, and new signed apps. To roll back, quit YS and restore the previous app to `/Applications/YabaiSpaces.app`; no input configuration restoration is needed because none changed. The old binary does not support the new switching commands.
