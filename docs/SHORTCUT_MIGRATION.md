# Switching shortcut handoff (active September 14, 2026)

Signed build `YabaiSpaces-build.ree466` is installed. The three rules from `migration/switching.skhdrc` are active in the user's skhdrc. Their old Hammerspoon cycle-mode definitions were removed from persistent `~/.hammerspoon/focus-window.lua`, and only those three handlers were disabled in the running Hammerspoon process. No Hammerspoon reload occurred. Its remaining hotkeys were compared before/after and all remained enabled.

Backup: `~/Library/Application Support/YabaiSpaces/Backups/shortcut-handoff-20260914.K1EhLx/` contains the original skhdrc, original focus-window.lua, and previous/original signed YS app copies. The replacement app passed strict verification against the previous app's designated signing requirement.

## Exact mapping

| Existing input | Native command | Behavior |
| --- | --- | --- |
| Option-F19 (Karabiner emits this for right-Option tap) | `window next-in-space` | Cycle individual windows in this Space |
| Command-L | `space next-recent` | Focus a window in a different recent Space |
| Command-period | `space next-recent` | Same recent-Space action |

The old Lua strings say `rightalt` and `rightcmd`, but Hammerspoon's installed `hs.hotkey.getMods` uses substring matching and normalizes these to unsided Option/Command. The proposed skhd rules deliberately preserve that existing behavior, including Command-L on either side. This is not an opportunity to silently change shortcuts. Keycode 0x2F is period.

Recent-Space selection reproduces the old `find_next_space` traversal: find the first current-Space entry in the frozen MRU list, then take the first later eligible window in another Space; if none, wrap to the first other-Space window. No other Space means no-op. It shares the two-second sliding cycling timeout but has a separate scope from all-window/all-application cycling. `app next-across-spaces` is not an equivalent replacement because it may remain on the current Space.

The Command-F19 prefix/modal and its application/Space selections remain in Hammerspoon. Right-Shift/F18, Hyper-Space, Caps, Tab, Karabiner and BTT remain untouched. YS keeps its own learned MRU order; Hammerspoon's private history is not transferred.

## Activation history

Initially `hs -c` could not access Hammerspoon's IPC message port. The user ran `require('hs.ipc')` in its Console, and live control was then verified. No Hammerspoon reload, AppleScript-enablement change, or permission reset was performed. IPC was not added to startup configuration.

Activation backed up both configs and the app, deployed the signed app, removed only the persistent direct cycle-mode section (from `cycle_windows_in_space_mode = hs.hotkey.modal.new()` up to, but not including, `return windowCache`), ran `migration/disable_legacy_switching.lua`, and added the supplied rules to skhd. skhd reloaded in place as PID 2401. It reported an active event tap and Input Monitoring granted. The existing F18 panel rule was unchanged. Before disabling, the three active Hammerspoon hotkey objects were retained in `ysShortcutRollbackHotkeys` for selective live recovery.

The handoff Lua passes `luac -p` and loads/executes with a fake Hammerspoon API, asserting the exact two mode exits and three disabled combinations. Homebrew Lua 5.5 rejects an unrelated pre-existing assignment to a loop variable in focus-window.lua; Hammerspoon's own `loadfile` successfully compiled the edited complete file without executing/reloading it. Shell actions passed `sh -n`, and live skhd dispatch passed all three tests: Option-F19 focused window 1056 → 1060 within Space 7; Command-L and Command-period each focused 1056 → 3880, Space 7 → 8. These tests synthesized the actual bound chords through skhd and checked yabai's focused window and Space, rather than only sending native commands. Original window 1056 was restored. Physical right-Option tapping itself was not retested; its Karabiner mapping is unchanged. The 34-test suite and signed build passed during preparation.

## Rollback

Restore the backed-up skhdrc and reload skhd first to release these keys. Restore the backed-up focus-window.lua. In the same Hammerspoon session, re-enable the retained objects with `for _, binding in ipairs(ysShortcutRollbackHotkeys) do binding:enable() end`; if Hammerspoon has since restarted, restoring and loading its old configuration is necessary instead. The previous YS app can then be restored while YS is stopped; it does not implement `space next-recent`. Do not restore the old binary while the new skhd Space bindings remain active.
