# Session Log

## 2026-09-13: Shortcut migration prepared; live handoff awaits Hammerspoon IPC

Inspected current skhd, Karabiner and loaded Hammerspoon source before changing live configuration. The direct shortcuts are Option-F19 for window cycling and Command-L/period for recent-Space navigation. Hammerspoon normalizes the apparent right-side modifier strings to unsided modifiers; preserve that actual behavior. Added a separate space next-recent semantic command reproducing the existing other-Space traversal rather than misbinding those shortcuts to app/window next-across-spaces. The prefix/modal bindings remain out of this direct-shortcut migration.

Added staged skhd rules and a selectively disabling Lua handoff with syntax/loading tests. Immediate Swift syntax/type checks, Python compilation/import and separate signed build ree466 succeeded. No installed app, live skhd config, Hammerspoon config, permission setting or input service was changed. Hammerspoon IPC is not loaded, so requested that the user run require('hs.ipc') in its Console; this allows releasing only migrated handlers without restarting Hammerspoon or resetting its history. See docs/SHORTCUT_MIGRATION.md for exact mapping, validation boundaries and activation order. Migration is not yet active.

## 2026-09-13: Native application/window switching added

Final verification: all 34 focused tests passed. Live application/window commands switched within Space 11 (135 → 108) and across Spaces 7 → 12 (1060 → 1071), verified through yabai focus queries, with original window 1060 restored. Application-mode tests verified different PIDs. SIP remains enabled; window_animation_duration remains 0.000000. Documentation whitespace checks passed. No physical shortcuts were remapped, and no exhaustive rendering/physical-key verification is claimed for this build.

User requested switching applications within and across Spaces. Inspected the loaded Hammerspoon focus-window.lua: in-Space cycling freezes MRU ordering with a two-second sliding deadline, while next-Space navigation is a distinct behavior. Added eight allowlisted app/window next/previous commands for current/all-Space scope. Application mode groups by PID; window mode includes each eligible window. Kept Hammerspoon and all input bindings untouched rather than silently replacing their history or repurposing shortcuts. YS maintains its own observed MRU history, seeded from the startup yabai query; it does not claim to preserve Hammerspoon's historical ordering across processes.

Added a separately testable selection engine and serialized background execution using the existing yabai connector. Focus transitions are verified, targets revalidated, and failures cancel cycling without injecting keys or opening permission dialogs. Existing window-refresh events feed observations. Rendering, native panel semantics, previous-Space, Caps, terminal Tab and BTT remain unchanged. See docs/WINDOW_SWITCHING.md for exact scope and limitations.

Each Swift edit passed syntax parsing; the pure engine/parser passed type checking, Python tests passed compilation/import, and Xcode project plist validation passed. Isolated build De3uLb succeeded and was installed after matching designated-requirement verification and byte-verified backup at window-switching-20260913.naJBcW. The first signature-check invocation omitted codesign's inline requirement prefix; it failed before the running app was touched, then was corrected. Installation replaced only YS and verified one installed GUI process (PID 10000) plus native help/panel acknowledgment. No input services were reloaded.

An initial live test verified switching applications within Space 11. The test helper then asked yabai to focus an already-current Space and failed; the original window was restored. Corrected the helper to skip redundant Space-focus requests, as the production controller already does. This was a test-helper issue, not a product change.

## 2026-09-13: Physical right-Shift confirmed; proposed window-switching phase

After the native command migration, the user explicitly confirmed: "Right-shift is working right now." This verifies the physical right-Shift → Karabiner F18 → skhd → native YabaiSpaces command route in current use. A retry of synthetic F18 did not visibly open the panel, whereas a direct native show command did. The synthetic test is inconclusive, not evidence that the working physical shortcut is broken. This confirmation supersedes the earlier physical-input-unverified caveats; it does not establish the cause of the status subprocess's permission report or constitute exhaustive keyboard testing. No permission reset or configuration change was needed.

Proposed next capability, not implemented: switching between windows within the current Space and across Spaces. Use windows rather than applications as the selection unit because one application can have windows in multiple Spaces. First inspect the existing timed MRU implementation, repeated-press cycling/reset rules, and previous-Space behavior. Preserve those semantics rather than invent replacements. YS should own target-window selection, activation, and any required Space transition; skhd should only dispatch semantic commands. Command names and shortcuts remain undecided pending that inspection. No new window-switching behavior or key bindings were introduced by this discussion.

Verification for this documentation-only update: user-reported physical input success and direct-command visual observation are distinguished from inconclusive synthetic input. Documentation whitespace checks passed; no executable code changed or build was required.

## 2026-09-13: Native application command mode replaces live Python dispatch

Publication housekeeping: the Debug executable populated a previously tracked empty default.profraw during command testing. Removed that generated coverage file from tracking and ignored profraw/profdata outputs; no executable source changes were needed. The local profiling output may remain on disk, but is not a source artifact.

Final verification caveat: the CLI skhd status probe changed from Input Monitoring unknown to denied, while the same daemon still reported an active event tap. Source inspection shows that permission query runs in the status subprocess, not directly in daemon PID 2401. No fresh daemon-revocation diagnostic was found. Physical input remains unverified; no further synthetic events, TCC reset or permission grants were attempted. The native hide command still succeeds. All 31 tests passed again. This caveat qualifies the earlier healthy-status statements below.

User requested YS itself accept panel commands without normal GUI startup and authorized autonomous implementation. Added YabaiEntryPoint to dispatch arguments before constructing the SwiftUI App/delegate, and PanelCommandClient with bounded same-user Unix-socket transport. No-argument GUI behavior and all panel messages are preserved. Native help, invalid arguments and socket errors exit rather than create another GUI. The helper does not auto-launch or retry. Added the client to the Xcode target and 11 native tests; all 31 focused tests passed alongside immediate Swift parsing/type checking, Python compilation/import, project plist validation and full signed build aJEclL.

Native command calls to the existing instance measured median 9.7 ms versus Python 28.1 ms over 12 hide calls each. These measure process launch through acknowledgment, not display animation. The no-server command returned exit 1 as intended, but an overly broad process assertion triggered the first installation rollback. While inspecting that rollback, invoking --help on the old app (which lacks native CLI handling) started an extra GUI; that exact process was stopped, and final installation restored a single native-capable instance. No assumption that old builds understand CLI arguments should be made.

Installed the verified native build at /Applications/YabaiSpaces.app as PID 52205, with complete old/new signed app backups and original skhdrc in ~/Library/Application Support/YabaiSpaces/Backups/native-cli-20260913.vYncb5/. Changed only skhd's F18 command to the full native executable path, validated shell syntax, and reloaded the same healthy event-tap process. Added /opt/homebrew/bin/YabaiSpaces as a direct executable symlink, not a wrapper. Native help/hide work after installation. Retained ysctl.py only for rollback and old tests, not the live input route. BetterTouchTool Hyper-Space, Hyper-F18 compatibility, Karabiner, Caps, Tab, MRU, previous-Space and rendering code remain unchanged.

A synthesized F18 test encountered visible macOS permission dialogs for ChatGPT and did not prove the physical route worked. Left dialogs unanswered and stopped further input synthesis. Physical right-Shift and post-install visual behavior still require user verification; native commands and daemon health are verified. No TCC reset or permission grant was performed. See docs/NATIVE_COMMANDS.md for semantics, benchmarks, validation boundaries and rollback. Documentation whitespace checks passed.

## 2026-09-13: Main live test, stable installation and keyboard audit

User requested execution of the controlled test and then continued work. Verified a fresh copy of the previously confirmed app at pre-main-test-20260913.ldsJgA, then launched merged build 4kQMoP. Semantic show/hide/activate-selected-or-show/activate-selected exchanges acknowledged; skhd remained PID 2401 with its event tap active. Initial screenshot missed the panel during concurrent user focus changes; an immediate screenshot showed the panel, centered pointer, actual current-Space content and expected outline fallbacks on uncached Spaces. Framework IOSurface errors were present in startup logs, so no claim of an error-free log or exhaustive rendering verification is made.

Installed that exact signed build at /Applications/YabaiSpaces.app, stopped the temporary instance, and verified one installed instance (PID 44764) plus command acknowledgment. Byte comparison and strict signatures passed for the staged and recovery copies. Backup directory: ~/Library/Application Support/YabaiSpaces/Backups/main-installed-20260913.YptHIB/ (YabaiSpaces.app is the new build; previous-YabaiSpaces.app is the prior daily app). No binding, TCC, iCloud, MRU or previous-Space changes.

Audited remaining registrations: both default global hotkeys use Carbon; ComposableHotkey's specialized tap/hold detector is dormant. Panel-local navigation/dismissal monitors remain necessary. Recorded active and dormant paths in docs/KEYBOARD_HANDLERS.md. No handler removal was performed. Documentation whitespace validation passed; source is unchanged from tested main dcc537f2. Full physical-input and multi-Space visual verification remain distinct from this audit and screenshot.

## 2026-09-13: Approved main integration

The user explicitly approved resolving the conflicts, rebuilding/testing and publishing to main. Merged the documented tested checkpoint with GitHub main 682b4d8 without rewriting either history. Preserved main's throwing Yabai client and matching call-site error handling, release metadata and existing artifacts; retained the tested full-display thumbnail method, same-user semantic socket commands, Hyper-F18 compatibility and Hyper-Space toggle behavior. Kept the newer Serena configuration comments and Python bytecode exclusions.

Reviewed automatic merges as well as explicit conflicts. The first build caught duplicated C timeout setup; removed the redundant block and immediately verified C syntax. Review also caught two Swift defer blocks freeing the same buffers; retained one cleanup block and immediately parsed the file. Added four structural regression guards covering those duplicates, display capture and the compatibility bindings. These complement, rather than replace, live visual testing. All 20 focused tests passed; Python compilation/import, shell syntax and Swift parsing passed. The final isolated build is checked before commit/publication. A GitHub push dry run succeeded as a fast-forward to main using existing HTTPS credentials; no force push is needed.

Final isolated build 4kQMoP succeeded and passed strict signing verification. The installed app remains PID 82181. This supersedes the earlier blocked-publication note. The merged source incorporates existing main changes beyond installed VdlD77, so it is not claimed byte-identical to that user-tested app. No merged build was installed or launched; the working desktop and input services remain untouched. The old release DMGs are retained, not rebuilt or relabeled as this source revision. No new release tag is created. Credential rotation remains a separate outstanding security action.

## 2026-09-13: Local commit complete; main publication blocked by merge review

Saved all reviewed project changes in commit 5bb87013, excluding generated bytecode. The user requested main remain the publication/release branch rather than using a new branch. Created a local jj merge with GitHub main 682b4d8; it has nine conflicts, including window-query, view, image-generation, capture and app-delegate code. Broad conflict resolution was rejected by the automated safety review because it could introduce behavior changes beyond publishing the tested state. No conflicting code was compiled, installed or launched.

Restored the working directory to a clean child of tested commit 5bb87013. The unresolved merge is retained separately in jj for review; no existing release history was overwritten. Main was not advanced and nothing was pushed. Further publication requires explicit approval for careful source integration and testing, or approval to publish the tested commit on a separate branch. The installed user-confirmed app and all live input settings remain unchanged.

## 2026-09-13: Publication preparation and confirmed working state

User confirmed the installed skhd F18 command route opens the panel and activates its selection. User subsequently confirmed Desktop icons render after deploying VdlD77. Updated current-state documentation to supersede earlier pending-verification notes. Preserved all project changes, including the preexisting Serena configuration and logging changes; excluded generated Python bytecode. The live skhd rule is documented in docs/PANEL_COMMANDS.md; unrelated machine configuration and credentials are not source artifacts.

Recorded the driver-protocol incompatibility, diagnostic hang and competing-grabber findings in docs/SKHD_GRABBER_RESEARCH.md with primary sources. No upstream fix date was found; migration remains deferred. Remaining work is auditing redundant YS keyboard handlers and creating a new durable archive of the latest confirmed app, not changing rendering, MRU, previous-Space, Caps or Tab behavior.

Publication checks: all four changed Swift files parse; run.sh passes bash syntax validation; all three Python files compile and import; all 16 focused tests pass. The exact capture/command source previously passed the full isolated Xcode build and user visual testing. Documentation whitespace checks pass. This publication operation does not rebuild, reinstall or restart the working desktop services.

Removed an embedded authentication token from the local fork remote URL without recording its value. Token revocation/rotation is still required; changing the URL does not revoke it. SSH authentication to origin failed; clean HTTPS fetch from fork succeeded. GitHub main differs from this detached tested checkout, so a separate publication branch was proposed rather than rewriting main or merging unrelated release/build changes. Commit and push outcomes must be verified separately.

## 2026-09-13: Restore omitted historical Desktop-icon capture fix

After semantic-command deployment the user reported missing Desktop icons in thumbnails. That build used the detached checkout's wallpaper-plus-yabai-windows compositor, which excludes Finder Desktop icons. The deployment had not preserved the display-capture fix already present in Git commits 5ef0524 and 5b56676. Successful panel activation was not sufficient rendering regression coverage.

Restored only the historical captureSpace implementation: CGDisplayCreateImage for the visible display, scale, immediately encode PNG Data. No private per-window capture is used by this method now. Kept all semantic commands, existing capture timing, panel selection, keyboard bindings and MRU behavior unchanged. Did not touch Finder, Desktop files, iCloud, or TCC grants. This is restoration of an existing implementation, not another capture-framework experiment.

Swift syntax validation passed immediately after the edit. Full isolated signed build VdlD77 succeeded; all nine panel-command tests passed. Installed that exact build at /Applications/YabaiSpaces.app after strict matching-signature and staged byte-comparison checks; restarted as PID 82181 and verified the command socket. Previous semantic-command app retained at ~/Library/Application Support/YabaiSpaces/Backups/icons-20260913.zY2L1M/YabaiSpaces.app. Earlier confirmed baseline backups are unchanged. Actual Desktop-icon pixels still require user confirmation; builds and socket acknowledgments do not establish visual success. Thumbnails are in memory and regenerate as each active Space is captured when opening the panel.

## 2026-09-13: Deploy semantic panel dispatch after user-confirmed activation

Repeated the controlled panel test with a 30-second selection interval. Active Space changed from index 8 to 5, and the user confirmed the panel closed and activated the highlighted Space. On explicit deployment authorization, installed the exact tested lQCqv5 bundle at `/Applications/YabaiSpaces.app`. Verified strict signing, matching designated requirement, and staged byte comparison before replacement. Retained verified old app and config backups under `~/Library/Application Support/YabaiSpaces/Backups/deploy-20260913.yiAot8/`; earlier baseline archive remains unchanged.

Replaced only `f18 | hyper - f18` with the absolute Python/helper invocation of `panel activate-selected-or-show`. Karabiner still recognizes right-Shift taps; skhd dispatches semantic intent; YS owns visibility and selection. No BTT, MRU, previous-Space, Caps, Tab, Hammerspoon, grabber, or iCloud changes. No source rebuild or commit. SIP enabled; yabai animation duration zero.

Nine automated command tests passed again. Validated helper syntax/import, shell syntax, and exact single-line config replacement immediately after editing. Reloaded the same skhd PID 2401; status reports an active event tap and no grabber. Installed YS PID 67743 acknowledged hide and closed-panel activation commands and passed strict signing verification. Physical right-Shift dispatch and post-install visual behavior remain user checks. TCC logs include an AppleEvents entitlement warning; no permission reset or entitlement edits were made. Documentation whitespace checks passed. See docs/PANEL_COMMANDS.md for rollback instructions and verification boundaries.

## 2026-09-13: Controlled live panel-command test; baseline restored

User requested testing. Verified matching signing requirement, gracefully stopped baseline PID 57400, and launched lQCqv5 as PID 62205. All five panel commands acknowledged. Tested invalid old command name, multiple commands in one frame, oversized frame, refresh windows compatibility and idle read timeout against the live server: expected replies, with idle rejection at 2.0 seconds. Socket was mode 0600. TCC logged authorized ScreenCapture results for the test build; no permission resets or grants occurred.

The activation/toggle sequence left the active Space unchanged as expected when activating the initial current-Space selection. Actual visible panel transitions, cursor behavior, screenshots and activation of another selected target remain unverified: yabai does not enumerate this panel, and the user has not yet supplied visual confirmation. Do not describe acknowledgment alone as full UI success.

Stopped the test process and restored `/Applications/YabaiSpaces.app`. Its bundle and all live bindings remain unchanged; nothing was installed. See docs/PANEL_COMMANDS.md for exact test coverage. Documentation whitespace checks passed.

## 2026-09-13: Semantic panel socket commands implemented, not deployed

Implemented show, hide, toggle, activate-selected and activate-selected-or-show messages on the existing local socket. Exact allowlisted commands resolve panel visibility on the main actor and reuse existing show/hide/Return behavior. Added same-user peer checks, 0600 socket mode, bounded/deadlined reads and queued/error acknowledgments. Existing refresh messages and high-level hotkeys remain compatible. Added ysctl.py with no app auto-launch, bounded acknowledgment reads and explicit failures.

Before building, restored PrivateWindowCapture to HEAD and removed only the experimental asynchronous thumbnail property/block from YabaiAppDelegate. The capture experiments are retained in the previously checksum-verified baseline backup; right-Shift and prior logging changes remain. This supersedes the WORKING_BASELINE inventory's statement that capture experiments remain in active source. No branch/reset/commit was performed.

Immediate Swift/Python syntax checks and Python import checks passed. Nine automated tests passed, including real local fake-server exchanges and a compiled Swift harness for production dispatch decisions and framing. The first test run caught shutdown racing a server close; removed unnecessary shutdown from the newline-framed helper and reran successfully. Full isolated build lQCqv5 succeeded and passed strict matching designated-requirement verification. No live panel commands were sent; PID 57400 still runs the unchanged Applications app and skhd still forwards F18 to Hyper-F18. Physical UI behavior and Screen Recording authorization remain deployment checks. See docs/PANEL_COMMANDS.md for protocol, limitations and invocation.

## 2026-09-13: Freeze user-confirmed working binary; no further experiments

User confirms the current app works and requests preservation plus source review. Verified PID 57400 runs `/Applications/YabaiSpaces.app`. Archived the exact signed bundle outside iCloud at `~/Library/Application Support/YabaiSpaces/Backups/confirmed-20260913.qZ8UzV/YabaiSpaces-working.zip`. Extracted backup, recursive comparison and strict signature validation passed. Archived current tracked diff and selected changed/untracked sources separately, with SHA-256 checksums.

`docs/WORKING_BASELINE.md` records binary identity, backup location and mixed-source inventory. Capture experiments remain in the working tree, explicitly not validated for deployment; right-Shift and logging changes must not be removed with them wholesale. The earlier capture-restoration plan is paused. No app restart, build, branch change, source-code edit, permission reset or input/iCloud change occurred. Documentation whitespace validation passed.

## 2026-09-13: ScreenCaptureKit thumbnail migration under live test

User reported white window rectangles after the ABI correction. Those rectangles were the explicit capture-failure fallback, not captured content; the previous change did not resolve screenshots. On macOS 14+, now use SCShareableContent and SCScreenshotManager with desktop-independent window filters, stable window IDs, thumbnail-sized output, no cursor and no window shadows. Missing permission, missing windows, or capture errors return no new thumbnail and are logged. The compositor no longer caches white placeholders. Older systems retain the corrected legacy call.

Capture requests are asynchronous so panel opening and navigation do not wait for screenshots. Each request keeps its originating Space ID and window list. A newer request for the same Space cancels the previous task and canceled results cannot overwrite the cache. This changes snapshot timing: pixels are obtained asynchronously, not guaranteed at the exact instant before switching. No MRU or Space-switching commands were changed. Existing outline fallback remains while no thumbnail is available.

Immediate Swift parsing and isolated full Xcode build passed. Strict signing matched the existing daily-use designated requirement. The temporary UXVaHH build was launched for live testing; the previous temporary build, original DerivedData bundle and Applications copy remain untouched. Actual screenshot content and panel responsiveness remain user-verification items, not established by compilation. No permission prompts were accepted automatically and no input or iCloud settings changed.

## 2026-09-13: Correct capture ABI; live preview verification pending

The installed SDK's CGWindow.h declares CGWindowListCreateImage with four arguments (CGRect, list options, window ID, image options). PrivateWindowCapture incorrectly cast that symbol to a three-argument function taking a CFArray. Corrected the ABI, used explicit single-window options, and adopted retained ownership for the Create result. Removed fallback symbol guesses with unverified signatures. Capture now uses the window's global top-left bounds, with display-relative flipped coordinates only for compositing; composites traverse back-to-front.

Swift syntax validation ran after each edit. The first build caught an unavailable `.default` option spelling; it was replaced with an empty option set and the full isolated Xcode build then passed. Strict signature verification passed against the prior daily-use app's designated requirement. Launched the isolated build from `YabaiSpaces-build.a3GVNa` after gracefully stopping the prior process. Original DerivedData and Applications bundles remain unchanged for rollback. No input or iCloud settings changed.

This fixes a verified ABI defect, not yet a verified end-to-end rendering failure. Missing outlines may have another cause; yabai currently returns window geometry and USER is set in the app environment. Visual capture/outline validation is pending. Do not promote this temporary build to daily-use installation until verified.

## 2026-09-12: Stable daily-use application staged

After the user confirmed the panel worked again, copied the verified signed DerivedData app to the previously absent `/Applications/YabaiSpaces.app` and registered that exact bundle with Launch Services. No rebuild, process restart, login-item change, or input configuration change occurred in this installation step. Recursive file comparison and strict signature verification passed; designated requirements match. The running process remains the working DerivedData instance. Launch from Applications still needs functional verification.

The earlier panel failure followed another task launching the repository's March app with identifier `de.arsbrevis.YabaiIndicator`; the working app uses `com.carcot.YabaiSpaces`. Preserve the old bundle for recovery but do not use it as the daily launcher. Rendering errors remain unresolved and must not be attributed solely to this launch mismatch.

Verified SIP enabled, yabai animation duration zero, and active service labels `com.koekeishiya.yabai` and `com.jackielii.skhd`. The inactive `com.asmvik.yabai` plist is preserved. Next: verify stable launch, diagnose remaining previews, then migrate semantic panel dispatch without disturbing MRU timing, previous-Space behavior, Caps or Tab. Documentation whitespace validation passed. Rollback is to continue launching the untouched DerivedData bundle; no automatic deployment was added.

## 2026-09-12: Scope correction, terminal trace, and safe development launcher

Final verification: ran the installed run.sh --build-only against the real Xcode project. The isolated build succeeded, passed strict signing verification, and separately satisfied the previous daily-use app's designated requirement. The running app PID/path and both active skhd/Karabiner configs were byte-for-byte unchanged across the build. Generated Python test bytecode was moved out of the repo. SIP remained enabled, yabai animation duration was 0, and skhd reported an active event tap with no skhd grabber running.

User confirmed resizing features are unused. The unlinked, task-created WindowGeometryCore package was moved outside the repo to task work/scope-reset/parked-WindowGeometryCore, compared against its known copy, and its nineteen tests passed there. Earlier geometry-backend migration next steps are superseded. Preserve useful panel, window/Space navigation, and existing timing; do not recreate every historical binding. HyprMac-inspired enhancements are future optional work.

Read the selected Karabiner profile and local Ghostty/Emacs/Kitty settings. Tab emits left Control when held despite its Super description. Ghostty sets left Option as Alt, and the checked Ghostty and Emacs source configs contain no Control-to-Super/Meta reassignment. This is a source audit, not proof about every runtime application or terminal escape sequence. The ~/.config/emacs symlink points to missing /Users/carl/.emacs.d; ~/.emacs.d exists separately. It was not repaired automatically because selecting a startup configuration could change unrelated behavior. Caps application-list discrepancies are also left unchanged. No input mappings were removed.

Replaced run.sh's force-kill-before-build and hardcoded launch path with isolated temporary signed builds. Default is now build-only; explicit --launch refuses while an existing app runs and rechecks after building. Build/signature failures stop execution, and the working app is never replaced. Documentation is in docs/SAFE_DEVELOPMENT.md. Seven mocked tests in test_run.py passed after shell/Python syntax checks, including failures and duplicate-app checks. These tests do not prove live input behavior or signing continuity. Existing app-source and Serena changes are preserved. No commits were made.

The current right-Shift route is user-verified. Karabiner remains temporary, with eventual skhd replacement contingent on reliability. Rollback assets for the launcher are in task work/safe-run/run.before.sh; the parked geometry directory can be restored without any app rebuild.

## 2026-09-12: Right-Shift physically verified; geometry execution contract tested

User confirmed all three right-Shift behaviors work: opening the panel, confirming while open, and ordinary Shift-held typing. The temporary Karabiner/skhd/YabaiSpaces path is now physically verified. Keep the user's eventual preference for skhd replacing Karabiner contingent on reliable tap handling and preserved mappings.

Added a main-actor GeometryExecutor and backend protocol to the isolated WindowGeometryCore package. Commands are validated before querying; a single target is passed to a guarded apply, followed by same-ID readback. Results distinguish stale, missing, rejected, adjusted, failed, unverified, and verified outcomes. No implicit retry or focus change is performed. Backend apply errors may involve partial changes; the contract explicitly forbids assuming errors imply no mutation. Cross-process races cannot be completely eliminated.

All nineteen package tests passed, including eight new fake-backend tests for command rejection, absent/ineligible targets, stale targets, same-ID readback, application size constraints, invalid/failed readback, backend errors, and one-point rounding. Swift parsing/type checks ran immediately after source edits. This is still isolated: the real macOS backend and controlled-window tests remain to be implemented. No app rebuild/restart or live shortcut/config changes were made in this stage.

Rollback: remove GeometryExecutor.swift and GeometryExecutorTests.swift and their README/log additions. Existing user changes and working input remain untouched.

## 2026-09-12: Temporary right-Shift route deployed after explicit approval

The user accepted the temporary Karabiner-to-skhd implementation while retaining the longer-term preference to replace Karabiner with skhd if reliable. This supersedes the blocked-deployment status below. The previously tested app was backed up, gracefully restarted, replaced with the signed build, and verified against its previous designated requirement. skhd loaded the F18-to-Hyper-F18 forward with no new logged parser errors and reported its event tap active. The added Karabiner rule was installed and JSON validation passed. All original mappings are preserved; no skhd grabber was installed.

Right-Shift tap now routes through Karabiner (250ms alone detection), skhd (dispatch), and the temporary YabaiSpaces Hyper-F18 confirm-or-show action. Physical tap/confirm/typing verification is awaiting the user; deployment and unit checks do not establish end-to-end input success. The eventual architecture should remove specialized key handling from YabaiSpaces and expose semantic panel actions instead. Replacing Karabiner is contingent on reliable skhd tap handling and preserving existing Caps/modifier behavior, not an immediate removal request.

Rollback assets: task work/right-shift/before contains the full prior app bundle, skhdrc, and karabiner.json. Restore those together to regain the previous native YabaiSpaces right-Shift toggle. No other input service, MRU behavior, or Space-switching logic was changed by deployment.

## 2026-09-12: Right-Shift panel confirmation staged, NOT deployed

User requested right-Shift tap to open the panel, then act as Return while it is visible. Replaced the source's existing modifier-tap toggle binding with Hyper-F18 and a confirm-or-show action. Return and the new action share selection confirmation logic. The existing Hyper-Space toggle remains unchanged. Karabiner's staged rule emits F18 only for an unmodified right-Shift tap within 250ms; ordinary Shift combinations pass through. skhd's staged forward maps F18 to Hyper-F18, avoiding the broken low-level skhd grabber. Panel visibility is owned by YabaiSpaces, not inferred from the foreground application (the panel is nonactivating).

Validation: Swift syntax checked after each edit; full signed Xcode build passed and matched the existing designated signing requirement. An isolated mock-panel executable passed closed/show, open/confirm, externally-opened-panel, and legacy-toggle checks. JSON validation and a structural comparison verified all pre-existing Karabiner rules and skhd lines remain unchanged in staging. Actual skhd parser acceptance and physical right-Shift behavior have not been verified.

Deployment was rejected twice by auto-review due to live input risk. No running app or live keyboard config was changed. The skhd parse error cited by the review was from 01:51, before cleanup; neither current nor staged config contains an active .remap. Further live deployment requires resolving the review/user approval. Staged files and original source/config backups are in the task's work/right-shift directory. Source changes are present in the repository, but the running app remains the prior version. No commits were made.

## 2026-09-12: Geometry command parser and planner

Added an isolated 13-command allowlist and explicit window-ID frame plans to WindowGeometryCore. This keeps keyboard dispatch separate from geometry semantics without exposing arbitrary shell commands. Missing/nonstandard/minimized/native-fullscreen targets and minimum-size violations are rejected. Maximize remains a frame operation, not native fullscreen. The command parser rejects compound and oversized messages.

Validation: immediate Swift type/syntax checks passed; all eleven package tests passed, including five new command-boundary tests. The first package-test attempt was blocked by the sandbox compiler-cache restriction; the authorized rerun passed. This is not yet a live socket endpoint or window adapter. Transport authentication, bounded reads, fresh target validation, coordinate conversion and application readback remain required before hotkey cutover. No running app, signing, permissions, MRU logic, or live input configuration changed.

Rollback: remove GeometryCommand.swift and GeometryCommandTests.swift and revert the corresponding package README/log additions. The package remains unlinked from the running app.

## 2026-09-12: Isolated geometry migration foundation

Added WindowGeometryCore as a standalone Swift package, not yet linked into the app or any input handler. It calculates halves, quarters, maximized frames, and 24-division upper-left-corner adjustments. Keeping geometry pure separates window semantics from skhd dispatch and allows testing without moving real windows or disturbing MRU history.

Legacy Hammerspoon characterization passed 114 assertions and identified absent-window errors and origin-dependent corner grid dimensions. The candidate uses screen-local dimensions, preserves opposite edges, and rejects invalid or collapsed geometry. Its six XCTest cases passed in staging after correcting a negative-size validation issue exposed by testing. Syntax/type checks were performed after edits. Actual app minimum sizes and physical shortcuts still need adapter-level validation before any cutover.

The current signed app and live configuration were backed up separately, and a clean isolated rebuild passed the previous build's designated signing requirement. No signing private keys were exported. Existing Serena additions and the YabaiAppDelegate logging change were preserved; no live hotkeys or application wiring changed. The pre-existing run.sh force-kill/build ordering remains a documented follow-up, not something executed in this stage.

Rollback: remove the unintegrated WindowGeometryCore directory and this log entry. No application rollback or permission reset is needed because the running app was not replaced.

## 2026-08-21: FAILED - Desktop Wallpaper Restoration Caused Memory Leak Regression

### Outcome
🚨 **FAILED** - Wallpaper restoration reintroduced CGImage memory leaks that were fixed in commit `ae254c4`

### What We Tried
Attempted to restore desktop wallpapers to hybrid previews using "memory-safe" direct CGImage drawing:
```swift
// Our approach - assumed to be safe
context.draw(wallpaperCG, in: rect)  // Still leaks CGImage
```

### What Actually Happened
- **Memory pattern**: 75 MB → 126 MB over panel opens (51 MB leak)
- **Leaks tool**: 84 CGImage leaks for 14,544 bytes
- **Root cause**: Direct CGImage drawing still creates dependency leaks

### Why It Failed
Both approaches leak memory:
```swift
// Original approach - leaks
let wallpaper = NSImage(cgImage: wallpaperCG, size: size)
wallpaper.draw(in: rect)  // CGImage leaks

// Our "fix" - still leaks  
context.draw(wallpaperCG, in: rect)  // CGImage leaks
```

**Fundamental issue**: Any CGImage drawing in this context creates dependency leaks, regardless of drawing method.

### Files Modified (BROKEN)
- `YabaiIndicator/PrivateWindowCapture.swift` - Multi-screen wallpaper loading
- `YabaiIndicator/ImageGenerator.swift` - Direct CGImage drawing (LEAKING)
- `YabaiIndicator/ButtonImageCache.swift` - Separate wallpaper cache
- `YabaiIndicator/Connectors/YabaiClient.swift` - Fixed queryWindows logic
- `WALLPAPER_LOADING_FIX.md` - Incorrect documentation (claimed memory-safe)
- `SESSION_LOG.md` - This file

### Commits That Need Reversion
- `4940905` "fix: restore desktop wallpapers in hybrid previews (memory-safe)" - REVERT THIS
- `0de1e29` "fix: add safety checks and improvements" - Keep (memory logging works)

### What Commit ae254c4 Actually Did
The original fix removed wallpapers entirely because **all wallpaper rendering approaches leak**:
```swift
// The working solution from ae254c4
context.setFillColor(NSColor(red: 0.3, green: 0.35, blue: 0.45, alpha: 1.0).cgColor)
context.fill(rect)  // Gray background, no leaks
```

### Lessons Learned
- Don't assume "direct" drawing is safer than NSImage drawing
- Test with `leaks` tool during development, not just basic functionality
- The original fix removed wallpapers for a reason - should have understood why first
- Memory logging works perfectly and caught the leak immediately

### Evidence
- Memory log shows 51 MB increase: 75 MB → 126 MB
- Leaks tool confirms 84 CGImage leaks
- Pattern confirms leak occurs with each panel open

## 2026-08-21: Desktop Wallpaper Loading Fix (FAILED - ABOVE)


### Problem
Desktop wallpaper loading had been removed in commit `ae254c4` to fix CGImage memory leaks, resulting in gray/black backgrounds instead of actual desktop wallpapers in hybrid preview mode.

### Root Causes
- **Primary issue**: Initial fix used NSImage drawing (`wallpaper.draw(in: rect)`) which caused CGImage memory leaks
- **Secondary issue**: Single-screen focus in `loadWallpaperCG()` - only tried `NSScreen.main`
- **Cache collision**: Both `generateImage` and `generateHybridPreviewImage` used same cache, causing overwrites
- **Logic error**: Reversed guard statement in `YabaiClient.queryWindows()` with reversed guard statement logic

### Solution
**Restored direct CGImage drawing** (memory-safe):
- Changed from `NSImage.draw(in: rect)` to `context.draw(cgImage, in: rect)`
- Matches original pre-leak approach from commit `ce328c8`
- Maintains leak-free behavior while restoring wallpapers

**Multi-screen wallpaper loading**:
- Updated `PrivateWindowCapture.loadWallpaperCG()` to iterate through all `NSScreen.screens`
- Falls back through screens if one fails
- More robust in multi-display setups

**Separate wallpaper cache**:
- Added `WallpaperImageKey` struct and dedicated `wallpaperCache`
- Prevents cache collisions between window-style and wallpaper-style previews
- Added LRU management for wallpaper cache

**Fixed YabaiClient logic error**:
- Corrected guard statement in `queryWindows()` - now properly skips malformed entries
- Window creation moved to success path after all fields validated

### Files Modified
- `YabaiIndicator/PrivateWindowCapture.swift`:
  - `loadWallpaperCG()`: Changed from single-screen to multi-screen iteration
  - `captureDesktopCG()`: Updated for consistency
  - `captureDesktop()`: Updated for consistency
- `YabaiIndicator/ImageGenerator.swift`:
  - `generateHybridPreviewImage()`: Restored direct CGImage drawing, uses wallpaper cache
- `YabaiIndicator/ButtonImageCache.swift`:
  - Added `WallpaperImageKey` struct
  - Added `wallpaperCache` and LRU methods
  - Added `getWallpaper()` and `setWallpaper()` methods
- `YabaiIndicator/Connectors/YabaiClient.swift`:
  - `queryWindows()`: Fixed guard statement logic

### Testing
- ✅ Build succeeded with no errors
- ✅ Wallpapers display correctly in hybrid previews
- ✅ Maintains memory-safe approach (no CGImage leaks)
- ✅ Multi-display support improved
  - `queryWindows()`: Fixed guard statement logic

### Testing
- ✅ Build succeeded with no errors
- App launches and runs successfully
- Maintains existing PNG caching strategy for memory safety
- More robust wallpaper loading across all displays

## 2026-06-21: Correct Memory Leak Release Notes

### Problem
The memory leak release-note language still described the older `1911 -> 73` investigation as the current fix, even though runtime verification showed the actual leak was the private SkyLight thumbnail capture path.

### Solution
- Replaced the old percentage-reduction release-note language with the verified SkyLight leak explanation.
- Documented the measured before/after reproducer: 205 leaks and 35,424 leaked bytes before the fix, 0 leaks and 0 leaked bytes after the fix.
- Preserved the older `1911 -> 73` data only as superseded historical investigation context.

### Files Modified
- `MEMORY_LEAK_FIX.md`: Rewritten around the verified root cause, corrected release-note copy, and current verification procedure.
- `SESSION_LOG.md`: Documents this documentation correction.

### Testing
- Documentation-only change; no build required.

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


## 2026-06-18: Panel Spacing and Border Refinements

### Changes
- Reduced row spacing from `4 * scale` to `3 * scale` to better match visual balance
- Reduced panel padding from `4 * scale` to `3 * scale` to match row spacing
- Changed inactive thumbnail border from `Color.secondary` to `Color.white.opacity(0.2)` for brighter appearance
- Fixed thumbnail capture timing: hide panel first, then capture, then switch (prevents panel from appearing in screenshots)

### Files Modified
- `PanelLayout.swift`: `rowSpacing = 3 * scale`, `padding = 3 * scale`
- `ContentView.swift`: Inactive border color changed to `Color.white.opacity(0.2)`
- `YabaiAppDelegate.swift`: Reordered `switchSpace()` to hide panel before capturing thumbnail

### Attempted: External Switch Thumbnail Capture
Attempted to capture thumbnails when switching spaces via keyboard/gestures (external to app). Multiple approaches tried:
1. NSWorkspace.activeSpaceDidChangeNotification observer
2. Track lastActiveSpaceId before model update
3. Combine subscriber on spaceModel.$spaces

All approaches failed because spaceModel is updated by Yabai signals before OS notification fires, making it impossible to reliably identify the old space after switch.

Current behavior: Thumbnails only captured when switching via panel. External switches update UI but don't capture thumbnails.

See `EXTERNAL_SWITCH_CAPTURE_NOTES.md` for detailed analysis and potential future approaches.

### Files Created
- `EXTERNAL_SWITCH_CAPTURE_NOTES.md`: Documents attempted approaches and root cause analysis

## 2026-06-20: CGImage Memory Leak Fix

### Problem
App showed 49.4 GB physical footprint due to CGImage memory leaks from repeated panel opens.

### Root Cause
Verified via `leaks` with `MallocStackLogging=1`: Leaked `<CGImage>` roots allocated under SkyLight's `SLWindowListCreateImage` path in thumbnail capture.

**Technical Detail:** When `context.draw(sourceCGImage, in: rect)` is called, Core Graphics creates dependency tracking where the final CGImage retains references to source CGImages drawn into it.

### Solution
1. **Replaced private SkyLight capture** with public `CGDisplayCreateImage()` for active-display capture
2. **Immediate PNG conversion** - All CGImages converted to PNG Data immediately after creation
3. **PNG-only caching** - Cache stores only PNG Data, never NSImage or CGImage
4. **Wallpaper removed from hybrid preview** - Eliminates `context.draw()` dependency chain

### Verified Metrics (reproducer: 40 panel opens)
| Metric | Before Fix | After Fix |
|--------|------------|-----------|
| Leaks | 205 | 0 |
| Leaked memory | 35,424 bytes | 0 bytes |
| Physical footprint | 610.5M | 43.8M |

### Files Modified
- `PrivateWindowCapture.swift`: Changed to public API, PNG caching
- `ImageGenerator.swift`: Immediate PNG conversion, wallpaper removed from hybrid preview
- `MEMORY_LEAK_FIX.md`: Created comprehensive documentation

### Verification
```bash
MallocStackLogging=1 ~/.../YabaiIndicator.app/Contents/MacOS/YabaiIndicator &
PID=$(pgrep -f YabaiIndicator | head -1)
leaks $PID
```

Expected: `Process <PID>: 0 leaks for 0 total leaked bytes.`

## 2026-08-08: Fix Desktop Wallpaper Loading and Hotkey Behavior

### Problem 1: Spaces Not Pre-Populated with Desktop Background
On startup, unvisited spaces showed solid gray backgrounds instead of desktop wallpapers.

### Root Cause
Two separate issues:

1. **Hybrid preview was using solid color**: `generateHybridPreviewImage()` had been changed (commit ae254c4) to use a solid gray background "to prevent CGImage leaks" instead of loading desktop wallpaper.

2. **Capture method was wrong**: `PrivateWindowCapture.captureSpace()` was using `captureDisplay()` which captures current SCREEN CONTENT (including windows), not the wallpaper file. This caused:
   - All spaces to show the same current screen content
   - Windows to be drawn twice (captured in background + drawn separately)

### Solution

**Restored wallpaper loading in hybrid preview:**
- `generateHybridPreviewImage()` now calls `gPrivateWindowCapture.captureDesktopCG()` to load wallpaper from file
- Falls back to solid gray if wallpaper load fails

**Fixed captureSpace() to use wallpaper file:**
- Changed from `captureDisplay()` (captures current screen) to `captureDesktopCG()` (loads wallpaper file)
- Now correctly shows desktop wallpaper + window outlines for unvisited spaces
- When visiting/leaving spaces, thumbnails capture actual wallpaper + window content

**Removed broken startup pre-population:**
- Removed code that tried to capture all space thumbnails on startup (was capturing current screen for all spaces)
- Thumbnails are now only captured when you actually leave a space (correct behavior)

### Problem 2: Hotkey Toggled Panel Open/Close
The same hotkey (Cmd+Option+Ctrl+Shift+Space and Right Shift tap) both opened AND closed the panel.

### Solution
Changed hotkey action from `.toggle()` to `.show()`:
- Hotkey now only OPENS the panel
- If panel is already open, pressing hotkey repositions/recaptures but doesn't close
- Panel can still be closed via: click outside, Escape, or Enter/Space after selection

### Files Modified
- `ImageGenerator.swift`: Restored wallpaper loading in `generateHybridPreviewImage()`
- `PrivateWindowCapture.swift`: Fixed `captureSpace()` to use `captureDesktopCG()` instead of `captureDisplay()`
- `YabaiAppDelegate.swift`: Changed hotkey actions from `.toggle()` to `.show()`

### Testing
- Desktop wallpapers now display correctly for unvisited spaces on startup
- Each space shows its own wallpaper (or same wallpaper if configured that way)
- Thumbnails are captured correctly when leaving spaces
- Hotkey only opens panel, never closes it
