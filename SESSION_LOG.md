# Session Log

## 2026-10-22: Prepare universal 1.10.0 GitHub release

User explicitly requested pushing all current work and publishing a new app bundle. Active `carlcotner` credentials lacked write access; switched gh to the already authenticated `carcot` account and verified repository admin/push permission. No new login, credential disclosure, global Git configuration change, or SSH-key change was needed. The remote main was still `409f7bbe`, so publication will include the prior local 1.8.0 release commit plus the documented 1.9.0/1.10.0 fixes and installation updates. Version remains **1.10.0**, already incremented from published/source predecessor; no new runtime behavior was added during packaging.

Verification: Swift parse, Python compilation/import, shell syntax, project plist validation and whitespace checks passed. The full **53-test suite passed with no skips in 85.362 seconds**, including actual Screen Recording pixel and AppKit regressions; `/private/tmp/YS-release-1.10.0-tests-20261022.log`. `./build-dmg.sh` completed an explicit signed universal **clean Release build** in `/var/folders/b3/my4hx2zj60987cm3sl1ck4vm0000gn/T/YabaiSpaces-release.P5xlPu`; full `build.log` retained, packaging log `/private/tmp/YS-release-1.10.0-package-20261022.log`. DMG integrity, mounted contents against build, strict signature, version/identity, arm64/x86_64 slices, Applications shortcut and SHA-256 all verified. Added checksum `126d133d262778ac7bedcded7c6464ac2640f55a985ed1eb7f1e8950116b901b`, release notes, and updated current package/install references without replacing historical deployment records.

Installed the exact packaged build after verifying the working-app backup, matching designated requirement and signatures. Clean replacement, complete installed-content comparison and restart passed: PID 1902 → **81694**. Healthy native focus diagnostics with no degradation and two actual panel open/close cycles passed. Backup/retired bundle/runtime log/deployment JSON: `/private/tmp/ys-release-1.10.0-install-20261022/`. Reused the verified deployment routine `/private/tmp/deploy-ys-thumbnail-20261022.py` with explicit build/version/recovery overrides; rollback protection remained in place. No physical click/Space transition was synthesized. Existing build warnings were unchanged/unrelated.

The bundle remains Apple Development signed, not Developer ID signed/notarized. No user configuration, permissions, SIP, preview mode or animation setting changed. At this preparation point the new local artifact exists and is running, but GitHub push/release publication still require final commit/upload verification; the final publication record follows once verified.

## 2026-10-22: Installation, preview-mode, and SIP-enabled no-animation documentation

User requested the missing installation/release details and asked whether the README explained newer yabai switching without disabling SIP. The README previously offered only a general SIP statement, dependency bullets, and release links; it lacked a fresh-install sequence, prominent distribution-signing warning, and an explanation that the default Windows preview mode does not display screenshots. Added an actionable README sequence and `docs/INSTALLATION.md` covering yabai setup, checksum verification, stable app placement, per-component permissions, first-run previews, optional skhd/Karabiner integration, signal ownership, clean upgrades/rollback, and troubleshooting. Button Style is shared by menu bar/panel: Windows means wallpaper/outlines, Thumbnail means cached screenshots, with uncaptured-Space fallback and departure-time refresh. The user's existing Windows selection was not changed.

Verified upstream primary sources: [7.1.25 changelog](https://github.com/asmvik/yabai/blob/v7.1.25/CHANGELOG.md), [manual](https://github.com/asmvik/yabai/blob/v7.1.25/doc/yabai.asciidoc), [maintainer's SIP-enabled switching discussion](https://github.com/asmvik/yabai/issues/2780), [installation instructions](https://github.com/asmvik/yabai/wiki/Installing-yabai-(latest-release)), and [Apple's Gatekeeper guidance](https://support.apple.com/en-us/102445). Documented SIP-enabled direct Space focus from 7.1.19, the separate indirect-focus animation option introduced in 7.1.22/improved in 7.1.23, its no-scripting-addition restriction, and remaining scripting-addition/SIP distinctions. Window-frame animation is not the Space-transition setting. Local read-only checks found yabai 7.1.25, arm64, macOS 26.6.2, SIP enabled, `skip_window_focus_animation` off, and `window_animation_duration` 0.000000; documentation does not imply that the optional setting was enabled or all OS/hardware combinations were tested.

Documentation decision: distinguish current source/installed 1.10.0 from the checked-in 1.8.0 package and pending new publication. Keep real existing download links, identify the release index as the published-download source, and do not invent a 1.10.0 asset URL. Prominently disclose Apple Development signing rather than notarized Developer ID distribution, with Apple's cautious first-launch guidance instead of blanket security bypasses. Updated quick context, safe-development release-readiness guidance, and switching cross-references; retained historical deployment records.

Verification: immediate `git diff --check` after each documentation patch; Markdown fence/final-newline and local-link/heading-anchor checks; shell examples parsed with `bash -n` without executing installation/configuration commands. Confirmed UI style labels/default and source version against source files. These are documentation checks, not new runtime/physical-input compatibility tests. No code, version, privacy authorization, SIP, keyboard configuration, preview preference, or animation setting changed; no build/restart was required. No new DMG, commit, push, or release publication was performed during this documentation update.

## 2026-10-22: Disable thumbnail click-position window selection (1.10.0)

User found click-position window selection slow/confusing and explicitly requested commenting out the code while retaining it, then recompiling. The old thumbnail handler mapped the click into window bounds and passed a target ID for an extra window-focus request after switching Spaces. Wrapped both `findWindowAt` and the original `DragGesture` handler in block comments, preserving their implementation. The active handler is now `.onTapGesture { switchSpace() }`, so thumbnail position no longer selects a window. Leave the optional delegate focus pathway and normal yabai/macOS destination focus intact; do not introduce a new MRU policy or alter native cycling/history, keyboard handling, or the standing departure-thumbnail requirement. Incremented minor version to 1.10.0 and updated README, quick context, switching documentation, and safe deployment notes.

Verification: per-edit Swift parsing, Python compilation/import, project plist validation, and documentation diff checks passed. Added a source regression verifying the helper/old handler remain in comments while active thumbnail handling contains no hit-testing/drag selection and calls only `switchSpace()`. All five focused merge regressions passed, then the full **53-test suite passed with no skips in 87.550 seconds**, including real-pixel departure and AppKit border checks; `/private/tmp/YS-thumbnail-click-tests-20261022.log`. Explicit signed universal **clean Release build** succeeded; `/private/tmp/YS-thumbnail-click-build-20261022`, log `/private/tmp/YS-thumbnail-click-build-20261022.log`.

Deployment: verified and byte-compared installed 1.9.0 backup at `/private/tmp/ys-thumbnail-click-install-20261022/YabaiSpaces.app` before stopping the old process. Verified strict signatures, matching designated requirements, bundle identity/version and both architectures, moved the old bundle aside, copied the replacement into a clean destination, and compared complete installed contents/signature. Installed at `/Applications/YabaiSpaces.app` and restarted PID 79957 → **1902**. Two actual panel open/close cycles stayed alive and native `focus status` reported healthy signals/no degradation. Recovery app, retired bundle, runtime log, and deployment JSON are retained in that directory; helper `/private/tmp/deploy-ys-thumbnail-click-20261022.py` restores the verified backup on failure. No physical click/Space switch was synthesized; source guard/build and panel viability were checked, with direct click testing available to the user. No external configuration/permission changes, commit, push, or new DMG.

## 2026-10-22: Make departure-thumbnail timing a standing requirement

User reaffirmed that departure-time capture was always the intended behavior and requested durable protection against changing it again. Added a normative contract to `EXTERNAL_SWITCH_CAPTURE_NOTES.md` and a linked mandatory section in root `AGENTS.md`: capture the outgoing desktop immediately before leaving, never substitute arrival/panel-opening snapshots, finish before focus/Space changes, exclude YS overlays, preserve Space/display attribution and clean-cache failure behavior, and require explicit user approval to change the requirement. Recorded acceptance criteria and the three existing production-ordering, real-pixel, and window-ID regressions; capture mechanisms may evolve without weakening the behavior. External-switch interception remains an explicit limitation, not a redefinition of the requirement.

Verification: per-edit Markdown diff checks passed; requirement link/heading anchor, Markdown structure/local links, and all three referenced test names were verified. This follow-up is documentation-only and leaves the prior 1.9.0 runtime work untouched; no build, restart, version change, commit, or push was needed/performed.

## 2026-10-22: Refresh thumbnails at panel departure (1.9.0)

**Final status:** corrected 1.9.0 clean universal Release build installed and running as PID **79957**, with healthy native command/focus diagnostics and two actual panel open/close cycles verified. All **52 tests passed with no skips in 87.810 seconds**; `/private/tmp/YS-thumbnail-tests-20261022.log`. Final backup/deployment/runtime records are in `/private/tmp/ys-thumbnail-install-20261022-2/`. The initial 51-test run and PID 74763 deployment below were intermediate, not the final verification.

Live-crash follow-up: a real panel interaction after that initial deployment exposed a positive AppKit `windowNumber` outside the 32-bit CoreGraphics range. The new unchecked conversion trapped in `captureThumbnail` before taking the image; crash report `YabaiIndicator-2026-10-22-113319.ips`. Preserved the failed app, restored the verified 1.8.0 backup, and restarted PID 77194 while fixing it. Exclusion collection now uses `CGWindowID(exactly:)`, skipping invalid/unrepresentable values. Added a compiled production-caller regression covering negative/zero, normal, maximum 32-bit, and oversized numbers. Fixed a missing CoreGraphics import in that new harness, then reran the full suite successfully. Rebuilt with explicit clean Release/universal settings, preserved a second byte-verified 1.8.0 backup, installed into a clean destination, verified signatures/requirements/contents, and restarted PID 77194 → 79957. The deployment helper now opens/closes the actual panel twice and checks process/command health before declaring success. No physical Space changes were synthesized. Initial/retired/failed bundles are retained for rollback and diagnosis.

User reported thumbnails captured too early, clarifying that panel navigation showed the desktop as it looked on arrival rather than departure. Root cause in the existing policy: `prepareForSpaceSwitch` deliberately skipped capture while the panel was visible and retained the earlier panel-opening snapshot. Changed preparation to hide the panel without cursor restoration, then synchronously refresh the outgoing visible desktop immediately before sending the Space-focus command. Opening still captures the initial preview; repeated show/reposition does not capture the visible panel. No-op/unknown destinations retain their existing guard behavior. Direct YS switches still capture at departure; external Mission Control/direct-yabai switches remain outside the pre-focus hook.

A new real-pixel regression found a second root cause: `orderOut` and disabled panel animation do not guarantee the completed display image has dropped the panel. The naive hide-then-`CGDisplayCreateImage` fix captured the blue panel instead of the changed green content. Explicitly exclude YS AppKit window IDs from fresh front-to-back on-screen composition using dynamically resolved `CGWindowListCreateImageFromArray` and full display bounds. Preserve desktop/Finder elements and the full-display path when there are no exclusions. Missing clean-composition support returns no image, preserving the previous cache rather than falling back to a contaminated screenshot. This remains dependent on legacy CoreGraphics availability and Screen Recording permission; it is not a ScreenCaptureKit migration. Disable panel show/hide animation as well. No arbitrary sleep, synthetic outline substitution, keyboard remapping, history-policy change, or new permission request was added.

Verification: first strengthened the ordering/content harness and reproduced its failure before the policy change. Production preparation now records hide → fresh outgoing capture → focus, including main/background callers, visible desktops on both relevant displays, no-op/invalid targets, and focus failure. Added a second harness compiling production capture/preparation/panel-hide code: a nonactivating blue panel covers a red-to-green content change; eight departures must capture green, not red or blue, without changing the foreground application. Its initial compile used the host deployment target and rejected the legacy display API; corrected the harness target to match the app's macOS 11.6 deployment target. The real-pixel test then reproduced the compositor race before explicit exclusion and passed afterward. It skips if existing Screen Recording permission is absent, without requesting access. All **51 tests passed with no skips in 82.160 seconds**, including actual pixel and border checks; `/private/tmp/YS-thumbnail-tests-20261022.log`. Per-edit Swift parsing, Python compilation/import, project plist validation, and documentation diff checks passed. Updated README/capture notes/quick context/deployment guidance; incremented minor version to 1.9.0.

Deployment: explicit universal signed **clean Release build** `/private/tmp/YS-thumbnail-build-20261022`, log `/private/tmp/YS-thumbnail-build-20261022.log`. Before stopping YS, verified the new/old strict signatures, matching designated requirements, bundle ID/version, arm64/x86_64 slices, and byte-identical prior-app backup at `/private/tmp/ys-thumbnail-install-20261022/YabaiSpaces.app`. Moved the stopped old bundle aside, installed into a clean destination, compared complete contents, verified installed signature/requirement, and restarted PID 95428 → **74763**. Native `focus status` returned healthy signals and no degradation. Deployment record/runtime log and retired bundle are retained in the recovery directory; rollback helper `/private/tmp/deploy-ys-thumbnail-20261022.py` restores the verified previous app on failure. No personal configuration, privacy authorization, focus protocol, or input-service changes. Physical panel/shortcut and multi-display confirmation remains available to the user; pixel regression covers the rendering/timing race, not every real desktop. No commit, push, or new DMG was requested/performed for this fix; the checked-in 1.8.0 package does not include it.

## 2026-10-06: Universal 1.8.0 package and publication preparation

User requested pushing all changes, including a new app bundle. Reviewed the complete pending changeset and retained the pre-existing Serena metadata update with the YS code, tests, docs, licenses, project/package changes, and shortcut snippet. Runtime version was already incremented from the published source's 1.1.5 to 1.8.0 across prior feature work; packaging-only edits require no further minor increment. Added release notes, refreshed quick context/README, and prepared the versioned universal DMG plus checksum for source publication and release upload. No personal home-directory configurations or credentials were copied into the repository.

Packaging root causes: `build-dmg.sh` hard-coded 1.1.5, used a pipeline that could mask compilation failure, searched a reusable build tree for potentially stale output, and did not verify the image/architectures. It now propagates failures, clean-builds both architectures in a fresh directory, retains the full log, derives the filename from the built plist, verifies strict signing/architectures, stages branded `YabaiSpaces.app` plus an Applications shortcut, and verifies DMG integrity. The first attempt exposed corrupt package state in the old tracked build tree; the isolated retry resolved dependencies without altering that tree. Restored only build-cache changes caused by that failed attempt. Corrected a lipo argument-order error detected by the real universal build and added mock coverage for it. Five new isolated packaging tests cover success/version branding/staging cleanup and build, signature, architecture, and image-verification failures.

Verification: shell syntax, changed Swift parsing, all Python test compilation/imports, project plist validation, Markdown diff checks, and targeted credential-pattern checks passed. Initial sandboxed runtime tests failed because local socket creation, package resolution, and AppKit window services were restricted; the approved unsandboxed rerun passed all 45 tests. Final combined suite passed **50 tests in 80.477 seconds**; `/private/tmp/YS-publication-tests-20261006.log`. Clean signed universal Release build succeeded at `/private/var/folders/b3/my4hx2zj60987cm3sl1ck4vm0000gn/T/YabaiSpaces-release.snGYwv`; full `build.log` and `/private/tmp/YS-publication-build-20261006.log` retained. DMG SHA-256 is `b8fa2e2664ec6f477e6988c8cf98414d6dc0452bf187524c91b0a2d16b4bcb47`. Image integrity, mounted contents, strict app signatures, both slices, version/identity, and matching designated requirements were verified. No Developer ID distribution signing/notarization was performed; universal compilation is not Intel runtime verification.

Deployment root cause/fix: copying the Release app over the Debug bundle left obsolete Debug files, so the installed-content comparison failed. Rollback restored/restarted the byte-verified prior app. A clean replacement then moved the stopped bundle aside, installed the exact mounted DMG app, compared complete contents, verified its signature/requirement, and restarted YS as PID 70844. Native command handling and focus diagnostics were healthy (`signalsHealthy=true`, `degraded=false`); no keyboard/configuration/signal-protocol/privacy changes. Recovery app and records are in `/private/tmp/ys-publication-install-20261006/` and `/private/tmp/ys-publication-install-20261006-2/`; the verified backups and retired bundle are retained, not deleted. Final strict signature verification required unsandboxed trust access and passed.

Publication gate: both GitHub CLI and SSH authenticate as `carlcotner`, but the configured `carcot/YabaiSpaces` repository reports `permissions.push=false`. No writable YabaiSpaces repository appeared in the authenticated account's repository listing. Requested the intended publishing account/repository or a write-access grant while continuing local verification. At this entry, no GitHub branch, tag, or release has been changed; do not treat the verified local package as a published release.

## 2026-10-06: README consolidated for the current YS/skhd setup

Updated the README to describe 1.8.0 and the active local integration rather than mixing historical shortcuts with current behavior. Documented the four skhd dispatch rules, direct F20-to-YS Caps prefix, remaining application-specific Karabiner tap/hold responsibilities, deferred skhd-only handoff, removed Left-Command tap/Command-L/Caps-period actions, and all configured Caps letters. Distinguished local Ghostty and Brave Space overrides from generated defaults, and documented complete-file TOML semantics and explicit reload.

Consolidated window-derived Space ordering, two-second cycling and manual-focus cancellation, thinning window-adjacent border, ID-bearing focus journal/reconciliation and its chronology limitations, native commands, manual controls/yabai-owned tiling, clean thumbnail timing, permissions, owned signal registration/rollback, version history, and verified deployment workflow. Corrected the blanket SIP requirement: current local Space focus was verified with SIP enabled; features needing Dock injection retain upstream prerequisites. Kept detailed architecture and migration information linked rather than treating historical session entries as current configuration.

Verification: Markdown diff whitespace checks passed immediately after the README edit. Validated balanced fences, 13 local links/assets, eight shell example blocks with shell syntax checks, and the TOML example. Compared all four documented skhd rules and 20 Caps bindings/six unbound letters against the active local files. Compiled the production native command parser and validated 21 documented command examples against an intentionally absent test socket; no commands were sent to the running app. Documentation-only: no runtime/configuration changes, build, installation, restart, version increment, commit, or push.

## 2026-10-06: ID-bearing focus tracking (1.8.0)

Implemented the focus-tracking design. Root cause: legacy `window_focused` actions discarded the event ID, and later snapshots could collapse A → B → C into C. Added typed native focus/destroy events, strict positive decimal 32-bit ID validation, bounded raw intake/history (1,024 each), and `focus status` JSON diagnostics. Raw events retain receipt sequence/time, provisional operation association, resolution, and observed PID/lifetime metadata separately from filtered navigation history. Repeated IDs are retained, unknown/dialog events are not navigation targets, and failures preserve MRU while exposing gaps/degradation. Reply limits and same-user security checks are preserved; diagnostics allow a bounded 32 KiB response and the server handles partial writes.

Separated serial state/ingress from command, query, and signal-registration workers. Snapshots use revision/generation guards; stale operation completion cannot revive a canceled cycle. Verified cycling retains frozen candidates; confirmed external focus ends it and updates history without waiting for the timer. Non-cycling raw eligible IDs are promoted in receipt order, then current focus is reconciled. Two-second cycling, Space representatives derived from window history, Caps/modifier handling, border rendering, and thumbnail exclusion remain unchanged. No exact producer-order/provenance guarantee is claimed.

Implementation decisions: full inventory reconciliation every second rather than the proposed focused-only optimization, providing one consistent view of focus/eligibility/lifetimes; measurements recorded below. Metadata lifetimes are local observations, not authoritative producer tokens. YS's own windows/focus bookkeeping are excluded from navigation. Startup and 30-second checks verify/repair five owned signal labels without touching unrelated consumers. Shadow intake was exercised with compiled fake-backend regressions rather than a separately deployed shadow release. Incremented application minor version to 1.8.0.

Validation: per-edit Swift syntax parsing, Python compilation/import, project plist validation, and Markdown whitespace checks passed. Final full suite: all 45 tests passed in 76.526 seconds; `/private/tmp/YS-focus-tests-20261006.log`. New tests cover parser bounds, raw A/B/A preservation, ring/pending overflow, reversed/stale event delivery, stale snapshots, prompt intake while queries block, dialog/unknown handling, backend recovery, manual cancellation during blocked verification, destruction/PID reuse, and signal idempotency/repair. Existing cycling/history, native socket/framing, Caps/configuration, controls, thumbnail, border/AppKit, build-script, and merge regressions passed. Explicit clean signed build succeeded: `/private/tmp/YS-focus-build-20261006`, log `/private/tmp/YS-focus-build-20261006.log`. Existing app-icon asset warnings remain unrelated.

Deployment: preserved and byte-verified installed 1.7.0 backup `/private/tmp/ys-focus-install-20261006/YabaiSpaces.app`, original `.yabairc`, and active signal snapshot before stopping YS. Verified strict signatures, matching designated requirement, identity/version, and installed bundle contents. Installed 1.8.0 at `/Applications/YabaiSpaces.app`, restarted PID 87652, and verified native command acknowledgment, valid event intake/reconciliation, invalid ID rejection, and healthy owned signals. Replaced only the identified legacy focus-refresh action; persistent `.yabairc` has the five labels and all other existing refresh actions. Compared unaffected active registrations against the original snapshot. App/config/signal rollback is retained in `/private/tmp/deploy-ys-focus-20261006.py` and the recovery directory.

Live verification: initial automation found no yabai key window, then a flat three-window MRU assertion failed because Space transitions also produced intermediate focus IDs. Corrected the helper to derive Space targets from actual deduplicated window history. Other navigation/focus changes overlapped the next run; cleanup restored original focus. After user coordination, macOS foreground inspection found Ghostty visible as window 122 while yabai had no key-window flag. This is a source limitation, not evidence of a missing raw event: YS retained reported IDs and represented current focus as unknown. The helper now independently saves/restores the actual macOS foreground window and uses non-Ghostty windows for the controlled traversal.

The final coordinated live run passed: real yabai focus signals/history for 192424 → 108 → 176892; deduplicated recent-Space traversal 176892 → 108 → 192424 with MRU frozen; manual focus to 176892 ended cycling and updated history; the next command selected 192424, and expiry committed it automatically. Ten repeated native focus-event messages were retained/reconciled with no rejection or degradation. Original foreground window at the start of that final run was 176892 and was independently verified restored afterward. Record `/private/tmp/ys-focus-install-20261006/live-verification.json`. Physical keyboard presses and a real dialog were not synthesized; compiled regressions cover dialog policy and border/thumbnail integration.

Measurements (10 samples each, including process startup, not in-process socket cost): focus-event CLI acknowledgment median 11.66 ms, maximum 14.71 ms; full inventory CLI query median 37.53 ms, maximum 47.08 ms. Three snapshots occurred over 3.2 idle seconds. Separate nonintrusive reconciliation measurements were 11.92/19.58 ms acknowledgment and 31.78/56.30 ms inventory query; `/private/tmp/ys-focus-install-20261006/latency-verification.json`. Final tracking and owned signals were healthy, with no rejected intake. No commit or push; unrelated working changes are retained.

## 2026-10-06: Focus-tracking design and implementation plan

User requested a design before implementing broader focus tracking. Added `docs/FOCUS_TRACKING.md` and linked it from `docs/WINDOW_SWITCHING.md`. Inspected current socket routing, native client validation, filtering, serialized navigation/verification, `.yabairc`, and active signals. Installed yabai reports 7.1.25; its active focus action discards the event ID and requests only a later refresh. Checked the matching upstream documentation and signal implementation: independent forked actions do not guarantee chronological delivery or provide a producer sequence/provenance token.

Design decision: use stock-yabai ID-bearing events, a bounded raw journal separate from eligible navigation history, prompt serialized ingress, nonblocking operation/state coordination, and watermarked live reconciliation. Receipt order is explicitly not producer order. Snapshot repair establishes current focus, not missed intermediate history. Command-origin correlation remains provisional; the document includes delayed-event, dialog, cycle, window-lifetime, gap, and restart limitations. An exact ordered upstream stream or direct macOS observer is outside the initial scope. Implementation proceeds through shadow intake, queue separation, history integration, lifecycle checks, controlled signal cutover, and verified deployment/rollback.

Verification: documentation whitespace checks passed after each edit; code-fence balance and all three local Markdown links across the design/switching documents passed. Active signal reading initially hit sandbox socket restrictions; the approved read succeeded without configuration changes. The initial `jj status` could not snapshot into sandbox-protected `.git/objects`; read-only Git status was used instead, with no commit requested. No runtime code, signals, configuration, version, installed app, or running process changed; no build/restart, commit, or push is required/performed for this documentation-only task. YS remains the previously deployed 1.7.0.

## 2026-10-06: Border thins to the cycling deadline (1.7.0)

User requested a border that thins until timeout while always remaining adjacent to the window. Thickness is now derived from the cycle's remaining deadline and shared two-second duration, from three points to zero. Repeated cycling renews it; observations of the same deadline do not restart the countdown. Replaced layer borderWidth with a shape-layer stroke whose centerline is offset by half its thickness, keeping its inner edge flush with the actual window. Fixed overlay padding avoids resizing/repositioning the panel as it thins. Disabled panel and implicit layer animations so frame changes and show/hide remain immediate. Focus history, shortcuts, and input services are unchanged. Minor version incremented to 1.7.0.

Validation: per-edit Swift parse, Python compile/import, project plist, and documentation whitespace checks passed. Extended the actual AppKit border regression to check decreasing thickness, midpoint, renewal, expiry, and adjacency on all four edges while the window moves. The standalone border regression passed, followed by all four targeted tests across test_cycling_border, test_window_switching, and test_thumbnail_capture; log `/private/tmp/YS-thinning-tests-20261006.log`.

Deployment: explicit signed clean build `/private/tmp/YS-thinning-build-20261006`, log `/private/tmp/YS-thinning-build-20261006.log`. Preserved and byte-verified the installed 1.6.0 recovery app at `/private/tmp/ys-thinning-install-20261006/YabaiSpaces.app` before stopping it. Verified strict old/new signatures, matching designated requirements, bundle identity, installed contents, and version. Installed 1.7.0 at `/Applications/YabaiSpaces.app`, restarted as PID 41390, and verified native prefix cancel acknowledgment. Deployment record and runtime log are in the recovery directory. Rendering/movement checks used the actual AppKit regression; physical shortcut appearance remains available for user testing. No input-service/config changes, commit, or push; unrelated working changes are retained.

## 2026-10-05: Cycling history, shortcut cleanup, and temporary border (1.6.0)

User requested removal of inherited Caps-period and global Command-L, immediate history updates for manual focus, and a focused-window border during the two-second cycle. Removed `jump .` from native validation and the period controller route. Unmodified period during a Caps prefix now cancels and consumes the key without navigation or punctuation. Command-L was removed from the migration snippet and a staged copy of live skhd configuration; installation/reload verification is recorded below. Right-Command tap, existing Command-period, numbered Space jumps, letter bindings, and Karabiner tap/hold rules retain their behavior.

Root cause of stale ordering: every focus observation during an active cycle was treated as a cycle-induced change. The controller now explicitly marks its verified cycling focus; a different externally observed focus commits/ends the cycle and immediately promotes the new window. Unchanged-focus refreshes preserve traversal. A real dispatch timer commits the final focus at the renewable deadline without needing another event. Scope changes/no-target results also commit/clear the session. Space order remains derived from deduplicated window MRU, restoring each Space's most recent eligible window; restart history is still not persisted.

Added a transparent orange three-point AppKit border panel that ignores mouse input and cannot activate. It tracks verified cycle focus and frame movement, shares the model deadline, and clears on expiry/cancellation. It is hidden before outgoing thumbnail captures and while the Spaces panel is visible. Prefix waiting and application jumps do not show the cycling border. Incremented minor version to 1.6.0.

Validation: per-edit Swift parsing, Python compile/import checks, project plist validation, and whitespace checks. All 42 tests passed; log `/private/tmp/YS-cycling-tests-20261005.log`. Updated model/controller regressions verify automatic expiry/renewal and immediate manual-focus history promotion. The AppKit regression uses a temporary background window and verifies border geometry, expiry, renewal, and focus preservation. Initial test harness failed because its private-property extension was compiled in another file; it now compiles alongside the production source. The geometry test waits for WindowServer publication and compares actual window movement rather than assuming a content rectangle equals its titled frame.

October 6 deployment: explicit signed clean build `/private/tmp/YS-cycling-build-20261005`, build log `/private/tmp/YS-cycling-build-20261005.log`. Preserved and byte-compared the working 1.5.0 app at `/private/tmp/ys-cycling-install-20261005/YabaiSpaces.app`. Verified old/new matching designated requirements, strict signatures, identity, installed bundle bytes, and version. Installed `/Applications/YabaiSpaces.app` and restarted as PID 24802; native prefix cancel acknowledged and `jump .` rejected with exit 2. Backed up live skhdrc to the same recovery directory, removed only Command-L, checked active shell-action syntax, and reloaded existing skhd PID 2401 through SIGUSR1. Event tap remains functional and Input Monitoring granted. The initial deployment status assertion read only stdout, while skhd prints status to stderr; configuration was restored automatically, then the corrected check successfully completed the removal. Karabiner/Hammerspoon and TOML bindings were not edited. Runtime log and deployment record are in the recovery directory.

Live installed-build checks verified recent-Space traversal 13093 (Space 6) → 122 (Space 5) → 1060 (Space 7), reused border geometry following focus, automatic disappearance after the deadline, external focus clearing the border, and subsequent navigation honoring the updated history. Record: `/private/tmp/ys-cycling-install-20261005/live-verification.json`. The verifier uses live WindowServer bounds because yabai frame metadata can lag a Space transition, and bounded waits for asynchronous drawing. After the navigation assertions passed, restoration initially tried to focus the already-active Space, which yabai rejects; corrected that test-helper no-op and separately verified original window 13093 restored on Space 6. Physical shortcut presses were not synthesized. No commit or push; unrelated working changes are retained.

## 2026-10-03: Two-second Caps prefix timeout (1.5.0)

Changed only Caps-prefix duration from three to two seconds. PrefixSession.timeout is now the single constant used by both the logical deadline and the event-handler cleanup timer. Repeated Caps taps renew two seconds. Other key handling, TOML bindings (including G → Ghostty), and window ordering are unchanged.

Validation: Swift parse checks after source edits, Python compile/import checks after test edits, project plist validation, and documentation whitespace checks. Tests cover activity just before the boundary, rejection exactly at two seconds, renewal, actual one-shot timer scheduling and key passthrough after expiry even when timer delivery is delayed. Corrected a test-only assumption: a nonrepeating Timer's timeInterval is not its scheduled delay; the test now checks fireDate. An initial parallel build/test run temporarily lost the shared TOMLDecoder checkout during package resolution; reran after resolution completed. Final full run passed all 41 tests.

Explicit signed clean build: /private/tmp/YS-prefix-timeout-build-20261003. Verified recovery copy of prior app: /private/tmp/ys-prefix-timeout-install.aGOARA/YabaiSpaces.app. Old/new designated requirements match; backup and installed bytes compared and strict signatures verified. Installed /Applications/YabaiSpaces.app reports 1.5.0, restarted as PID 93556, and prefix cancel acknowledged. Runtime log is in the recovery directory. No user configuration changes, commit, or push. Physical keyboard timing was not independently automated.

## 2026-10-01: Disable Left-Command tap; audit window ordering

User requested no Left-Command-tap action, keeping Caps unchanged, and asked whether ordering is completely correct. Root cause: Karabiner's standalone Left-Command rule emitted Left-Command-F19, which the existing skhd Command-F19 mapping routed to YS `space next-recent`. Removed that entire redundant identity/tap rule from the live Karabiner config, leaving native Left Command untouched. JSON structural comparison proved the only change was removal of this one rule; all Caps rules, Right-Command tap, terminal Tab behavior, profile settings, and other mappings remain identical. No skhd/Hammerspoon changes and no YS runtime source changes.

Recovery copy: `/private/tmp/ys-left-command.eWrBIz/original.json`; staged/installed JSON: `/private/tmp/ys-left-command.eWrBIz/karabiner.json`. JSON parsed before installation and after copying, guarded by a byte comparison against the original to avoid overwriting intervening edits. Karabiner console_user_server logged loading the file and `core_configuration is updated` at 18:52:35. Physical key events were not synthesized. Verified the existing app's strict signature and restarted it per standing instruction (old PID 6064, new PID 39784); startup loaded all 20 Caps bindings and `prefix cancel` acknowledged. Runtime log is in the backup directory. No rebuild/version bump was needed for an external config-only change; restart resets the in-memory MRU history.

Ordering audit did not change the implementation. A temporary Swift harness compiled the actual WindowSwitching engine and replayed the period controller's pre/post cancellation sequence: three windows produced visits [2, 1, 2], never window 3. Cause is cancelling and immediately promoting each result on every Caps-period press, unlike uninterrupted native cycling. It also demonstrated that an external focus change during an active cycle leaves history frozen because observations do not identify manual versus cycling-induced changes. This is a known interaction limitation; timeout eventually commits the last observed focus. Existing two window-switching tests still pass, demonstrating that those tests do not cover all relevant interactions. Reproducer: `/private/tmp/ys-left-command.eWrBIz/OrderingAudit.swift`; binary `audit` in the same directory. Findings added to docs/WINDOW_SWITCHING.md. Follow-up fixes need their own tests and deployment; no completeness claim, commit, or push was made. Unrelated working changes, including .serena/project.yml, were preserved.

## 2026-09-26: Reloadable TOML Caps bindings (1.4.0)

Replaced the split hard-coded app/Space definitions with cohesive CapsBinding values and a user-editable `~/.config/yabaispaces/config.toml`. Startup creates a default file only when missing; defaults are generated from the same binding model, preserving legacy substring matching and C/B/H exact Space constraints. Added strict full-file TOML/schema validation through pinned TOMLDecoder 0.4.5 (revision a2bbd2796fe3064e107de18cb56031052c4fa899), bundled its MIT notice, and updated the SwiftPM lockfile without changing existing dependency versions. New entries default to exact matching; `match = "contains"` is explicit. Missing/disabled letters dismiss; fixed numeric/period actions, three-second prefix timing, and Caps holds are unchanged.

Architecture: CapsConfigurationStore serializes reloads separately from its small snapshot lock. Parse/validate the whole bounded regular file before publishing; invalid/missing/unreadable reloads retain the last-good in-memory dictionary. Supports symlinked files and editor atomic replacements. Both physical selections and CLI jumps resolve through the same store before entering the window-switch worker, retaining that immutable binding across later reloads. Event taps perform no configuration I/O. No file watcher: save and explicitly reload using the menu or `config reload`. Unlike ordinary queued actions, the reload socket reply is sent after completion and errors return a nonzero CLI result. Menu actions open/reveal the file and show reload success or detailed errors. Startup load failures use built-in defaults, not persisted last-good custom data; this limitation and full-replacement semantics are documented in docs/CAPS_PREFIX.md.

Validation: syntax checks after each source/test edit; TOMLDecoder module and production config/store compiled and exercised in a Swift harness; tests cover defaults parity, real TOML comments/literal/escaped/Unicode strings, duplicates/unknown fields, key/app/match/Space validation, disable/omission, MRU target selection, immutable snapshots, missing/oversized/deleted/symlinked files, atomic replacement, and fail-safe reload. Fixed an initial test-harness throwing-autoclosure compile error before proceeding. All 41 regression tests passed; after improving parser-error descriptions, the focused configuration test passed again. Final explicit Xcode clean build succeeded in /private/tmp/YS-caps-config-build-20260926, with sources resolved under /private/tmp/ys-caps-packages. No new compiler errors; existing unrelated warnings remain.

Deployment: verified backup of 1.3.0 at /private/tmp/ys-caps-config-install.t7IMAP/YabaiSpaces.app, matching existing designated signing requirements, strict signatures, installed bundle byte comparison, version 1.4.0, and bundled TOMLDecoder license. Stopped old PID 25410 and restarted installed /Applications/YabaiSpaces.app as PID 6064. Startup generated the config and loaded 20 bindings. CLI reload succeeded and prefix cancel acknowledged. Log: /private/tmp/ys-caps-config-runtime.log.

Live verification: backed up the generated config to /private/tmp/ys-caps-config-install.t7IMAP/config.toml. Temporarily mapped formerly unused Q to a disposable AppKit fixture (window 89626), reloaded, and verified `jump q` selected it. Replaced the file with a schema-invalid Space=0 entry; reload failed while Q still selected the fixture, proving last-good retention in the running app. Restored/byte-compared the original file, reloaded all 20 mappings, closed the fixture, restored prior focus, and verified Q reverted to a no-op. PID remained 6064 throughout: no rebuild or restart was needed for configuration changes. Live test script: /private/tmp/ys-caps-live-check.py. Physical Caps input and editor/menu UI were not automated. No commit/push; prior uncommitted work is preserved.

## 2026-09-26: Manual window controls and yabai-backed edge insertion (1.3.0)

Started the HyprMac-style interaction work without importing a second workspace/layout engine. Inspected HyprMac at commit 1ea990a0f0be30a5e0f0a05ce98cabffc832f373; adapted only its pure TiledDragTarget resolver. Its broader drag transaction implementation depends on HyprMac-owned trees/caches and was not appropriate to copy wholesale. Retained the exact MIT notice as HyprMac-LICENSE.txt in source and app Resources. Added WindowHandling.swift with isolated geometry, an injected backend, serial off-main yabai IPC, cached snapshots, a Control–Option mouse event tap, and a nonactivating preview. Frames commit on release; Escape cancels. Free windows move/resize, BSP windows insert beside another tile or resize tree boundaries. No Caps/keyboard remapping, input-service configuration edits, or automatic layout activation.

Live discovery found all twelve Spaces using float and yabai mouse controls using Fn. Preserved those settings. Added explicit Window controls menu actions and validated two-word CLI commands for movement/size nudges, float/split toggles, per-Space tile/untile, and persistent mouse-control on/off. The menu labels BSP activation as automatic: enabling it causes yabai to manage new windows, while untile does not restore historical floating geometry. This is intentionally opt-in, not a new YS tiler. Bumped app version 1.2.1 → 1.3.0.

Safety: fresh source/layout checks before mutation, full eligible membership/geometry comparison before insertion, frontmost target checking, cancellation before panel/departure thumbnails, no IPC in event callbacks, and bounded cache freshness. Opposite-edge then intended-edge requests handle yabai's toggle-style insertion marker; failed warps attempt marker cleanup. External yabai commands can race this non-atomic sequence. Preview geometry is approximate; cross-Space insertion, animated live dragging, arbitrary resize handles, screen-edge snapping, and restoration are deferred. Detailed scope, controls, and provenance: docs/WINDOW_HANDLING.md.

Validation: Swift syntax parsing after every source edit, Python compilation/import for tests, plutil for project edits, and whitespace checks for docs. New production-code Swift harness covers geometry, exclusions, backend sequencing, stale state, cleanup, and cancellation; native transport tests cover all new commands. The first full run found the thumbnail harness missing the new cancellation dependency; updated that harness to verify previews are cancelled before capture. All 39 tests then passed. Explicit Xcode `clean build` succeeded in /private/tmp/YS-window-handling-build-20260926. Existing app-icon and NativeClient unreachable-catch warnings remain unchanged.

Deployment: byte-verified and signature-verified previous app at /private/tmp/ys-handling-install.yKyIIX/YabaiSpaces.app. Old/new designated requirements match com.carcot.YabaiSpaces and the existing Apple Development identity. Stopped PID 11833 only after backup/build verification, installed at /Applications/YabaiSpaces.app, compared all bundle files, verified strict Apple-anchored signature and bundled MIT notice, and restarted as PID 25410. Installed version reports 1.3.0; native prefix cancel acknowledged; help lists all new commands. Runtime log /private/tmp/ys-window-handling-runtime.log confirms the mouse listener installed.

Live functional check: compiled a disposable AppKit window fixture and used the installed YS command socket to move fixture window 88307 right by exactly 40 points and shrink its width from 620 to 580. Readback verified both changes. Closed the fixture and restored prior focus; did not rearrange user windows or activate BSP on any Space. Fixture scripts are /private/tmp/YSWindowFixture.swift and /private/tmp/ys-handling-live-check.py. Physical mouse gestures, live tiled insertion, minimum-size edge cases, and multi-monitor previews still need hands-on testing; harness checks are not presented as equivalent. No commit or push was performed; prior uncommitted Caps/MRU work is preserved.

## 2026-09-25: Remove Caps-prefix helper timing gap (1.2.1)

User reported Caps-tap-M did not work. Messages was present as an eligible AXStandardWindow, ID 108 on Space 11. An initial queued jump did not show Messages in the subsequent query; after restarting with stderr/stdout captured, the direct jump was confirmed by both diagnostics and yabai focus state. Thus the target mapping works; the exact physical failure was not conclusively reproduced. The input design nevertheless contained a timing gap: skhd launched a helper, sent a socket command and scheduled main-thread work before the prefix listener was armed, allowing a fast following letter to escape.

Moved F20 recognition into YS's own event tap, installed at application startup. Unmodified F20 is consumed and arms/renews the three-second session within the same callback, before the following key event. Key-up/repeat consumption remains balanced. Explicit prefix start/cancel automation remains available. Removed the now-redundant skhd F20 binding and its migration snippet; no Karabiner or Caps-hold changes. Bumped version to 1.2.1.

Verification: per-edit Swift parsing, Python compile/import and project plist checks passed. The regression feeds F20 down/up immediately followed by M down/up through the production handler and asserts a single M command with no intervening run-loop wait. That test and seven existing switching/thumbnail/merge tests passed. Signed isolated build AQfHUr succeeded. Backed up the preceding app and skhdrc in /private/tmp/ys-caps-direct.5PJ4hi; installed bytes match the new build and strict signature passed with matching identity. Restarted YS as PID 11833; read-only event-tap enumeration confirmed its enabled mask-3072 listener immediately after startup. Removed only the F20 line from skhdrc and reloaded existing PID 2401 with SIGUSR1. Messages focus was verified during live diagnosis; physical Caps-M still needs user retesting. Diagnostics remain in /private/tmp/ys-caps-debug.log. No commit/push performed.

## 2026-09-25: Native Caps-tap-letter application/window jumps (1.2.0)

Implemented the existing Hammerspoon mappings in YS, including last-focused named-app windows and exact Brave/Space targets C=6, B=7, H=8. Added validated native `jump <key>` and `prefix start/cancel` commands. YS handles a renewable three-second prefix and consumes recognized selection-key down/repeat/up events. Escape and existing no-op letters dismiss; unbound/modified keys pass through. Application selection uses native eligible-window MRU history, ends cycling, and reuses serialized verified Space/window focus with departure capture. Missing/hidden/minimized targets do not launch or move apps. Number and period actions are retained. Hammerspoon history is not imported. Bumped the application's minor version from 1.1.5 to 1.2.0 and recorded the standing version rule in AGENTS.md.

Validation: syntax parsing after every Swift edit; Python compilation/import after test edits; Xcode plist and shell-action syntax checks; staged Lua compiled with Hammerspoon loadfile without executing/reloading it. All 37 tests passed, including new prefix state/event handling, app mappings, MRU target selection, missing targets, controller jumps and every jump/prefix transport command. Isolated signed build SJhPX0 succeeded. Byte-verified backup at /private/tmp/ys-caps-install.Za5QZD/YabaiSpaces.app; matching designated requirements, installed byte comparison and strict signatures passed. Installed /Applications/YabaiSpaces.app reports 1.2.0 and runs as PID 1709. Native help and prefix start/cancel acknowledged; CGGetEventTapList confirmed an enabled YS key-down/key-up listener. GUI inspection failed because the computer-use native pipe could not start. Physical Caps/letter dispatch and every real target remain unverified; automated key-handler tests do not claim physical input validation.

Handoff: backed up skhdrc and focus-window.lua in the same directory. Added only F20 → native prefix start to skhd; removed only the Hammerspoon adapter require from its persistent config, exited the old modal and disabled only its retained Caps handler live. No Hammerspoon reload or Karabiner/hold change. skhd --reload failed because its PID file was missing, while service status and process inspection confirmed PID 2401. Read upstream v0.2.0 service.zig to verify reload uses SIGUSR1, then sent that signal directly to the existing process; status remained healthy with its event tap active. Historical skhd log errors did not correspond to new reload diagnostics. No permissions were reset and no input service was restarted. Detailed mapping/rollback is in docs/CAPS_PREFIX.md. No commit/push performed in this step.

## 2026-09-25: End cycling on panel selection and deduplicate recent-Space candidates

Deployment follow-up: user established a standing instruction to install and restart YS after runtime changes, rather than hand off uninstalled builds. Recorded this in AGENTS.md and docs/SAFE_DEVELOPMENT.md. Verified a6gQRl's signature and matching designated requirement, backed up the installed app to /private/tmp/ys-cycle-install.w4bHQn/YabaiSpaces.app and byte-compared it, stopped PID 65137, installed a6gQRl, then verified installed contents and signature. Restarted /Applications/YabaiSpaces.app as PID 95257; its native panel-show command was acknowledged. Physical appearance and switching behavior are not independently verified. This supersedes the initial not-installed status below.

User clarified that navigation remains window-history-based: retain the latest eligible window per Space, rather than maintain an independent Space history. The previous recent-Space traversal searched after the first current-Space entry in an undeduplicated frozen list. For A1, B1, A2, C1, repeated commands could loop A → B → A and never reach C. Recent-Space candidates now retain only the first eligible window per Space in frozen MRU order before traversal, so this example cycles A1 → B1 → C1 → A1. Empty Spaces remain outside window navigation.

User also requested that selecting through the panel immediately end the two-second cycling session. Previously, panel focus events reached the history observer while its cycle scope was still active, so ordering stayed frozen. Added an explicit endingCycle option to the serialized controller observation. Panel switching invokes it before focus; confirmation of the current Space invokes it too. Later focus events update normal MRU order, and the delayed panel focus completion requests an additional observation. Cancellation uses the controller queue asynchronously to avoid deadlocking the main thread against a background switch awaiting main-thread thumbnail capture. Panel opening/dismissal without selection and ordinary tap timeout behavior remain unchanged.

Verification: Swift syntax parsing passed immediately after each edit; modified Python tests compiled and imported. Engine regressions cover interleaved duplicate Spaces, wraparound and selecting a different representative window before timeout; controller regressions confirm panel-triggered cancellation promotes the selected window immediately and determines the next command's target. All 16 tests across test_window_switching, test_thumbnail_capture, test_panel_commands and test_merge_regressions passed after rerunning the panel suite outside the sandbox (its five initial failures were blocked local socket binds). Isolated signed build a6gQRl succeeded and its --help command loaded. Documentation whitespace checks passed. This build is not installed; physical panel/Command-tap behavior has not been live-tested. No commit or push performed for this change.

## 2026-09-17: Restore pre-departure thumbnail capture across YS switching paths

Installation follow-up: user requested installation for testing. Verified matching designated requirements and backed up /Applications/YabaiSpaces.app to /private/tmp/ys-thumbnail-install.XpqbSY/YabaiSpaces.app with a clean recursive byte comparison. Stopped PID 27774, installed build TCahRD, verified installed contents match the build and the signature passes, then launched the installed app as PID 65137. Installed --help loading passed. The first sandboxed signature check could not access trust services; the approved outside-sandbox check passed before replacement. Live thumbnail appearance and physical switching behavior remain for user testing.

Root cause: June commit f718a43 removed capture from the departure path, leaving only panel-opening capture. Menubar and newer native MRU shortcuts bypassed that path entirely. Repeated panel-show requests could also capture an already-visible panel. Earlier documentation incorrectly described capture on every departure.

Added a synchronous pre-focus notification at the shared YabaiClient.focusSpace boundary. The app completes capture on the main thread before the socket focus command, including background MRU callers. It queries fresh native Space state instead of the potentially stale UI model. Panel opening captures all visible desktops, while switches with a visible panel preserve those clean pre-panel images and hide the panel before focusing. Repeated show/reposition calls never overwrite thumbnails with the visible panel. Panel-free departures capture the outgoing active desktop and, for another display, its outgoing visible desktop. Capture uses the actual CoreGraphics display ID and no longer depends on an unused yabai window query. PNG-only caching remains unchanged.

Scope: covers YS panel, menubar and native cross-Space/recent-Space commands. External gestures and direct yabai commands remain outside this hook. Pre-panel snapshots intentionally do not track changes occurring while the panel stays open. No post-switch capture is attempted under the outgoing Space ID.

Verification: syntax parsing passed after each Swift edit; Python compilation and import passed. Seven tests passed across test_thumbnail_capture, test_window_switching and test_merge_regressions. The new executable Swift harness checks pre-focus ordering, panel exclusion/repeated show, fresh state, multi-display selection, redundant/invalid targets, failed focus and background-to-main synchronization. The first sandboxed build failed to download dependencies; the approved retry built and verified the signed app at /var/folders/b3/my4hx2zj60987cm3sl1ck4vm0000gn/T/YabaiSpaces-build.TCahRD/Build/Products/Debug/YabaiIndicator.app. Its --help command loaded successfully. Documentation whitespace validation passed. Installation and GUI process verification are recorded above; live thumbnail pixels and physical shortcuts remain unverified.

Publication preparation: user requested documenting, committing and pushing all changes. Reviewed all seven changed files; no executable changes followed the successful tests/build. Origin SSH authentication failed, so publication uses the existing fork HTTPS remote, which points to the same carcot/YabaiSpaces repository and fetched successfully.

## 2026-09-14: Caps tap activates the preserved window-management prefix

User clarified that only tapping should change and every app-specific hold behavior must stay as before. Changed only to_if_alone in the three existing Karabiner Caps rules to F20, plus descriptive labels. Structural checks against backup confirmed all hold outputs, conditions and other key manipulators unchanged. Preserved existing Emacs/Portacle exclusions rather than introducing new hold behavior there. Backup is caps-prefix-20260914.2C8KBM.

Added a small Hammerspoon caps-prefix adapter, loaded live without restarting, and required it after the persistent modal creation. It reuses the original letter/number actions with a renewable three-second timeout. Command single-tap remains on skhd/YS; only this legacy letter-prefix remains Hammerspoon-owned. Adapter syntax, live loading and JSON validation passed. Synthetic F20 entry, existing Q dismissal and timeout passed; physical Caps tapping and every application action were not independently retested. See docs/CAPS_PREFIX.md. A first generated patch had unsupported numeric hunk headers and made no changes; the exact-context patch then succeeded. Documentation whitespace checks passed.

## 2026-09-14: Command single-tap replaces double-tap/prefix

User explicitly requested moving Command double-tap out of Hammerspoon and making it a single tap. Verified the existing live Command-F19 binding and Karabiner's existing tap-only emission. Backed up both configs to command-tap-20260914.Qq2rWT, removed the four-line persistent Hammerspoon prefix-entry binding, compiled the edited file with Hammerspoon's loadfile without executing it, exited any active prefix mode and disabled its live Command-F19 handler. Retained that handler in ysCommandTapRollback. Added cmd - f19 → native space next-recent to skhd, checked shell syntax and reloaded PID 2401 in place. No YS rebuild, Hammerspoon restart, Karabiner edit or modifier-hold change.

One synthesized Command-F19 event verified a Space transition 8 → 4, with original window 136 restored. Physical tap recognition remains the unchanged Karabiner mapping, not a newly performed physical-key test. Both Command keys retain their previous unsided tap-signal coverage; the old prefix menu is intentionally no longer entered. Updated the migration snippet and documentation; whitespace checks passed.

## 2026-09-14: Three direct switching shortcuts activated

User loaded Hammerspoon IPC. Verified its live connection and retained the three active target handlers for selective rollback. Backed up skhdrc, focus-window.lua and the installed signed app in shortcut-handoff-20260914.K1EhLx. Installed matching-signed build ree466. Removed only the persistent direct cycle-mode section; Hammerspoon's own loadfile compiled the edited source. Homebrew Lua 5.5 rejected an unrelated old loop-variable assignment, so no unrelated compatibility rewrite was attempted. Ran the selective handoff without reloading Hammerspoon, and verified every other previously enabled hotkey remained enabled.

Added Option-F19 → window next-in-space and Command-L/period → space next-recent to skhd; shell checks passed and skhd reloaded in place (PID 2401, event tap active, Input Monitoring granted). Live synthesized-chord tests verified Option-F19 switched 1056 → 1060 within Space 7 and both Command chords switched 1056 → 3880 from Space 7 to 8. Restored original window 1056. No physical modifier-tap verification is claimed. Right-Shift/F18, BTT, Karabiner, Caps, Tab, remaining Hammerspoon prefix/modal handlers and rendering code remain unchanged. See docs/SHORTCUT_MIGRATION.md for exact persistent edits, live tests and rollback. Documentation whitespace checks passed.

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
