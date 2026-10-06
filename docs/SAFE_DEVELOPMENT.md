# Safe local builds

## October 6 universal Release package — 1.8.0

The exact app from `YabaiSpaces-1.8.0-Universal.dmg` is installed at `/Applications/YabaiSpaces.app` and running as PID 70844. The clean Release build is `/private/var/folders/b3/my4hx2zj60987cm3sl1ck4vm0000gn/T/YabaiSpaces-release.snGYwv`; its full log is `build.log`, with packaging output in `/private/tmp/YS-publication-build-20261006.log`. Both arm64/x86_64 slices, strict signatures, matching designated requirement, mounted-image/build/installed contents, native command acknowledgment, and healthy focus diagnostics were verified. All 50 tests passed; `/private/tmp/YS-publication-tests-20261006.log`. GitHub publication still requires repository write access; package details and distribution limits are in `RELEASE_1.8.0.md`.

Recovery copies are `/private/tmp/ys-publication-install-20261006/YabaiSpaces.app` and `/private/tmp/ys-publication-install-20261006-2/YabaiSpaces.app`. The initial merge-copy left obsolete Debug files, failed content comparison, and restored/restarted the verified old app. The successful retry moved the stopped installed bundle aside before copying into a clean destination. Its retired bundle and deployment/diagnostic record remain in the second recovery directory. Replacement must preserve full-bundle rollback, not merge a Release copy into a Debug installation. No input configuration, focus-signal protocol, app version, or privacy authorization was changed during this release packaging/deployment.

`build-dmg.sh` now uses a fresh build directory and explicit `clean build`, preserves the full log, propagates pipeline failures, derives the DMG version from the built plist, verifies signatures/architectures, stages `YabaiSpaces.app` and the Applications shortcut, and verifies image integrity. It never installs/restarts the daily app itself. The application remains Apple Development signed; this packaging run did not perform Developer ID distribution signing/notarization. Older Debug deployment notes below remain historical.

Current deployment (October 6): **1.8.0**, ID-bearing focus tracking with bounded diagnostics, receipt-order window MRU/live reconciliation, and asynchronous backend workers. All 45 regression tests passed. Explicit signed clean build `/private/tmp/YS-focus-build-20261006`; byte-verified 1.7.0 recovery app, original `.yabairc`, and signal snapshot at `/private/tmp/ys-focus-install-20261006/`. Installed and restarted PID 87652. Strict signatures, matching designated requirements, identity/version, bundle bytes, new event validation/intake/reconciliation, and five owned labels verified. Only the legacy YS focus-refresh registration was replaced; other refresh consumers are retained. No keyboard/input-service/permission changes. Live verification limits and measurements are recorded in SESSION_LOG.md. Roll back affected signals/configuration before launching the old app, which cannot accept the event protocol; see FOCUS_TRACKING.md. Older deployment entries below are historical.

Previous deployment (October 6): **1.7.0**, cycling border thins from three points to zero over its renewable two-second deadline, with its inner edge remaining flush against the window. All four targeted border/history/thumbnail tests passed, including actual AppKit movement, thickness, renewal, and adjacency checks. Explicit signed clean build `/private/tmp/YS-thinning-build-20261006`; byte-verified 1.6.0 recovery app at `/private/tmp/ys-thinning-install-20261006/YabaiSpaces.app`. Installed and restarted PID 41390. Bundle bytes, strict signatures, matching designated requirements, version, and native command handling verified. No input-service or configuration changes. See SESSION_LOG.md.

Previous deployment (October 6): **1.6.0**, cycling-history correction, temporary focused-window border, Caps-period removal, and Command-L restoration. All 42 tests passed. Explicit signed clean build `/private/tmp/YS-cycling-build-20261005`; verified 1.5.0 recovery app and original skhdrc at `/private/tmp/ys-cycling-install-20261005/`. Installed and restarted PID 24802. Bundle bytes, strict signatures, matching designated requirements, version, and native command handling verified. skhd PID 2401 reloaded with only Command-L removed and its event tap healthy. Live checks verified three-Space traversal, border movement/expiry, and external-focus cancellation/history; original window restored. See SESSION_LOG.md.

Current deployment (October 3): **1.5.0**, two-second Caps timeout. Explicit clean build `/private/tmp/YS-prefix-timeout-build-20261003`; verified previous-app backup `/private/tmp/ys-prefix-timeout-install.aGOARA/YabaiSpaces.app`; installed and restarted PID 93556. All 41 tests passed, including timeout boundary/renewal checks. Bundle bytes, signatures, matching identity, installed version, and native command handling verified. Older deployment entries below are historical.

## Standing deployment instruction — September 25, 2026

Latest deployment: **1.4.0**, clean build `/private/tmp/YS-caps-config-build-20260926`, installed and restarted as PID 6064. Verified 1.3.0 recovery app and original generated TOML file are in `/private/tmp/ys-caps-config-install.t7IMAP/`. All 41 tests passed plus a final focused config rerun. Live reload changed Q to a disposable test window, rejected an invalid replacement while keeping the working binding, then restored all original mappings without changing the running PID. Signature/identity/bundle bytes and license resource verified. See `CAPS_PREFIX.md` and `SESSION_LOG.md`; subsequent installation notes below are historical.

Current deployment: **1.3.0**, clean build `/private/tmp/YS-window-handling-build-20260926`, installed at `/Applications/YabaiSpaces.app`, restarted PID 25410. Recovery copy of 1.2.1: `/private/tmp/ys-handling-install.yKyIIX/YabaiSpaces.app`. Bundle bytes, strict signatures, matching designated requirements, version, listener startup, and real move/resize command readbacks on a disposable window verified. All 39 regression tests passed. Physical mouse/tiled/multi-monitor checks remain; see `WINDOW_HANDLING.md` and `SESSION_LOG.md`. The deployment entries below are historical.

Current Caps-M fix: 1.2.1 build AQfHUr, PID 11833, with the F20 listener installed at startup. Backup is `/private/tmp/ys-caps-direct.5PJ4hi/`. The native listener supersedes the earlier skhd F20 binding; see `CAPS_PREFIX.md`.

Latest deployment: YS 1.2.0 build SJhPX0, PID 1709, with native Caps-prefix/application jumps. Backup and live verification details are in `CAPS_PREFIX.md`. This supersedes the a6gQRl deployment below.

After runtime changes, build/test, install the verified build at `/Applications/YabaiSpaces.app`, and restart YS before handing back to the user. The user explicitly requested always restarting after changes so the new behavior is available for testing. This supersedes earlier build-only handoff guidance below. `run.sh` itself remains build-only by default; follow it with verified backup, matching-signature checks, installation, restart, and process/command verification. Do not stop the working app until the replacement build and backup are ready. Documentation-only edits do not require a restart.

Latest installation: build a6gQRl, containing deduplicated recent-Space cycling and panel-selection cycle cancellation. Previous app backed up and byte-verified at `/private/tmp/ys-cycle-install.w4bHQn/YabaiSpaces.app`. Installed contents and signature verified; restarted PID 95257 and the native `panel show` command was acknowledged. Command acknowledgment does not establish visual correctness; physical testing remains with the user.

The deployment notes below are historical.

Native command mode is installed in build aJEclL; see NATIVE_COMMANDS.md for current validation and rollback. Executing the binary with `panel ...` now sends to an already-running instance and exits; no arguments still starts the GUI. Do not pass these arguments to older app builds, which may ignore them and launch another GUI.

## Latest deployment

After the controlled live test, merged main build 4kQMoP was installed at `/Applications/YabaiSpaces.app`. Both it and the prior VdlD77 app have verified recovery copies; see WORKING_BASELINE.md. The earlier publication notes below predate that installation. run.sh still never deploys automatically. The keyboard-handler audit in KEYBOARD_HANDLERS.md made no source or input changes.

## Current state — September 13

The source publication merges the confirmed desktop/input changes with existing main release history. It retains upstream query/error handling and has 20 focused tests, including merge regression guards. The merged source is built separately and is not installed automatically; VdlD77 remains the user-tested running app. A successful build does not substitute for visual verification before any future deployment. Existing release DMGs describe their original tags, not the newly merged source.

The signed VdlD77 build is installed at `/Applications/YabaiSpaces.app`. The user confirmed both skhd right-Shift dispatch and restored Desktop icons. `run.sh` remains build-only by default; it does not deploy or restart the daily app. Earlier installation notes below are historical. Preserve full-display capture and semantic commands together in future builds; testing panel activation alone missed a rendering regression. See `PANEL_COMMANDS.md`, `WORKING_BASELINE.md`, and `SKHD_GRABBER_RESEARCH.md` for current behavior, recovery copies and deferred work.

## Daily-use installation: September 12, 2026

Use `/Applications/YabaiSpaces.app` for daily launches. It is an identical copy of the user-confirmed working signed DerivedData bundle. Recursive file comparison and strict signing verification passed, and the designated requirement matches the source. The running instance was left in DerivedData; launching from Applications remains to be verified before setting up automatic startup.

Do not launch the repository's `YabaiIndicator.app`: it is a March build with the older `de.arsbrevis.YabaiIndicator` identity. Launching that copy preceded the reported panel failure. The old copy is preserved, not deleted.

Next steps: verify the stable launch, resolve remaining thumbnail/outline rendering, then expose semantic panel actions for skhd dispatch. Preserve timed MRU, previous-Space behavior, Caps, and terminal Tab holds. Karabiner tap detection and Hammerspoon navigation remain until replacements are verified. Unused resizing features and iCloud settings are outside this work.

`./run.sh` now builds and verifies a separate signed development copy. It does not kill, replace, or launch the running app. This deliberately replaces the old force-kill-before-build behavior, which could take down a working desktop even when compilation failed.

The build directory is a fresh `YabaiSpaces-build.*` directory under the system temporary directory, printed before compilation. Failed builds and signature checks stop the script. Strict verification requires an Apple-anchored signature; it does not prove that a build has the same designated requirement or Accessibility grant as the daily-use app. Signing still uses the project's existing Xcode settings; the script changes no identity, certificate, or permissions.

`./run.sh --launch` is optional, for deliberate development testing. It refuses if a YabaiIndicator process already exists, checks again after building, and requests launch only after a successful build/signature check. It never quits a process automatically. The two checks reduce duplicate launches but are not an atomic system-wide lock.

Do not use the temporary build as a permanent installation or login item. The known-good daily-use app remains at its existing location. A stable installation outside DerivedData and an explicit reversible deployment procedure remain separate work. Before replacing a daily-use app, retain its full bundle, compare designated requirements, and verify actual panel/input behavior afterward. No automatic permission reset or private-key export is part of this script.

Run `python3 test_run.py` for seven isolated tests. They substitute build, signing, process-query, and launch commands; they never compile or launch the actual app. Coverage includes default build-only, failed builds/signatures, an already-running app, an app appearing during build, explicit successful launch, and invalid arguments. Run `bash -n run.sh` for shell syntax validation.
