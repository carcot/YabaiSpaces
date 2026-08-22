# Grabber research — September 13, 2026

Keep the working Karabiner tap/hold recognition plus skhd high-level dispatch. No input services, drivers, permissions or mappings were changed during research.

## Findings

- Installed skhd.zig v0.2.0 (7e95d99) pins DriverKit 6.14.0 and encodes protocol 5. Installed Karabiner DriverKit 8.5.0 uses protocol 7, different request numbering, and changed request/response transport. Changing only the version constant is insufficient.
- Historical `/var/log/skhd-grabber.log` repeatedly records `applyLatestRules failed: Timeout`. Source shows virtual-keyboard readiness timing out before physical-keyboard seizure. This is consistent with the proven protocol incompatibility; no additional driver-side mismatch log was recovered.
- `--grabber-test-rule` also has a separate protocol bug: after nonempty rules are applied, the server treats the connection as a subscription and discards further messages, while the CLI sends `bye` and waits for acknowledgment. Local logs contain matching unexpected-data warnings. The diagnostic hardcodes a Caps Lock rule and sample keyboard ID; do not run it against the live setup.
- An early test rule lacked a required device guard, but the later saved rule included one. The syntax error alone does not explain all failures.
- Both grabbers require exclusive ownership of a keyboard. skhd detects the old `karabiner_grabber` process name, not this installation's `Karabiner-Core-Service`; absent warnings do not establish safe coexistence.

## Fix direction

The maintainer acknowledges the newer protocols in [issue 51](https://github.com/jackielii/skhd.zig/issues/51) and is waiting for stabilization before upgrading. No timetable or compatible release was found. Fetched main e4770df has no grabber/client changes beyond the installed release. Older sleep/reconnection fixes are already included in v0.2.0.

Future work is an isolated protocol/transport update, correct bounded diagnostic exchanges, and current conflict detection, followed by a controlled keyboard-ownership transfer with rollback. Do not downgrade the shared driver or disable working Karabiner mappings to test a hypothesis. Even skhd-only remapping still uses the Karabiner virtual-HID driver.

## Primary sources

- [Installed-version client](https://github.com/jackielii/skhd.zig/blob/7e95d996901d25536d8e5175ded7199d832f169d/src/grabber/Vhidd.zig)
- [Grabber daemon](https://github.com/jackielii/skhd.zig/blob/7e95d996901d25536d8e5175ded7199d832f169d/src/grabber/main.zig)
- [Diagnostic CLI](https://github.com/jackielii/skhd.zig/blob/7e95d996901d25536d8e5175ded7199d832f169d/src/grabber_cli.zig)
- [DriverKit 8.5.0 version](https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/blob/v8.5.0/include/pqrs/karabiner/driverkit/client_protocol_version.hpp)
- [DriverKit 8.5.0 server](https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/blob/v8.5.0/src/Daemon/include/virtual_hid_device_service_server.hpp)
- [Coexistence](https://github.com/jackielii/skhd.zig#coexistence)
