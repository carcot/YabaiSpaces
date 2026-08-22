# User-confirmed working baseline — September 13, 2026

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
