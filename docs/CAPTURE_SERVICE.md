# Shared screenshot capture service — 1.12.0

All live-desktop thumbnails use `PrivateWindowCapture.captureSpace(...)`, a compatibility adapter into `ScreenshotCaptureService.capture(ScreenshotRequest)`. Implementation stays in the existing `PrivateWindowCapture.swift` compilation unit. UI/navigation code neither calls platform screenshot APIs nor owns raw capture images.

## Request, result and lifetime boundary

`ScreenshotRequest` supplies a display ID, target size and excluded window-ID set. `capture` returns `Result<Data, ScreenshotFailure>`; successful data is PNG. The adapter converts failure to `nil`, preserving the existing caller policy: only success replaces cached data.

The private serial queue and per-request autorelease pool contain capture, scaling and PNG encoding. Raw owned images remain local; no image/WindowServer handle escapes in the result. PNG encoding checks destination creation, finalization and nonempty output. Shared processing utilities also serve wallpaper loading, but wallpaper is not a screenshot backend/fallback.

| Failure | Meaning |
| --- | --- |
| `invalidRequest` | Unknown/inactive display, invalid/excessive size, or null excluded window ID |
| `captureUnavailable` | Permission/backend/window-list/image/scaling failure |
| `encodingFailed` | Failed or empty encoding |

Dimensions must be finite, at least one pixel, at most 8,192 per axis and 16,777,216 total pixels before integer conversion/allocation. The display must occur in the active-display inventory; sentinel IDs cannot silently select another display. Conversion from the model's wider display-ID type is checked.

## Private system backends

`ScreenshotBackend` checks existing Screen Recording authorization without requesting it. Its platform operations are private to the capture file:

- **Plain display:** directly imported `CGDisplayCreateImage`; its annotated Create reference is managed by Swift.
- **Excluded windows:** retain front-to-back on-screen window order and desktop/Finder content, omit requested IDs, and compose full bounds of the requested display. Dynamically resolved `CGWindowListCreateImageFromArray` returns `Unmanaged<CGImage>?`, immediately consumed with `takeRetainedValue()`.

No failure retries without exclusions. An unavailable symbol/list/image or empty composition fails closed. Dormant legacy single-window/display capture helpers and unsafe alternative function-pointer types were removed, not enabled as new backends. The internal injected image/encoder initializer is a deterministic test seam, not another production screenshot route.

## Wallpaper and navigation

`captureDesktopCG` and wallpaper caching remain file-loading operations. They share private scaling/PNG utilities with screenshots but do not substitute wallpaper for a failed capture. UI image rendering remains separate.

The service does not decide capture timing or Space attribution. Navigation still hides/excludes overlays, captures the outgoing desktop synchronously immediately before departure, then changes focus/Space. Failure preserves the previous clean cache. Panel-opening capture remains only an initial preview. No new window-capture mode or timing policy was added. See the [standing contract](../EXTERNAL_SWITCH_CAPTURE_NOTES.md#required-thumbnail-timing-contract).

## Regression coverage

`test_thumbnail_capture.py` checks:

| Check | Evidence |
| --- | --- |
| Both production backends' memory | Separate plain/excluded workloads: four warm-up plus 24 real captures, per-call pools, bounded `task_vm_info.phys_footprint` growth |
| Ownership and failure | Injected image-provider release counters across repeated successes, nil/empty encoding and unavailable capture; no fallback/retry |
| Validation | Invalid/sentinel displays, zero/negative/nonfinite/excessive sizes and null exclusions rejected before backend work |
| Pixels and timing | Actual red/green departures and contrasting blue panel prove freshness/exclusion; plain capture observes panel pixels before exclusion; production-method harness verifies hide → capture → focus and checked window-ID conversion |

`test_merge_regressions.py` guards the adapter, ownership path, absence of dormant helpers and direct screenshot API bypasses elsewhere in Swift code. Existing Space-only click guards remain. Source guards supplement behavioral memory/pixel checks; they are not substitutes.

Real-screen memory/pixel tests explicitly skip if existing Screen Recording access is unavailable, without requesting it. Injected ownership/failure tests take no screenshots. Skips do not prove safety. Short footprint tests do not establish multi-day leak freedom or absence of unrelated framework allocations. Full-suite and deployment measurements are in [SESSION_LOG.md](../SESSION_LOG.md).

## Extending capture

Add new backends only behind this ownership/PNG boundary, with explicit source semantics and applicable lifetime/failure, footprint, actual-pixel and order/exclusion checks. Audit Create/Copy ownership even when callers and cache format are unchanged. Centralizing an entry point alone did not prevent the earlier regression; inheriting these invariants is the acceptance criterion. See [the regression lesson](../MEMORY_LEAK_FIX.md#regression-lesson-protect-the-invariant-not-just-the-old-implementation).
