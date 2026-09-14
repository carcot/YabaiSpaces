# Switching shortcut handoff (prepared, not activated)

The live bindings and installed YS app are unchanged. Signed build `YabaiSpaces-build.ree466` adds `YabaiSpaces space next-recent`; the installed De3uLb build does not yet accept that message. Do not load `migration/switching.skhdrc` into live skhd before deploying the new app and releasing the corresponding Hammerspoon bindings.

## Exact mapping

| Existing input | Native command | Behavior |
| --- | --- | --- |
| Option-F19 (Karabiner emits this for right-Option tap) | `window next-in-space` | Cycle individual windows in this Space |
| Command-L | `space next-recent` | Focus a window in a different recent Space |
| Command-period | `space next-recent` | Same recent-Space action |

The old Lua strings say `rightalt` and `rightcmd`, but Hammerspoon's installed `hs.hotkey.getMods` uses substring matching and normalizes these to unsided Option/Command. The proposed skhd rules deliberately preserve that existing behavior, including Command-L on either side. This is not an opportunity to silently change shortcuts. Keycode 0x2F is period.

Recent-Space selection reproduces the old `find_next_space` traversal: find the first current-Space entry in the frozen MRU list, then take the first later eligible window in another Space; if none, wrap to the first other-Space window. No other Space means no-op. It shares the two-second sliding cycling timeout but has a separate scope from all-window/all-application cycling. `app next-across-spaces` is not an equivalent replacement because it may remain on the current Space.

The Command-F19 prefix/modal and its application/Space selections remain in Hammerspoon. Right-Shift/F18, Hyper-Space, Caps, Tab, Karabiner and BTT remain untouched. YS keeps its own learned MRU order; Hammerspoon's private history is not transferred.

## Activation gate

`hs -c` could not access Hammerspoon's IPC message port. No Hammerspoon reload, AppleScript-enablement change, or permission reset was attempted. To permit a selective live handoff without restarting Hammerspoon, the user was asked to run `require('hs.ipc')` in Hammerspoon's Console. Activation awaits that step.

Once live control is available: back up both configs and the installed app; deploy the signed new app; verify the new command; remove only the direct cycle-mode definitions from the persistent Lua source; run the returned function in `migration/disable_legacy_switching.lua` inside Hammerspoon to exit those two modes and disable only Option-F19/Command-L/Command-period; add the supplied three rules to skhd and reload that daemon in place. Verify no duplicate owners and restore backups on failure. Do not reload the entire Hammerspoon configuration or remove its remaining modal handlers.

The handoff Lua passes `luac -p` and loads/executes with a fake Hammerspoon API, asserting the exact two mode exits and three disabled combinations. Shell commands in the skhd fragment pass `sh -n`; live skhd parsing/event dispatch is not yet tested. The separate signed Xcode build passes strict signature verification. Native tests cover the new Space command transport, different-Space selection, wraparound and no-op behavior alongside the previous suite. These are preparation checks, not proof of an activated shortcut migration.
