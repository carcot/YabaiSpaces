# Caps Lock tap: native application/window prefix

## Prefix cleanup — 1.6.0

Caps-tap then period no longer cycles windows. During an active prefix, an unmodified period is consumed and dismisses the prefix without switching or typing punctuation. Outside the prefix, period is unaffected. `jump .` is rejected by the CLI and socket command parser. Configured letters and numbered Space jumps remain; Caps holds are unchanged. The prefix timeout is two seconds.

## Two-second timeout — 1.5.0

As of October 3, Caps-tap waits **two seconds** for the following key. Another Caps tap renews that interval. The session deadline and cleanup timer share one constant; selection at or after the deadline is rejected. Other key-handling and mapping behavior is unchanged. References to three seconds below describe earlier versions.

## Editable TOML configuration — 1.4.0

The active file is `~/.config/yabaispaces/config.toml`. On first launch, YS creates it with all existing application bindings if it does not exist; an existing file is never overwritten. The path is fixed under the user's home directory, independent of `XDG_CONFIG_HOME`.

```toml
[caps]
c = { app = "Brave Browser", space = 6 }
b = { app = "Brave Browser", space = 7 }
h = { app = "Brave Browser", space = 8 }
m = { app = "Messages" }
w = { app = "Word", match = "contains" }
q = { disabled = true }
```

Use **YS menu → Edit Caps bindings…**, save the file, then **Reload Caps bindings**. If no editor is associated with TOML, Edit reveals the file in Finder. Changes are not automatically watched. Reload does not rebuild or restart YS:

```sh
/Applications/YabaiSpaces.app/Contents/MacOS/YabaiIndicator config reload
```

The command returns success only after parsing and installing the new bindings, printing `Configuration reloaded`. On failure it exits nonzero; the menu reload action displays the detailed error and file path. Details are also logged for CLI reload failures.

Each lowercase letter `a`–`z` maps to one application, optionally constrained to a positive yabai Space index. Both conditions are kept in the same entry. No `space` means any Space. Matching is case-sensitive: `match = "exact"` is the default; `match = "contains"` enables substring matching. The generated file explicitly uses `contains` for the legacy unrestricted names (Word, Code, etc.) so installation preserves existing behavior. C/B/H keep exact app and Space matching. Window choice remains the most recently focused eligible match; no launching, moving, unhiding, or minimizing behavior is added.

**The file is the complete letter mapping, not a patch over defaults.** An omitted letter or `{ disabled = true }` consumes the key and dismisses the prefix without switching. Thus replacing the generated file with the short example above disables the other letters. Any letter, including former no-op Q/E/T/U/I/O, can now be assigned. Escape always cancels. Numbers, `-`, and `=` retain their built-in Space jumps and are not configurable here. Period dismisses without an action as of 1.6.0. The prefix timeout is two seconds; Caps-hold mappings are unchanged.

Validation rejects unknown tables/fields, duplicate TOML keys, non-letter keys, empty app names, invalid match modes, nonpositive/noninteger Spaces, and contradictory disabled bindings. Reload parses the entire regular UTF-8 file (maximum 64 KiB) before atomically publishing a replacement. A missing, malformed, or unreadable file leaves the current in-memory mapping untouched. At startup, if loading fails, YS logs the error and uses built-in defaults; last-good custom mappings are not persisted separately across restarts. An intentionally empty `[caps]` table disables all letter jumps. Symlinked configuration files and editor atomic-save replacements are supported.

Parsing uses the pinned MIT-licensed TOMLDecoder 0.4.5 package, not a custom TOML subset. Its license is bundled in app Resources. Main-thread key handling only takes an in-memory mapping snapshot; no config-file I/O is added to the event tap. Both physical prefix selections and CLI `jump` commands resolve through the same store; already-dispatched window commands retain their resolved target definition across later reloads.

Tests: `test_caps_configuration.py` compiles the production parser/store and exercises real TOML features, defaults parity, exact/contains + Space matching, MRU selection, invalid schema/syntax, missing/oversized files, symlinks, atomic replacement, and last-good retention. `test_native_commands.py` tests successful/error reload replies and malformed commands. Configuration tests resolve pinned dependencies by default; `YS_TOMLDECODER_SOURCE` can point at an already-resolved TOMLDecoder checkout to run offline. Deployment/live verification is recorded in `SESSION_LOG.md`.

## Keyboard behavior and default mappings (introduced in 1.2.1)

YS owns prefix timing, letter consumption and target-window selection. The existing Karabiner tap-only F20 emission and all Caps-hold mappings/exclusions remain unchanged. YS installs its event tap at startup and consumes unmodified F20 directly, arming the prefix synchronously in that callback. No skhd F20 binding is needed. The 1.2.0 shell/helper/socket route was removed because a following letter could arrive before YS started listening. The automation command `prefix start` remains available, but physical taps do not use it.

Tap Caps, then an unmodified mapped key within two seconds. A second Caps tap renews the timeout. Selection ends the prefix; Escape, period, or an unconfigured letter cancels it. Other unknown keys and modified chords pass through without selecting. Recognized key-down/repeat/key-up events are consumed so the selection is not typed into the application. There is no new prefix window. Native event-tap creation uses YS's existing permissions; failure logs an error and does not arm the prefix. Secure Input can prevent delivery.

| Key | Target |
| --- | --- |
| A, W | Word |
| S | Safari |
| D | Discord |
| F | Firefox |
| G | GoodNotes |
| C | Brave Browser, Space 6 |
| B | Brave Browser, Space 7 |
| H | Brave Browser, Space 8 |
| J | iTerm2 |
| K | kitty |
| L | Logseq |
| Z | zoom.us |
| X | Excel |
| V | Code |
| N | Signal |
| M | Messages |
| R | Friendly Streaming |
| Y | Spotify |
| P | PowerPoint |
| 1–9, 0, -, = | Spaces 1–9, 10, 11, 12 |
| . | Dismiss without switching (since 1.6.0) |
| Q, E, T, U, I, O | Dismiss without switching |

Application jumps select the most recently focused eligible matching window from YS's own window history. Unrestricted app names use the legacy case-sensitive substring match (e.g. Word matches Microsoft Word); Brave targets require the exact app name and specified yabai Space index. This reproduces the configured app/Space targets, not Hammerspoon's private historical order. Eligibility follows native switching: standard, non-hidden, non-minimized windows with valid IDs and Spaces. Missing targets are no-ops; YS does not launch apps, unhide them, or move windows. A jump ends any Command-tap cycling session. Cross-Space focus uses the same capture-before-departure and verified focus path as native navigation.

Automation equivalents use the installed executable with `prefix start`, `prefix cancel`, or `jump <key>`. Replies acknowledge queued work, not completion or target existence.

### Historical installation and verification

Current installation: signed build AQfHUr, version 1.2.1, PID 11833. Startup event-tap inspection verified the enabled key-down/key-up listener before sending any prefix command. A regression passes F20 down/up immediately followed by M down/up through the actual handler without a run-loop turn between them and confirms exactly one M selection. Eight focused tests passed; the full 37-test suite had passed for the preceding 1.2.0 implementation. Installed contents and strict signature were verified, and a native Messages jump focused window 108 on Space 11 during diagnosis. Physical Caps-M failure was not reproduced through the unavailable computer-use tool; the input timing gap is eliminated, but physical retesting remains necessary. Diagnostic output is retained at `/private/tmp/ys-caps-debug.log`.

The following describes the preceding 1.2.0 installation and handoff.

Signed build SJhPX0 (version 1.2.0) was installed and restarted as PID 1709. Matching signing requirements, byte-identical installed contents and strict signatures passed. Read-only `CGGetEventTapList` inspection verified YS's enabled key-down/key-up event tap (mask 3072). Native help/start/cancel commands were acknowledged. All 37 automated tests passed, covering prefix renewal/expiry, one-shot selection, key consumption, mappings, MRU/Space constraints, missing windows, controller execution, native transport and existing regressions. The computer-use tool could not start; physical Caps/letter routing and all real application targets still require user verification.

Only `require('caps-prefix')()` was removed from persistent Hammerspoon configuration. Its existing live `capsPrefixHotkey` was disabled and its modal exited, without reloading Hammerspoon or changing remaining handlers. skhd's normal reload command reported a missing PID file despite the daemon being alive. After checking the installed v0.2.0 source's reload implementation, its normal SIGUSR1 reload signal was sent directly to PID 2401. The same daemon remained running with an active event tap and granted Input Monitoring. Karabiner, Caps hold, other shortcuts and input services were not restarted or changed.

### Rollback

The 1.2.1 backup is `/private/tmp/ys-caps-direct.5PJ4hi/`, containing the previous 1.2.0 app and `skhdrc.original` with its helper-based F20 binding. To return to 1.2.0, stop YS, restore that app and skhdrc, reload skhd, then relaunch YS. The removed `migration/native-caps.skhdrc` snippet must not be installed for 1.2.1; native F20 handling supersedes it.

Backup `/private/tmp/ys-caps-install.Za5QZD/` contains the byte-verified previous `YabaiSpaces.app`, `skhdrc.original`, and `focus-window.original.lua`. Restore skhdrc and reload its running daemon first, cancel the YS prefix, then restore Hammerspoon's original file. In the existing Hammerspoon session, `capsPrefixHotkey:enable()` restores the retained old entry; after an Hammerspoon restart, load its restored configuration instead. Restore/restart the old app only after removing the native F20 binding. The old `caps-prefix.lua` adapter remains on disk for rollback but is no longer required by the active config.

## Historical Hammerspoon prefix (September 14)

On September 14, the user requested the old Command-tap-then-letter behavior on Caps Lock tap, explicitly preserving all existing app-specific hold behavior.

The three existing Karabiner Caps manipulators now emit unmodified F20 in `to_if_alone`. Their `from`, `to`, conditions and parameters remain structurally identical:

- Terminal rules: hold remains Right Control; tap no longer sends Escape.
- Screen Sharing rule: hold remains Right Control; tap now emits F20.
- General rule: hold remains Left Command; tap changes from F19 to F20.

Existing app exclusions were intentionally retained. In particular, Emacs/Portacle were excluded from the general rule and not matched by the terminal list; this change does not invent a new Caps hold mapping in those apps. Other keys and Karabiner rules are untouched. Physical Caps tap recognition was not part of the synthetic signal test.

`~/.hammerspoon/caps-prefix.lua` is an exact copy of `migration/caps-prefix.lua`. It registers F20 to enter the existing `rightcmdf19` modal, preserving its original letter/number actions and three-second timeout. A repeated tap renews that timeout. The persistent `focus-window.lua` now calls `require('caps-prefix')()` immediately after creating the modal. The adapter was also loaded into the running Hammerspoon instance without a configuration reload or history reset.

This prefix still uses Hammerspoon for its existing application/window actions. It is not a new YS keyboard detector or a completed migration of those actions to skhd. Command single-tap and the previously migrated switching shortcuts remain skhd → YS. The old Command-triggered prefix entry remains disabled.

Validation: Karabiner JSON parsed; all three Caps `to_if_alone` changes were checked against backup while asserting all remaining manipulator fields unchanged. Adapter passed Lua syntax compilation and live loading. Synthetic F20 entered the mode, the original Q no-op action exited it, and another F20 timed out after three seconds. These tests verify signal dispatch and modal behavior, not every application-selection action or physical Caps tapping.

Backup: `~/Library/Application Support/YabaiSpaces/Backups/caps-prefix-20260914.2C8KBM/` contains the preceding karabiner.json and focus-window.lua. For rollback, disable `capsPrefixHotkey`, exit `rightcmdf19`, restore both backed-up configs, and remove the added caps-prefix.lua module. No app rebuild or signing/permission changes are involved.
