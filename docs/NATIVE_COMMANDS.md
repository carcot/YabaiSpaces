# Native YabaiSpaces commands

The application executable now handles commands before constructing the SwiftUI app or delegate. No Python process is needed. No arguments starts the normal app; a command sends one message to the existing app and exits without registering hotkeys, starting capture or replacing its socket. Invalid commands fail rather than launch the GUI. Legacy Finder process-serial-number arguments preserve normal startup.

```sh
/Applications/YabaiSpaces.app/Contents/MacOS/YabaiIndicator panel toggle
```

On this machine `/opt/homebrew/bin/YabaiSpaces` is a direct symlink to that executable, not another script:

```sh
YabaiSpaces panel toggle
YabaiSpaces panel activate-selected-or-show
YabaiSpaces --help
```

Other actions are `show`, `hide`, and `activate-selected`. Semantics and existing Hyper-Space/Hyper-F18 compatibility bindings are unchanged. For automation, use the full executable path and run it as a shell command, not `open -a ... --args`: Launch Services may not start a new command process when the app is already running.

## Current dispatch

skhd's only active F18 rule now is:

```text
f18 : /Applications/YabaiSpaces.app/Contents/MacOS/YabaiIndicator panel activate-selected-or-show
```

Karabiner still recognizes right-Shift taps. BetterTouchTool still sends Hyper-Space; its configuration was not edited. A future BTT shell action can call the executable with `panel toggle`. The old ysctl.py is retained for rollback and existing tests, but is no longer used by the live skhd binding. No new keyboard detector was added.

## Failure handling

Exit 0 means the server acknowledged queuing, not proof the panel changed. Exit 1 covers a missing server, rejected or missing reply, transport failures and timeout. Exit 2 is invalid usage. `--help` exits 0 without contacting the server. Missing-server errors never auto-launch YS. Do not automatically retry toggle or activation after a timeout: a command may have executed without its acknowledgment reaching the client.

The client uses the existing same-user Unix socket, rejects symlinks/non-sockets/wrong owners, verifies the connected peer UID, and limits replies to 128 bytes. Nonblocking connect/write/read share a three-second monotonic deadline. SIGPIPE is suppressed and descriptors close on exit. Server command validation and the five existing command messages are unchanged.

## Validation and deployment

Build a separate signed copy with `./run.sh --build-only`. Run `python3 -m unittest test_native_commands test_panel_commands test_merge_regressions test_run`: 31 tests cover the native client, argument parsing, help, missing servers, symlinks/non-sockets, all actions, partial/rejected/oversized replies, disconnects and timeout, plus prior command/merge/build-launcher regressions. Swift type checking, full Xcode build and strict matching signature verification passed for aJEclL. Native commands contacted the prior running app without another lasting UI instance. A missing-server call returned connection-refused exit 1; a broader process-name assertion failed and triggered rollback, so that particular process-count test was not treated as proof of clean startup behavior.

Twelve sequential hide calls per client measured native median 9.7 ms (first 10.5, maximum 12.4) versus Python median 28.1 ms (first 26.9, maximum 28.4). These are local warm-process-launch measurements including acknowledgment, not guaranteed gesture latency or cold-boot performance.

Installed aJEclL at `/Applications/YabaiSpaces.app`; native help and hide succeed and exactly one full app instance remained (PID 52205 at verification). skhd reloaded at PID 2401 with an active event tap. A synthesized F18 test encountered visible macOS permission dialogs for ChatGPT and did not establish physical dispatch success; dialogs were left unanswered and no further input synthesis was attempted. Direct socket commands passed. Physical right-Shift and post-install visual verification remain user checks.

Recovery directory: `~/Library/Application Support/YabaiSpaces/Backups/native-cli-20260913.vYncb5/` contains the old `skhdrc`, `previous-YabaiSpaces.app`, `original-installed.app`, and the new signed `YabaiSpaces.app`. Restore the old config and reload skhd before returning to the previous app. Quit the active app before replacing its bundle, and never run two GUI copies sharing this socket. Earlier main and pre-merge backups remain untouched. No TCC reset, iCloud change, driver change, Caps/Tab mapping change or MRU rewrite occurred.

Final status caveat: a later skhd status invocation reported Input Monitoring denied while still reporting the existing event tap active. Upstream service.zig queries IOHIDCheckAccess in the status process itself; this is not a direct query of daemon PID 2401's grant. No new matching daemon-revocation log was found. Therefore neither a working physical F18 route nor a revoked daemon grant is established. Stop synthetic input tests; leave the visible permission dialogs unanswered for the user. No reset, permission grant, skhd binary replacement or daemon restart was performed.
