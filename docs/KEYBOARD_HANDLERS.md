# Keyboard handler audit — September 13, 2026

Audited main dcc537f2 without removing handlers. Subsequently, the F18 sender changed from ysctl.py to YS's native command mode; see NATIVE_COMMANDS.md. The audit's keyboard ownership conclusions remain unchanged.

## Active paths

- Karabiner recognizes a right-Shift tap and emits F18. skhd invokes the YS executable with `panel activate-selected-or-show`. Its command process sends to the existing GUI instance, which owns visibility and selection.
- YS registers two immediate Carbon hotkeys: Hyper-Space (keycode 49, toggle) and Hyper-F18 (keycode 79, activate-selected-or-show compatibility behavior). Preserve Hyper-Space while BetterTouchTool still uses the existing gesture route. Hyper-F18 is no longer needed by the current skhd F18 rule, but other callers have not been exhaustively inventoried.
- PanelManager installs local event monitors while the panel is open. Arrow/Return/Space/Escape navigation calls the delegate's handleKeyEvent; mouse, gesture and global-event monitors support dismissal. These are panel interaction semantics, not the old right-Shift tap detector, and must not be removed indiscriminately.

## Dormant implementation

ComposableHotkey implements CGEventTap-based tap/hold/release recognition. A repository-wide registration search found only the two immediate non-modifier bindings above. HotkeyManager selects Carbon for both, so the default configuration does not instantiate ComposableHotkey. Thus the old specialized right-Shift event tap is already inactive; deleting the class would be source cleanup, not another live input migration.

## Safe next scope

Before removing compatibility code, inventory external callers and any configurable paths. Preserve panel navigation and dismissal, timing, cursor restoration, MRU and previous-Space behavior. Karabiner replacement stays deferred for the protocol incompatibility documented in SKHD_GRABBER_RESEARCH.md. No keyboard-handler code was removed in this audit.
