# YabaiSpaces 1.8.0 release notes

This release packages the accumulated changes since the last published 1.1.1 DMG. The app version is 1.8.0; source and local deployment details are in [README](../README.md) and [SESSION_LOG](../SESSION_LOG.md). Publication status is recorded separately; the existence of a local DMG does not mean a GitHub release has been published.

## Changes

- Native CLI dispatch replaces Python/Hammerspoon for migrated panel/navigation actions. skhd dispatches Right-Shift, Right-Command, Right-Option, and Command-period routes; physical taps still use Karabiner. Left-Command tap does nothing, and Command-L remains an application shortcut.
- YS owns the two-second Caps-letter prefix and selection directly through F20. Reloadable TOML bindings keep application/optional Space together; invalid reloads retain the current mapping. Current local G targets Ghostty, while generated defaults retain GoodNotes. Caps-period cancels rather than cycles.
- Recent-Space navigation deduplicates window history by Space and selects each Space's latest eligible window. Repeated commands freeze candidates for a renewable two-second cycle; confirmed manual focus and panel selection end the cycle and update history.
- An orange border follows the cycling target with its inner edge flush against the window and thins from three points to zero at expiry. Panel display/capture excludes it.
- Ctrl-Option mouse drags provide move/resize previews; native commands provide additional controls. Explicit tiling and nearest-edge insertion use yabai's BSP tree, not an independent YS layout manager.
- Thumbnails capture clean outgoing content before YS-controlled departures and before panel display. External Space changes cannot provide the same pre-departure hook.
- ID-bearing focus/destroy events, bounded raw intake, asynchronous state/backend workers, live reconciliation, owned signal repair, and `focus status` diagnostics improve history tracking. Receipt order is not guaranteed producer chronology; unavailable focus remains unknown rather than invented.
- README, feature/design documents, migration guidance, licensing notices, tests, and deployment/rollback instructions are updated.

## Package and verification

- [YabaiSpaces-1.8.0-Universal.dmg](../YabaiSpaces-1.8.0-Universal.dmg) contains `YabaiSpaces.app` plus an Applications shortcut.
- [SHA-256 checksum](../YabaiSpaces-1.8.0-Universal.dmg.sha256): `b8fa2e2664ec6f477e6988c8cf98414d6dc0452bf187524c91b0a2d16b4bcb47`.
- An explicit clean Release build produced arm64 and x86_64 slices. Strict signatures, matching designated requirement, package/build/installed contents, mounted-image contents, and DMG integrity were verified.
- All **50 automated tests** passed: 45 runtime regressions plus five packaging tests. The exact packaged app was installed locally, restarted, and verified through native command handling and healthy focus diagnostics.
- Packaging derives the version from the built app, uses a fresh build directory, preserves the complete build log, and fails on compilation/signature/architecture/image-verification errors rather than using stale output.

## Distribution and migration limits

The app is signed with the existing **Apple Development** identity. No Developer ID distribution signing or notarization was performed in this packaging run. Local launch verification does not establish Gatekeeper acceptance on another Mac.

Both architectures are present, but local runtime verification used the development Mac; Intel runtime behavior, every physical keyboard/mouse interaction, dialogs, and multi-monitor/fullscreen cases were not exhaustively retested. Existing asset-catalog warnings remain unrelated.

Do not install the machine's entire personal Karabiner/skhd configuration from this release. The README identifies the active local mappings and remaining Karabiner dependencies; the [shortcut migration document](SHORTCUT_MIGRATION.md) provides handoff/rollback context. The native Caps listener requires no F20 skhd rule. Owned ID-bearing focus signals must be rolled back before using an older app that rejects the new event protocol; see [focus tracking](FOCUS_TRACKING.md).

Preserve and verify the installed app before replacement, keep matching signing requirements for local permission continuity, stop the old process before replacing the whole bundle, verify contents/signature, then restart and test command handling. Copying a Release app over an existing Debug bundle can leave obsolete files; use a clean replacement with rollback protection. See [safe development](SAFE_DEVELOPMENT.md).
