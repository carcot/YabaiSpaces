# YabaiSpaces development workflow

After changes that affect YS runtime behavior, build and test them, install the verified build at `/Applications/YabaiSpaces.app`, and restart YS before handing the work back to the user. The user needs the changed behavior running for testing; a successful build alone is not completion. This deployment and restart are authorized by the user's standing instruction.

Before replacement, preserve and verify a backup of the installed app, verify the new build's signature and matching designated requirement, and stop the existing YS process. Verify installed contents and signature, launch the installed app, and confirm the new process and command handling. If a build, installation, or restart fails, report it explicitly and preserve or restore the working app. Never present an uninstalled build as running.

See `docs/SAFE_DEVELOPMENT.md` and `SESSION_LOG.md` for deployment details. Documentation-only changes do not require restarting the app.

Increment the minor application version for published runtime changes, at least before pushing. Keep the installed build and documentation aligned with that version.

## Required thumbnail timing — do not regress

The saved thumbnail must represent the outgoing desktop immediately before the user leaves it, not its appearance on arrival or an earlier panel-opening snapshot. For every YS-controlled Space departure, finish fresh capture before changing Spaces/focus. Opening the panel may capture an initial preview, but that does not replace departure capture.

The Spaces panel and other YS overlays must never appear in the thumbnail. Hide/exclude them before capture; merely requesting panel dismissal is not proof that its pixels have disappeared. Never capture the destination desktop under the outgoing Space's ID. Capture failure must not overwrite a clean cached image with a contaminated or mislabeled one.

Preserve this contract when changing capture APIs, caching, panel handling, or navigation. Changing the requirement requires explicit user approval. Keep the production ordering/content and real-pixel regressions in `test_thumbnail_capture.py`; run them when changing these paths and report any skipped pixel verification. See the [required thumbnail timing contract](EXTERNAL_SWITCH_CAPTURE_NOTES.md#required-thumbnail-timing-contract), including acceptance criteria and external-switch limitations.
