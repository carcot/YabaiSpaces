# Semantic panel commands

## Native sender

The live skhd binding now calls the YS executable directly; Python is no longer in that route. See NATIVE_COMMANDS.md for invocation, the direct YabaiSpaces symlink, exit codes, validation and rollback. The old helper and deployment entries below are historical; the five wire commands are unchanged.

## Current installation

Merged main build 4kQMoP is now installed after the controlled test described in SESSION_LOG.md and WORKING_BASELINE.md. The command protocol and physical F18 binding below are unchanged. The earlier VdlD77 confirmation remains a historical user test, not a claim that every physical input or thumbnail was retested after the merge.

## Confirmed current state — September 13

The user physically verified right-Shift opens the panel and a second tap activates the selection after skhd deployment. After restoring the historical full-display capture implementation in build VdlD77, the user also confirmed Desktop icons render again. That build is installed at `/Applications/YabaiSpaces.app`. These confirmations supersede the pending-verification statements in the earlier entries below. The same semantic commands and F18 binding remain in use.

## Deployment — September 13

The user confirmed that the repeated controlled test closed the panel and activated the highlighted Space. The sampled active Space changed from index 8 to 5. Installed that exact signed lQCqv5 build at `/Applications/YabaiSpaces.app`; strict signature and matching designated-requirement checks passed before installation. The installed app acknowledged hide and activate-selected commands. The latter was sent while closed, without intentionally changing Spaces.

The sole active skhd binding now is:

```text
f18 : /opt/homebrew/bin/python3 /Users/carlcotner/dev/YabaiIndicator/ysctl.py panel activate-selected-or-show
```

Karabiner still detects a right-Shift tap and emits F18; skhd now dispatches the semantic command rather than synthesizing Hyper-F18. YS retains ownership of panel visibility and selection. The compatibility Hyper-F18 handler remains available. BetterTouchTool, MRU, previous-Space, Caps, Tab, and Karabiner settings were not edited. SIP remains enabled and yabai animation duration is zero.

Nine command tests passed again. Helper syntax/import and the binding command's shell syntax passed; a comparison confirmed that only the F18 binding line changed. skhd reloaded in place (PID 2401) and reported an active event tap with no skhd grabber running. Physical right-Shift dispatch and post-install thumbnail/cursor behavior still need user confirmation; acknowledgment and service status are not visual verification. TCC logs include an AppleEvents entitlement warning; no entitlements or permission grants were changed during deployment.

Rollback files are outside iCloud at `/Users/carlcotner/Library/Application Support/YabaiSpaces/Backups/deploy-20260913.yiAot8/`: `skhdrc`, a verified `YabaiSpaces.app` copy, and `replaced-original.app` (the original installed bundle). To roll back, first restore the saved skhdrc and reload skhd, then quit the installed app, preserve the new bundle separately, restore the saved app to `/Applications/YabaiSpaces.app`, and launch that exact path. Do not launch a backup alongside the installed app because they share a socket and identity. The earlier confirmed baseline archive remains untouched.

The following test notes describe the earlier pre-deployment state and are superseded by this deployment entry.

## Controlled live test — September 13

Temporarily launched the signed lQCqv5 build (PID 62205), then restored the unchanged `/Applications/YabaiSpaces.app`. All five commands acknowledged successfully. The hide/activate-while-closed, activate-or-show, repeated-show, activation, and double-toggle sequence produced no change to the active Space sampled during that sequence. This is not proof of visual panel transitions: yabai did not enumerate the nonactivating panel, and visual confirmation is still pending.

Live invalid-name, combined-message, oversized-request rejection and legacy refresh acknowledgment passed. An idle connection received rejection after 2.0 seconds. Socket mode was 0600. macOS TCC logged ScreenCapture authorization value 2 for the test process; no authorization reset or new grant was performed. No live skhd or BetterTouchTool binding was changed. This test does not yet validate a selected different Space/window activation, cursor placement or thumbnail content.

Implemented in source and tested in an isolated build; not deployed to the daily-use application or live skhd/BetterTouchTool bindings.

## Messages

| Message | Closed panel | Open panel |
| --- | --- | --- |
| `panel show` | Show | No change |
| `panel hide` | No change | Hide without activation |
| `panel toggle` | Show | Hide without activation |
| `panel activate-selected` | No change | Run the existing Return action and close |
| `panel activate-selected-or-show` | Show | Run the existing Return action and close |

Activation reuses the current selection implementation; it adds no new window-selection behavior. Showing uses the same saved positioning and cursor behavior as existing hotkeys. Visibility is evaluated on the main actor when the command executes, avoiding a client-side query/action race. Existing Hyper-Space and Hyper-F18 bindings remain compatible during migration.

## Helper

Invoke with a Python 3 interpreter, for example:

```sh
python3 /Users/carlcotner/dev/YabaiIndicator/ysctl.py panel activate-selected-or-show
```

When installing a skhd binding, use the verified absolute Python interpreter path rather than assuming skhd's PATH. Do not install that binding until the new application is deployed and physically tested. The currently running older app does not acknowledge these commands.

The helper never launches, stops, or selects an application bundle. It reports missing sockets, rejection, timeout, and absent acknowledgment as failures (exit 1); usage errors exit 2. Exit 0 means queued, not visually verified. Do not automatically retry activation/toggle after a timeout: an unacknowledged command may already have executed.

## Transport

Uses the existing `/tmp/yabai-indicator.socket`, restricted to mode 0600 and peers with the server's user ID. The helper rejects non-socket paths and sockets owned by another user. Messages are UTF-8, one newline-terminated command per connection (EOF termination also accepted for compatibility). Reads are limited to 256 bytes and two seconds per connection; helper operations have a three-second deadline and responses are limited to 128 bytes. This is a local same-user interface, not a network service or a shell evaluator.

Replies: `ok queued\n` or `error invalid-command\n`. Existing `refresh`, `refresh spaces`, and `refresh windows` messages remain supported. Acknowledgments indicate dispatch was queued, not that UI execution finished. Invalid/oversized/incomplete messages are rejected; no arbitrary shell commands are accepted. The listener serves connections serially, so a stalled local client can delay later clients by up to the read deadline.

## Validation and deployment boundary

Run `python3 test_panel_commands.py`. Nine tests cover helper success/rejection, old servers, oversized replies, timeout, missing/non-socket paths, invalid commands, all ten open/closed action outcomes, exact command parsing, legacy refresh, EOF framing, invalid UTF-8, oversized requests, multiple-command rejection and idle-read timeout. The Swift harness compiles the production command enum and extracts the production read routine; it does not launch YS or simulate key presses. Actual main-actor UI execution and cross-user peer rejection still require integration verification.

Full isolated Xcode build and strict matching designated-requirement verification passed. They do not prove Screen Recording authorization survives deployment. The running `/Applications/YabaiSpaces.app` and input settings were not changed.

The shelved capture experiments are preserved in `~/Library/Application Support/YabaiSpaces/Backups/confirmed-20260913.qZ8UzV/source-review.tar.gz` and `source-changes.patch`. PrivateWindowCapture was restored to the pre-experiment HEAD contents; only the experimental thumbnail task property/block was removed from YabaiAppDelegate. Other existing changes were retained. This does not claim that the checkout exactly reproduces every aspect of the working binary; rendering must be checked before deployment.
