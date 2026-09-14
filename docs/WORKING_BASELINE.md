# User-confirmed working baseline — September 13, 2026

## September 14 shortcut deployment

Signed build ree466 is now installed with the active three-shortcut handoff described in [SHORTCUT_MIGRATION.md](SHORTCUT_MIGRATION.md). Live skhd chord tests passed for within-Space window cycling and recent-Space switching. Hammerspoon was not restarted; its remaining hotkeys are intact. Recovery app/config copies are in `~/Library/Application Support/YabaiSpaces/Backups/shortcut-handoff-20260914.K1EhLx/`. This supersedes installation descriptions below, not earlier user-reported visual confirmations.

## Current switching deployment

Signed build De3uLb is installed with native application/window switching; it supersedes the installation descriptions below. The prior native-panel build's physical right-Shift route was user-confirmed before this deployment. The new build passed 34 automated tests and live focus-query checks for application/window switching both within Space 11 and from Space 7 to Space 12. Original window 1060 was restored. No input configuration or capture code changed, but this is not a new exhaustive visual/physical-key confirmation. Recovery copies are in `~/Library/Application Support/YabaiSpaces/Backups/window-switching-20260913.naJBcW/`. See [WINDOW_SWITCHING.md](WINDOW_SWITCHING.md).

## Native command deployment

Build aJEclL is now installed to provide native panel commands. This does not claim new user confirmation while the user is away. Both the previous merged-main app and new app are backed up in `~/Library/Application Support/YabaiSpaces/Backups/native-cli-20260913.vYncb5/`; that directory also holds the previous skhdrc. Native commands and skhd reload passed; physical-key and visual checks remain pending. See NATIVE_COMMANDS.md for exact recovery and test details. The earlier confirmed baseline copies below remain unchanged.

## Main installed after controlled test

Main source dcc537f2, signed build 4kQMoP, is now installed at `/Applications/YabaiSpaces.app` (PID 44764 at verification). The controlled test exercised semantic commands and a captured screenshot showed the panel, centered pointer, populated current-Space thumbnail and outline fallbacks for uncached Spaces. The screenshot is not a full multi-Space rendering or physical-input regression test. Verified byte-identical signed recovery copies of the installed app and previous app are at `~/Library/Application Support/YabaiSpaces/Backups/main-installed-20260913.YptHIB/YabaiSpaces.app` and `previous-YabaiSpaces.app`. The previous independently confirmed VdlD77 baseline also remains at `~/Library/Application Support/YabaiSpaces/Backups/pre-main-test-20260913.ldsJgA/YabaiSpaces.app`. No TCC resets or input configuration edits occurred. These facts supersede the earlier installation state below.

## Latest confirmed installation

The installed VdlD77 build combines semantic panel commands with the historical full-display capture fix. The user confirmed right-Shift dispatch and Desktop-icon thumbnails after deployment. Keep both features together. Previous semantic-command-only app: `~/Library/Application Support/YabaiSpaces/Backups/icons-20260913.zY2L1M/YabaiSpaces.app`. The earlier recovery archive below remains available. No new archive of VdlD77 has yet been created; the installed bundle and temporary build are not an independent durable backup. Capture experiments were shelved before command deployment, and the historical display-capture method was subsequently restored. The inventory below describes the earlier baseline, not the current source state.

## Earlier recovery baseline

The user confirms the current version works. Preserve it; do not deploy the pending capture experiments or assume the checkout reproduces it.

- Running application: `/Applications/YabaiSpaces.app`, PID 57400 at verification.
- Bundle ID: `com.carcot.YabaiSpaces`; Team: `7CJ3BM3AGT`.
- Signing timestamp: September 12, 2026, 14:48:52.
- CDHash: `f7ce1624786e98d83e0549ac439968e8e54d8b05`.
- Durable backup: `/Users/carlcotner/Library/Application Support/YabaiSpaces/Backups/confirmed-20260913.qZ8UzV/YabaiSpaces-working.zip`.
- Archive SHA-256: `77e4f27bf6478e8f9015b5d1ed7d71795a9b05886c493851422c3616c5f96a6f`.

The backup was extracted into a fresh temporary directory, recursively compared with the installed bundle, and passed strict code-signature verification. This backup is outside iCloud Desktop/Documents. It is local recovery protection, not protection against loss of the Mac. It does not back up macOS privacy authorization.

## Source review

The backup directory also contains the full tracked diff, status, HEAD identifier, a source-review archive including the untracked development documentation/tests, and SHA256SUMS.

The checkout is detached at `4bab3e8`. The later v1.1.5 display-capture fix exists in history but is not part of this checkout. Do not switch branches, reset, or cherry-pick as part of preserving the working binary.

- `PrivateWindowCapture.swift`: unverified capture experiments: ABI changes, ScreenCaptureKit, coordinate/compositing changes, removal of white fallback, and Finder-icon enumeration. Not approved as a replacement for the working binary.
- `YabaiAppDelegate.swift`: mixed changes. Preserve right-Shift confirm-or-show handling and prior logging changes. The added thumbnailTasks property and asynchronous capture block belong to the unverified capture experiments.
- `HotkeyManager.swift` and `PanelHotkey.swift`: right-Shift confirm-or-show support, previously physically verified by the user.
- `run.sh`, `test_run.py`, and `SAFE_DEVELOPMENT.md`: isolated build safeguards; default builds do not deploy. Explicit development launch still requires manual care.
- `.serena` files: pre-existing changes, preserved.
- `SESSION_LOG.md`: historical actions and failed experiments, not proof that every intermediate build worked.

No source was reverted, no build was run, and no process or input/iCloud setting was changed during baseline preservation. Before any future deployment, review mixed changes, build separately, retain this backup, and verify behavior and actual Screen Recording authorization. Matching signing identity alone did not preserve that authorization during earlier tests.
