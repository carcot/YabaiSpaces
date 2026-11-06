# Keyboard handlers and recovery

## November 5, 2026: high-level skhd service recovery

The current local physical-tap path uses the separate experimental skhd remap agent/grabber and pqrs VirtualHIDDevice driver, not Karabiner-Elements' user agents. The normal `/Applications/skhd.app` service must also run: it reads `~/.config/skhd/skhdrc` and dispatches F18/F19/Command-period commands to YS. The separate remap agent reads `remap.skhdrc`, which contains tap/hold rules rather than those high-level commands. YS consumes the generated F20 Caps prefix directly. The September audit below is historical.

After the reported lid-close/wake failure, YS still answered native commands, its event taps were enabled, and Secure Input was off. The remap agent/grabber and their custom socket were alive, but the normal skhd service was absent. Starting it reported registration success while macOS killed the actual job with `CODESIGNING / Launch Constraint Violation`, then left launchd at `EX_CONFIG`. The installed November 3 bundle used a different self-signed identity without a Team ID. Its strict signature check alone did not prove that its background-service registration could launch it. A causal sleep/wake defect was not reproduced; wake may have exposed the already-invalid service installation.

Preserved/verified the installed bundle, staged the **same 0.2.1-79e0639 fast version**, signed it with the existing Apple Development identity, verified its Apple-anchored signature and installed contents, and cleanly replaced only `/Applications/skhd.app`. Re-registering without first discarding the stale service record still failed. Refreshed only `com.jackielii.skhd` through its normal uninstall/start service commands, not a global background-items reset. macOS then started the daemon but required fresh Accessibility approval. After the user enabled skhd, service diagnostics reported an active event tap, Input Monitoring granted and normal launchd running state; YS remained healthy.

Recovery copies/record: `/private/tmp/skhd-shortcut-recovery-20261105/`. The root grabber, remap agent, DriverKit installation, tap/hold rules, YS app and its focus history were left unchanged. No driver downgrade, permission-database edit, broad TCC reset or global background-items reset was performed. A warning in the ordinary skhd binary about its old pinned DriverKit version/default grabber socket does not describe the separately running experimental v8.5 bridge; do not downgrade that working bridge based only on this warning.

For recurrence, check **both** service layers and actual event-tap/process state, not only registration or socket acknowledgments. A code-signing launch-constraint error is different from a disabled input listener. Preserve diagnostics and verify the installed identity/registration before changing anything. Signing or registration changes can require the user to approve Accessibility/Input Monitoring again. Never silently reset unrelated security settings. The user confirmed Right-Shift tap, Right-Command tap, Caps-tap-M and Hyper-Space all work after repair. Another real sleep/wake cycle remains unverified; see [SESSION_LOG.md](../SESSION_LOG.md) for results.

## September 13, 2026 audit (historical)

Audited main dcc537f2 without removing handlers. Subsequently, the F18 sender changed from ysctl.py to YS's native command mode; see NATIVE_COMMANDS.md. The audit's keyboard ownership conclusions remain unchanged.

## Active paths

- Karabiner recognizes a right-Shift tap and emits F18. skhd invokes the YS executable with `panel activate-selected-or-show`. Its command process sends to the existing GUI instance, which owns visibility and selection.
- YS registers two immediate Carbon hotkeys: Hyper-Space (keycode 49, toggle) and Hyper-F18 (keycode 79, activate-selected-or-show compatibility behavior). Preserve Hyper-Space while BetterTouchTool still uses the existing gesture route. Hyper-F18 is no longer needed by the current skhd F18 rule, but other callers have not been exhaustively inventoried.
- PanelManager installs local event monitors while the panel is open. Arrow/Return/Space/Escape navigation calls the delegate's handleKeyEvent; mouse, gesture and global-event monitors support dismissal. These are panel interaction semantics, not the old right-Shift tap detector, and must not be removed indiscriminately.

## Dormant implementation

ComposableHotkey implements CGEventTap-based tap/hold/release recognition. A repository-wide registration search found only the two immediate non-modifier bindings above. HotkeyManager selects Carbon for both, so the default configuration does not instantiate ComposableHotkey. Thus the old specialized right-Shift event tap is already inactive; deleting the class would be source cleanup, not another live input migration.

## Safe next scope

Before removing compatibility code, inventory external callers and any configurable paths. Preserve panel navigation and dismissal, timing, cursor restoration, MRU and previous-Space behavior. Karabiner replacement stays deferred for the protocol incompatibility documented in SKHD_GRABBER_RESEARCH.md. No keyboard-handler code was removed in this audit.
