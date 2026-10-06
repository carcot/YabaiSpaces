# Focus tracking: design and implementation plan

Status: implemented in YS 1.8.0 source on October 6, 2026; deployment verification is recorded in SESSION_LOG.md. The original design was written against YS 1.7.0 and yabai 7.1.25. Keyboard bindings and permissions are unchanged.

## Implemented decisions — 1.8.0

The native executable now accepts `event window-focused <id>`, `event window-destroyed <id>`, `event reconcile`, and `focus status`. The last command returns bounded JSON diagnostics: the latest 32 raw records, receipt sequences/times, provisional operation association, metadata-resolution status, PID/local lifetime where resolvable, the first 64 navigation-history IDs, confirmed current focus, health/gap/retention counters, and snapshot/verification counts. The in-memory raw ring and pending buffer each hold at most 1,024 records; diagnostics are not written to disk automatically.

Event intake and navigation state share a short serial state queue. Separate command, observation, and registration workers perform blocking backend calls. A command carries a cancellation generation and expected target; external focus confirmed during window verification can invalidate it, and stale completion cannot restore a canceled cycle. Signal events alone do not prove whether a focus change was manual. Snapshots are guarded by receipt/lifecycle revisions and operation generations. Valid cycling retains frozen candidates; non-cycling received IDs are promoted in receipt order and the live focused window is reconciled to the front. YS's own windows are excluded from navigation and their focus snapshots do not alter navigation history.

The first release deliberately uses a full window inventory for the one-second safety check, not the proposed focused-only optimization. One successful inventory supplies current focus, eligibility, and lifetime reconciliation consistently, avoiding a second query and special handling of no key window. Live query cost is measured during deployment; a focused-only optimization remains a performance follow-up, not an ordering requirement. Queries are coalesced while in flight; event IDs are not coalesced. Backend failures retain MRU and flag a gap/degraded state. Successful recovery repairs current state, not lost intermediate history.

Local lifetimes distinguish observed PID changes or disappearance/reappearance; destroyed IDs are tombstoned until their absence or a different PID is confirmed. A delayed destroy/focus event for an ID reused without an observed absence remains ambiguous because yabai supplies no lifetime token. PID/lifetime fields are metadata-resolution results, not proof of the identity at the original event time. Command Space-transition phases and a manual return to the original window during verification also cannot be attributed perfectly with this signal protocol; these are explicit limitations, not guaranteed detection.

After its socket is ready, YS idempotently installs five owned labels: `ys-focus-window`, `ys-focus-destroyed`, `ys-focus-front`, `ys-focus-space`, and `ys-focus-wake`. It verifies them at startup and every 30 seconds, repairing missing labels and counting detected registration gaps. Existing unrelated registrations are retained. Daily cutover removes only the identified legacy YS focus-refresh action and updates `.yabairc`; other refresh consumers remain. Keep the prior app/configuration/signal snapshot for rollback.

The shadow stage was validated with fake-backend journal/concurrency tests before live cutover, rather than shipping a separate shadow-only app version. Raw event preservation, stale snapshots, reversed delivery/current-focus repair, dialog exclusion, failure recovery, cancellation during a blocked focus call, destroyed windows, observed PID reuse, and signal repair/idempotency have compiled Swift regressions in `test_focus_tracking.py`. Native transport/parser checks and all prior regressions remain in the release suite. See SESSION_LOG.md for final build, test, installation, and live-check results.

Release verification: all 45 tests and the explicit clean signed build passed; 1.8.0 is installed and running. A coordinated live run verified real signals, frozen recent-Space traversal, immediate manual-focus cancellation/history updates, automatic expiry, repeated-ID intake, and restoration of the original macOS foreground window. Focus-event CLI acknowledgment measured median 11.66 ms; inventory CLI queries measured median 37.53 ms, both including process startup. Three inventory reconciliations occurred over 3.2 idle seconds. Recovery copies and full records are in `/private/tmp/ys-focus-install-20261006/`.

An observed source limitation: Ghostty could be the macOS foreground app with visible window 122 while yabai reported no `has-focus` window. YS records delivered focus IDs and leaves confirmed current focus unknown in that case; it does not infer a key window solely from visibility or fabricate a focus event. Automated navigation verification used other apps, with independent macOS foreground restoration. This reinforces the distinction between all delivered yabai events and all real macOS focus changes.

## Objective and limits

Track window focus changes regardless of how they occur: mouse clicks, Command-Tab, application shortcuts, YS commands, panel selection, or external window-management commands. Use that information to improve the existing window history and its derived recent-Space order.

The practical contract is to retain every valid focus event delivered to YS, subject to an explicit bounded retention policy, and reconcile the currently focused window. It is not a promise to observe every macOS transition or reconstruct exact historical order. Stock yabai signals do not provide the producer sequence needed for that promise.

First-release non-goals: rewriting/forking yabai, independent automatic tiling, changing Caps or modifier handling, adding shortcuts, changing the two-second cycling interval, or persisting history across YS restarts. Recording focus does not imply making dialogs or panels navigation targets.

## Verified pre-implementation baseline (1.7.0)

- The active yabai `window_focused` action sends only `refresh windows` to `/tmp/yabai-indicator.socket`. Its window ID is discarded. `~/.yabairc` matches that registration.
- `YabaiAppDelegate.onWindowRefresh()` requests `WindowSwitchController.observe()` and separately queries windows for the panel.
- `WindowSwitchController` serializes observation and commands, but observation queries focus when it runs, not when the original event happened. Its focus/Space verification loops can delay subsequent observations.
- `NavigationWindow.init` excludes nonstandard, hidden, and minimized windows. Raw focus tracking currently does not exist separately from eligible-window MRU.
- Verified YS cycling focus preserves frozen candidates. A different externally observed focus ends the cycle. Panel selection explicitly ends it. History is in memory and restarts from query order.

For A → B → C, both delayed refreshes can find C; knowing that two notifications occurred cannot recover B.

### Upstream evidence

The [yabai 7.1.25 signal documentation](https://github.com/asmvik/yabai/blob/v7.1.25/doc/yabai.asciidoc#signal) describes `window_focused` as a key-window change carrying `YABAI_WINDOW_ID`. In the matching [signal implementation](https://github.com/asmvik/yabai/blob/v7.1.25/src/event_signal.c), `event_signal_flush` forks signal actions without waiting for each to complete, and the focus-event payload contains the window ID rather than an event timestamp, producer sequence, or command-origin token. Therefore chronological delivery cannot be inferred from socket arrival order. These conclusions apply to the inspected version; recheck when yabai changes.

## Architecture

```text
macOS focus change
    → yabai window_focused signal, with YABAI_WINDOW_ID
    → installed YS executable: event window-focused <id>
    → existing same-user Unix socket
    → validated, promptly acknowledged ingress
    → serial focus-state queue: raw journal + operation tracking
    → reconciliation worker: yabai queries
    → eligible-window MRU and cycling state
    → existing panel/border callbacks on the main thread
```

Use the existing socket and native executable, not a Python helper or another daemon. Keep keyboard ownership unchanged. Signal receipt must not require the main run loop, a thumbnail capture, or completion of a navigation command.

### Separate three concepts

1. **Raw observations:** received event IDs, including unknown/non-navigable windows; never replace an ID with the result of a later query.
2. **Confirmed current focus:** the result of a successful live query at a known reconciliation point. It is a snapshot, not a replay of missed events.
3. **Navigation state:** eligible-window MRU, frozen cycling candidates, and the latest eligible representative of each Space. Only this state determines navigation.

Do not interpret an absent query record as proof that an event never happened. The window may already have closed or metadata may be unavailable.

## Protocol and transport

CLI and wire message:

```text
event window-focused <positive-decimal-window-id>
```

This is a three-argument native command, requiring deliberate updates to both client and server validation. It must never fall through to GUI startup. Reject zero, signs, overflow, extra fields, oversized messages, and unsupported event names. Preserve existing peer-UID checks, socket ownership validation, framing limits, and bounded I/O deadlines. The event command is internal automation, not a keyboard binding.

Registration installed by the tracking service:

```sh
yabai -m signal --add label=ys-focus-window event=window_focused action='/Applications/YabaiSpaces.app/Contents/MacOS/YabaiIndicator event window-focused "$YABAI_WINDOW_ID"'
```

Acknowledgment means the event has entered the in-memory ingress queue, not that metadata queries or history updates have completed, nor that the event is durable. If ingress is full, reject explicitly and flag a tracking gap. Do not automatically retry after an ambiguous acknowledgment timeout: the original may already be queued, and there is no producer event ID for safe deduplication.

### In-memory event record

Assign a monotonically increasing receipt sequence on the ingress queue and capture monotonic receive time. Store window ID, source (`yabai-signal`, `ys-verification`, or `reconciliation`), operation association if any, metadata-resolution status, and classification confidence. A receipt sequence is explicitly not a yabai sequence. Verification/snapshot records are not counted as additional delivered focus events.

Keep a ring of 1,024 recent records for diagnostics, plus aggregate accepted/rejected/evicted/query-failure counters. Eviction limits retention, not MRU length, and must be visible in diagnostics. Bound pending ingress separately; initially 1,024 entries, with an overflow-triggered reconciliation. Do not write titles or full focus logs to disk by default. Unknown records survive within the ring even if they never become navigation candidates.

Do not deduplicate raw events solely by window ID or a time threshold: A → B → A is meaningful. Consecutive same-ID events may be navigation no-ops but remain separate raw records.

## Ordering policy

**Selected approach:** stock-yabai, best-effort event history plus explicit live reconciliation. Do not claim exact chronological ordering.

- Serialize events in receipt order. This gives deterministic local processing, not original focus order.
- Use each event ID to record an intermediate focus even when a snapshot already shows another window.
- Batch metadata refreshes, but never coalesce away individual raw focus IDs.
- Process a completed reconciliation against a receipt watermark. If newer events arrived during its query, do not apply that result as the final state; schedule another query. Even a query with no newer arrivals is only a snapshot and can be superseded immediately afterward.
- Outside cycling, promote eligible delivered IDs in receipt order, then reconcile the live eligible focus to the front. This repairs the current-most-recent entry, not the exact relative order of intermediate windows when deliveries were reversed.
- A stale event must not move the border onto a window that is no longer focused. Border selection follows verified current cycling focus, never an unverified historical event.

For delivered B then C with snapshot C, retain B and C and finish with C most recent. For reversed C then B with snapshot C, retain both and restore C to the front; older relative ordering remains best effort. If B's notification never arrives, mark any detectable gap but do not invent B.

Adding a shell timestamp, lock file, counter in a helper, persistent relay, or YS receipt sequence does not restore producer order: those act after the asynchronous scheduling boundary. They are not selected as ordering fixes.

Exact producer order would require an upstream ordered stream/sequence or a separately evaluated direct macOS observer. Neither is part of this implementation. A direct observer would introduce another permission/lifecycle/identity problem and would itself need measured ordering guarantees.

## Navigation and cycling integration

Keep the two-second interval as a navigation policy, not a delay before recording focus. Record raw events promptly even while navigation MRU is frozen.

Move slow yabai queries and focus verification off the serial focus-state queue. Model navigation as an asynchronous operation with a local ID, expected target, phase, receipt watermarks, and bounded completion deadline. Only the state queue changes history, operation state, or cycle deadlines. The worker returns immutable results; it never waits for the state queue while that queue waits for it. Continue dispatching AppKit work to the main thread without holding state locks.

Stock yabai does not report command provenance. An event matching a pending target is only correlated with the operation, not proven to be caused by it. Never suppress every occurrence of an ID or every event within the two-second interval.

Rules:

- Verified cycling success advances the selected window and renews the deadline while retaining frozen candidates. Record its verification separately from delivered signals.
- A confirmed external change ends cycling immediately upon observation, commits the previous selected eligible window, then promotes the newly focused eligible window. Clear the border; do not wait for the two-second timer.
- A focus change to a confirmed non-eligible window, such as a dialog, ends cycling without adding that window as a candidate. Preserve the latest eligible history. Exclude YS's own panel bookkeeping; opening/dismissing the panel alone retains its existing behavior, while selecting explicitly ends cycling.
- Same confirmed focus does not end cycling. Ambiguous delayed signals remain in the journal and trigger reconciliation, rather than independently canceling a valid cycle or rewinding its selection.
- Across-Space navigation may cause an intermediate window to receive focus. Track it, but treat possible operation-associated transitions as provisional until verification. If the live focus differs from the completed operation target, end the cycle and reconcile; never assert that all intermediate events were self-generated.
- Failure, target disappearance, scope changes, explicit panel selection, and automatic expiry keep their existing cancellation semantics. A late worker completion must not revive a canceled operation or expired cycle.
- A manual change during verification must not be silently overwritten by queued follow-up focus. Recheck operation validity and live state before each new focus step. There remains a race between a check and yabai's focus call; document it rather than promise perfect attribution.

Deduplicated Space order continues to come from eligible window history, selecting the latest eligible window for each Space. Do not introduce an independent Space-MRU list. Raw dialog observations do not erase their Space's last eligible representative.

## Reconciliation and lifecycle

Use explicit focus events as the primary input. Application-front changes, window lifecycle changes, Space/display changes, Mission Control exit, and wake can request reconciliation; they are not substitute window-focus events.

Retain metadata for known windows, with PID and a local lifetime/generation. Do not prune all history on query failure. Only successful inventory refreshes or validated lifecycle changes prune unavailable navigation candidates. Window ID alone cannot establish a lifetime across destruction/reuse; ambiguous late events for a reused ID must not resurrect old metadata. Expose that limitation in diagnostics.

Proposed safety net: a one-second focused-window check on a worker, only while YS is active and the backend is healthy. Fetch full inventory only when dirty or needed. Debounce inventory work without debouncing journal receipt. This interval is independent of the two-second cycling timeout. Measure query overhead before enabling it by default; reduce unnecessary duplicate panel/history queries.

On backend failure, retain history, clear unsafe pending navigation, and report degraded tracking. Recovery takes a fresh inventory/current-focus snapshot and marks an observation gap. Do not replay guesses about focus while disconnected. App activation without a key window means no confirmed current window, not a new navigation target.

On startup, inspect registrations and install/verify only YS-owned labeled signals after the listener is ready. On reconnect, compare registrations and restore missing YS-owned labels without restarting yabai or duplicating other consumers. An unavailable listener or restarted yabai can lose events; snapshots repair current state but cannot recover intermediate history. Initial startup and YS restart still seed history from live inventory, with no persistence claim.

## Original implementation sequence

1. **Ingress and shadow journal.** Add a typed event command, client/server validation, bounded journal, diagnostics, and tests. Keep navigation behavior unchanged initially. Introduce no new dependency. Verify real ID-bearing signals in a controlled test before migrating the daily registration.
2. **State/worker separation.** Refactor `WindowSwitchController` in `Connectors/YabaiClient.swift` so blocking focus verification cannot prevent event processing. Add asynchronous operation tests and stale-completion guards before switching MRU input.
3. **History integration.** Separate raw focus from `NavigationWindow` filtering; implement receipt-order promotion, watermarked reconciliation, cycling correlation, and explicit unknown/ambiguous handling. Preserve existing Space derivation and border/thumbnail contracts.
4. **Lifecycle and health.** Add successful-inventory pruning, reconciliation triggers, bounded fallback checks, idempotent labeled registration, and visible gap diagnostics. Run shadow/live traces to assess ordering and overhead.
5. **Controlled cutover.** Back up `.yabairc` and active signal list. Replace only the identified YS legacy focus action with the labeled ID-bearing action, and update persistent setup. Preserve other refresh actions/consumers. Add ancillary labels only where needed; never broadly remove/recreate all signals. Verify no duplicate focus intake.
6. **Release validation/deployment.** Run all existing regressions plus the new suite, explicit clean signed build, verified backup/install/restart, and physical/manual checks. Increment the application minor version for the runtime release; 1.8.0 is the implementation version.

Expected code areas: `Models/PanelHotkey.swift` or a dedicated event model, `PanelCommandClient.swift`, `YabaiAppDelegate.swift` socket routing, `Connectors/YabaiClient.swift`, `WindowSwitching.swift`, and a small focus journal/service. Add focused tests alongside `test_native_commands.py` and `test_window_switching.py`. Keep `CyclingWindowBorder.swift` rendering unchanged unless integration tests establish a necessary callback adjustment.

## Validation and acceptance

### Automated tests

- Parser/client/server: valid three-field events; invalid IDs, overflow, extra arguments, framing, wrong peer, rejection, unavailable listener, acknowledgment timeout, and no GUI startup.
- Journal: A → B → C preserved even when every query shows C; A → B → A retained; nonstandard/unknown/closed windows retained as raw events; bounded ingress/retention counters.
- Ordering: reversed delivery, duplicate delivery, delayed stale events, snapshot-watermark invalidation, failed queries, recovery gaps, ID reuse, and current-focus repair. Tests must assert the documented limits rather than pretend reordered events are reconstructed exactly.
- Concurrency: event intake continues during one-second verification stages; command failures/late completions cannot revive cycles; UI/socket/state queues do not deadlock.
- Cycling: rapid repeat traversal, external focus before/during/after verification, repeated same-ID focus, intermediate cross-Space focus, panel selection, dialogs, expiry, and renewable deadlines.
- Navigation: same-Space window MRU, eligible window per application, deduplicated recent Spaces, closed-window pruning, and no independent Space history.
- UI/regressions: border remains adjacent and thins to the original deadline; no stale-event border jump; panel/border absent from thumbnails; no focus stealing or new shortcuts.

### Live verification

Use disposable windows where possible, recording intended and observed IDs. Check clicks, Command-Tab, application window switching, YS cycling/jumps, external yabai focus, and panel selection across Spaces. Restore the original focus afterward. Exercise rapid A/B/C sequences and compare journal receipt order with the known controlled sequence; report any reversal explicitly. Check dialog behavior and an application with no key window manually.

Confirm signal registration before/after YS restart, and simulate backend disconnection with a test backend rather than restarting the user's yabai unnecessarily. Measure event acknowledgment latency, query counts, queue backlog, and bounded memory during rapid switches. Physical input behavior is not established by socket acknowledgment alone.

Release gates: current focus converges after a burst; all delivered IDs are represented unless a declared bound is exceeded; manual focus updates navigation upon confirmation; cycling candidates remain frozen for verified cycling; no silent gap/overflow; no input-service changes. Exact chronological ordering of every macOS focus change is not an acceptance claim for this stock-yabai approach.

## Deployment and rollback

Follow [SAFE_DEVELOPMENT.md](SAFE_DEVELOPMENT.md): test after each edit, complete a clean build, verify the installed-app backup and matching designated requirement before stopping YS, install/verify the new bundle, restart it, and check command handling and actual focus behavior. Preserve the prior app, `.yabairc`, and active signal registrations together.

For rollback, remove only newly introduced YS-owned labels and restore the exact prior legacy actions and persistent configuration before launching the old app, which cannot accept the new event command. Avoid a blanket `.yabairc` reload if it duplicates unrelated unlabeled actions. Use verified signal snapshots to restore only affected entries. Restore the previous signed app through the same safe procedure and verify refresh/focus handling. Record any gap during rollback.

No commit or push is implied by this plan. Update this document and SESSION_LOG.md with implementation results, measured limitations, tests, deployment details, and any decisions that change the proposed contract.
