# YabaiSpaces 1.13.0

Fresh clean universal app build with updated keyboard-routing, installation and recovery documentation. **This is not a new YS sleep/wake fix.** The recent shortcut failure was repaired in the separate skhd installation; that repair, skhd binaries, private remap configuration and macOS permission grants are not bundled with YS.

## Changes since 1.12.0

- Document the current two-layer local skhd setup: experimental tap/hold remapping plus separate high-level shortcut dispatch, with F20 consumed directly by YS.
- Document recovery from skhd signing/background-registration failure, the distinction between registration success and an actually running event tap, and user approval of Accessibility.
- Clarify the retained pqrs virtual-HID dependency and why the ordinary skhd binary's older driver-pin warning is not evidence to downgrade the working experimental bridge.
- Rebuild and package the existing YS runtime as **1.13.0**. Apart from version metadata, YS capture, history, keyboard handling and window behavior are unchanged from 1.12.0. The memory fix and shared screenshot service remain included.

## Download and verify

Assets: `YabaiSpaces-1.13.0-Universal.dmg` and `YabaiSpaces-1.13.0-Universal.dmg.sha256`. The DMG contains **YabaiSpaces.app** and an Applications shortcut. Download both files into the same directory:

```sh
shasum -a 256 -c YabaiSpaces-1.13.0-Universal.dmg.sha256
```

SHA-256: `786b233869a50028c7a183fe7cc835a5c25b68b1d232d733595fa58c0f8e6a07`.

**Distribution warning:** Apple Development signed, **not Developer ID signed/notarized**. Local launch and signature checks do not establish Gatekeeper acceptance on another Mac. Follow the [installation guide](https://github.com/carcot/YabaiSpaces/blob/v1.13.0/docs/INSTALLATION.md); do not disable Gatekeeper or SIP to install YS.

## Verification and limits

All **56 tests passed with no skips in 105.504 seconds**, including both capture backends' real physical-footprint workloads, deterministic ownership/failure checks, real-pixel freshness/panel exclusion and capture-before-focus ordering. Plain/excluded workload growth stayed below 1 MiB after warm-up. Native commands, history/focus, Caps/configuration, border, window handling and packaging regressions also passed.

The explicit clean Release build contains arm64/x86_64 slices. Mounted DMG contents, version/identity, strict signature, both architectures, Applications link and image checksum were verified against the build. Its exact app was installed with a verified working-app backup, matching designated requirement and clean replacement, restarted, and checked through healthy native diagnostics and two actual panel open/close cycles. Publication results are recorded in [SESSION_LOG.md](https://github.com/carcot/YabaiSpaces/blob/v1.13.0/SESSION_LOG.md).

Tested locally on Apple Silicon, macOS 26.6.2 and yabai 7.1.25 with SIP enabled. Intel runtime, every physical shortcut/click, multi-display/fullscreen cases, another actual sleep/wake cycle and multi-day memory behavior are not established by these tests. Existing asset, unreachable-catch and AppIntents warnings remain unrelated. Screenshot caches/history reset on app restart; external Space switches still lack YS's pre-departure capture hook.

Upgrades must preserve the working app/configuration, quit YS, replace into a clean `/Applications/YabaiSpaces.app` destination, then launch and verify. Installing this app does not install or repair skhd, switch keyboard ownership, or grant macOS permissions.
