# Caps Lock tap: existing window-management prefix

On September 14, the user requested the old Command-tap-then-letter behavior on Caps Lock tap, explicitly preserving all existing app-specific hold behavior.

The three existing Karabiner Caps manipulators now emit unmodified F20 in `to_if_alone`. Their `from`, `to`, conditions and parameters remain structurally identical:

- Terminal rules: hold remains Right Control; tap no longer sends Escape.
- Screen Sharing rule: hold remains Right Control; tap now emits F20.
- General rule: hold remains Left Command; tap changes from F19 to F20.

Existing app exclusions were intentionally retained. In particular, Emacs/Portacle were excluded from the general rule and not matched by the terminal list; this change does not invent a new Caps hold mapping in those apps. Other keys and Karabiner rules are untouched. Physical Caps tap recognition was not part of the synthetic signal test.

`~/.hammerspoon/caps-prefix.lua` is an exact copy of `migration/caps-prefix.lua`. It registers F20 to enter the existing `rightcmdf19` modal, preserving its original letter/number actions and three-second timeout. A repeated tap renews that timeout. The persistent `focus-window.lua` now calls `require('caps-prefix')()` immediately after creating the modal. The adapter was also loaded into the running Hammerspoon instance without a configuration reload or history reset.

This prefix still uses Hammerspoon for its existing application/window actions. It is not a new YS keyboard detector or a completed migration of those actions to skhd. Command single-tap and the previously migrated switching shortcuts remain skhd → YS. The old Command-triggered prefix entry remains disabled.

Validation: Karabiner JSON parsed; all three Caps `to_if_alone` changes were checked against backup while asserting all remaining manipulator fields unchanged. Adapter passed Lua syntax compilation and live loading. Synthetic F20 entered the mode, the original Q no-op action exited it, and another F20 timed out after three seconds. These tests verify signal dispatch and modal behavior, not every application-selection action or physical Caps tapping.

Backup: `~/Library/Application Support/YabaiSpaces/Backups/caps-prefix-20260914.2C8KBM/` contains the preceding karabiner.json and focus-window.lua. For rollback, disable `capsPrefixHotkey`, exit `rightcmdf19`, restore both backed-up configs, and remove the added caps-prefix.lua module. No app rebuild or signing/permission changes are involved.
