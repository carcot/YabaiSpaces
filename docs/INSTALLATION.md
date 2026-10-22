# Installing and upgrading YabaiSpaces

This guide describes YS **1.10.0**, including the verified [universal DMG](../YabaiSpaces-1.10.0-Universal.dmg) and its [checksum](../YabaiSpaces-1.10.0-Universal.dmg.sha256). That exact packaged app is installed locally. The retained 1.8.0 package is historical and lacks the departure-capture and Space-only thumbnail-click fixes. Download assets listed on [GitHub Releases](https://github.com/carcot/YabaiSpaces/releases), and read the [1.10.0 release notes](RELEASE_1.10.0.md) and distribution limits. A source version, local app, checked-in DMG, and published release are different things; publication status is recorded in the session log.

## Signing and Gatekeeper

**The current local app and 1.10.0 DMG use Apple Development signing, not notarized Developer ID distribution signing.** Successful local signature/launch checks do not establish Gatekeeper acceptance on another Mac. Public distribution signing/notarization remains separate work.

For a downloaded build you independently trust, follow [Apple's first-launch guidance](https://support.apple.com/en-us/102445). After an attempted launch, macOS may offer **System Settings → Privacy & Security → Open Anyway** for the relevant unverified-developer/notarization warning. Do not bypass malware/damaged-app warnings indiscriminately. Do not disable Gatekeeper/SIP or recursively remove quarantine as an installation step. A matching checksum detects a download mismatch; it does not establish that the publisher or software is trustworthy.

## Install the dependency

YS needs a running yabai daemon. Follow [upstream installation and supported-macOS guidance](https://github.com/asmvik/yabai/wiki/Installing-yabai-(latest-release)); with Homebrew installed:

```sh
brew install asmvik/formulae/yabai
yabai --start-service
```

Grant **yabai** Accessibility access in **System Settings → Privacy & Security → Accessibility**. Check that the daemon answers:

```sh
yabai --version
yabai -m query --spaces
```

The local tested baseline is yabai **7.1.25**, Apple Silicon, macOS **26.6.2**, SIP enabled. Universal packaging includes arm64/x86_64 slices but does not establish Intel runtime compatibility. Use upstream instructions when upgrading an existing yabai installation; do not overwrite `~/.yabairc`, add scripting-addition startup commands, or change SIP just for YS.

YS does not enable automatic tiling during installation. Existing yabai layouts still apply. For a fresh yabai setup intended to remain entirely manual, its `layout float` setting can be used; do not replace an existing tiling configuration without intending to change it. Fast SIP-enabled Space switching and the optional `skip_window_focus_animation` setting are explained in the [README's no-animation section](../README.md#sip-enabled-switching-and-no-animation-support); that option is for setups **without** the scripting addition, not an unconditional installation step.

## Install the app

1. Get the DMG and matching SHA-256 file from the same published release. Check the release version before expecting current-source features.
2. In Terminal, change to the download directory and verify the checksum. For 1.10.0:

   ```sh
   shasum -a 256 -c YabaiSpaces-1.10.0-Universal.dmg.sha256
   ```

   For another release, use its actual checksum filename instead. Stop if verification fails or the listed DMG is missing.
3. Open the verified DMG in Finder. On a fresh installation, drag **YabaiSpaces.app** onto its **Applications** shortcut. If a copy is already installed, use the upgrade procedure below instead of merging app bundles.
4. Launch **`/Applications/YabaiSpaces.app`**, not an app inside the mounted DMG, an old repository `YabaiIndicator.app`, or a temporary build directory. Eject the DMG afterward. Use only one running GUI copy.
5. Grant the permissions below, and restart the affected app when macOS requests it. No Xcode or Python installation is needed to run the packaged app. Source builds require Xcode and resolved Swift packages; see [development instructions](../README.md#development-and-verification).

The stable installed path is also the destination expected by the documented skhd and yabai signal commands. Launching the executable with a native command does not auto-launch the GUI; start the app first.

## Permissions by component

Open **System Settings → Privacy & Security**. Permissions apply to each listed app/executable, not to the whole toolchain at once.

| Component | Permission/purpose |
| --- | --- |
| yabai | Accessibility for window/Space control and observation; additional permissions only for optional upstream features that require them |
| YabaiSpaces | Screen Recording (or Screen & System Audio Recording) for actual desktop screenshots; Accessibility/input-monitoring authorization as required for its event taps, Caps prefix, and mouse controls |
| skhd, if installed | Its own applicable Accessibility/Input Monitoring authorization for hotkey interception |
| Karabiner, if retained | Its own macOS permissions and driver approval, following its installer; YS does not configure these |

Authorize the installed **YabaiSpaces.app** rather than a stale build copy. Signing/path changes can affect permission continuity; do not reset all privacy permissions to troubleshoot one app. No microphone/audio capture is required just because macOS groups screen and system-audio permissions under one heading.

## Choose real thumbnails

Open YS **Preferences → Button Style → Thumbnail**. **Show Menubar** must be enabled to edit this picker. The same style controls both the menu bar and floating panel; separate styles are not implemented.

- **Windows** is the default: wallpaper and window outlines, not captured screen contents.
- **Thumbnail** uses cached screenshots; Spaces without a capture fall back to wallpaper/window outlines.
- **Numeric** uses Space labels rather than desktop previews.

Open the panel for an initial visible-desktop capture. When selecting another Space, YS hides/excludes its overlays and captures the outgoing desktop again **immediately before leaving**, finishing capture before changing focus/Space. It must show the last content seen at departure, not the content at arrival or when the panel first opened. Failed clean captures preserve the previous clean image. Captures are cached in memory, not a live video feed, and reset on restart. External switches that bypass YS do not provide this pre-departure hook. See the [standing capture contract](../EXTERNAL_SWITCH_CAPTURE_NOTES.md#required-thumbnail-timing-contract).

**Show Current Space Only** controls which menu-bar buttons appear; it does not enable screenshot mode. Seeing only wallpaper in Windows mode is expected, not evidence of a screenshot-refresh failure.

## Optional keyboard integration and signals

Basic panel/menu use, the built-in Hyper-Space hotkey, and native commands do not require skhd/Karabiner. The [README's shortcut table and four skhd rules](../README.md#keyboard-setup-and-skhd) describe this machine's optional setup, not a configuration installed automatically on other Macs.

If adopting those rules, install/authorize the chosen skhd implementation, merge only the intended rules into its configuration, and reload it according to that implementation's instructions. Physical modifier taps still need the documented Karabiner tap/hold rules; skhd dispatch alone does not create them. Preserve application-specific Caps/terminal behavior rather than copying this machine's whole personal configuration. YS owns the F20 Caps-prefix listener and subsequent letter selection; **do not add an F20 skhd rule**. Left-Command tap does nothing for YS and Command-L remains an application shortcut. See [migration/rollback](SHORTCUT_MIGRATION.md) and [grabber compatibility](SKHD_GRABBER_RESEARCH.md).

YS 1.8.0 and later install/repair five labeled focus-tracking signals after their command socket starts. Do not repeatedly append duplicate registrations. Existing panel/window-refresh actions are separate; review and merge the [README's signal setup](../README.md#yabai-signals) into the existing yabai configuration if needed. Keep other consumers' actions. These local configuration files are not installed by dragging the app into Applications.

## Upgrade and rollback

1. Save a complete backup of the working installed bundle and any configuration being changed. Verify its contents/signature before stopping it. For local development replacements, verify the candidate signature and matching designated requirement before proceeding; see [safe development](SAFE_DEVELOPMENT.md).
2. Quit YS and confirm the old process has stopped. Move the old app aside; copy the replacement into a **clean** `/Applications/YabaiSpaces.app` destination. Do not merge a Release app over an old Debug bundle.
3. Verify the installed version/signature and, for a local build, compare installed contents to the verified candidate. Start the installed app, not its backup or source build.
4. Check native command handling and actual panel behavior. For focus-tracking builds:

   ```sh
   /Applications/YabaiSpaces.app/Contents/MacOS/YabaiIndicator focus status
   ```

   Healthy diagnostics do not prove physical shortcuts or thumbnails work; open the panel, inspect the chosen preview mode, and exercise the intended navigation.
5. If replacement or launch fails, retain the failed candidate for diagnosis and restore/restart the verified working app. Before rolling back below 1.8.0, restore compatible yabai signals/configuration too: older apps cannot accept the ID-bearing event protocol. See [focus tracking migration](FOCUS_TRACKING.md).

Upgrades preserve macOS preferences and `~/.config/yabaispaces/config.toml` unless explicitly changed; keep backups anyway. Restarting resets learned MRU history and screenshot caches. Installation does not automatically create a login item or install personal skhd/Karabiner mappings.

## Troubleshooting

| Symptom | First checks |
| --- | --- |
| No Spaces or navigation | Confirm yabai is running/authorized and `yabai -m query --spaces` succeeds; check version compatibility |
| Wallpaper/outlines instead of screenshots | Choose Thumbnail rather than Windows; check YS Screen Recording access, open the panel, then test a YS-controlled departure |
| An externally switched desktop has an older image | External switching lacks the pre-departure hook; it is not equivalent to a YS panel selection |
| Physical tap shortcuts do nothing | Check Karabiner tap/hold mapping, skhd dispatch/permissions, and the installed executable path; do not add an F20 rule |
| Native CLI says the server is unavailable | Start the installed GUI app and ensure only one copy uses `/tmp/yabai-indicator.socket` |
| A downloaded app is blocked | Read the signing warning and Apple's linked guidance; do not disable Gatekeeper or SIP |

The current installation and publication records are in [SESSION_LOG.md](../SESSION_LOG.md). The existence of a successful build, local DMG, or local commit is not proof that a release has been pushed/published.
