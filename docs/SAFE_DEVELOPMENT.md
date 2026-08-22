# Safe local builds

## Current state — September 13

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
