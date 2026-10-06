//
//  YabaiClient.swift
//  YabaiIndicator
//
//  Created by Max Zhao on 01/01/2022.
//

import SwiftUI

struct YabaiResponse {
    let error:Int
    let response:Any
}


// MARK: - Error Types

enum YabaiError: Error, LocalizedError {
    case connectionFailed(String)
    case invalidResponse(String)
    case yabaiNotRunning
    case jsonParseError(String)
    case queryFailed(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Cannot connect to Yabai: \(message)"
        case .invalidResponse(let message):
            return "Invalid response from Yabai: \(message)"
        case .yabaiNotRunning:
            return "Yabai is not running. Start Yabai to enable window management features."
        case .jsonParseError(let message):
            return "Failed to parse Yabai response: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .connectionFailed, .yabaiNotRunning:
            return "Start Yabai with: yabai --start-service"
        case .invalidResponse, .jsonParseError:
            return "Check Yabai version compatibility"
        case .queryFailed:
            return "Retry the operation or check Yabai logs"
        }
    }
}

class YabaiClient {
    static let willFocusSpace = Notification.Name("YabaiSpaces.willFocusSpace")

    func _yabaiSocketCall(_ args: [String]) -> (Int, String) {
        var cresp:UnsafeMutablePointer<CChar>? = nil
        var cargs = args.map { strdup($0) }

        // Ensure cleanup happens even if errors occur
        defer {
            for ptr in cargs { free(ptr) }
            if let resp = cresp { free(resp) }
        }

        let ret = send_message(Int32(args.count), &cargs, &cresp)

        var response = ""
        if let r = cresp {
            response = String(cString: r)
        }

        return (Int(ret), response)
    }

    @discardableResult
    func yabaiSocketCall(_ args: String...) throws -> YabaiResponse {
        let (e, m) = _yabaiSocketCall(args)
        var resp: Any = []

        // Check for connection errors
        if e != EXIT_SUCCESS {
            if m.contains("failed to connect") || m.contains("failed to open socket") {
                throw YabaiError.yabaiNotRunning
            }
            throw YabaiError.connectionFailed(m)
        }

        if m.count > 0 {
            if let data = m.data(using: .utf8) {
                do {
                    resp = try JSONSerialization.jsonObject(with: data, options: [])
                } catch {
                    NSLog("[YabaiSpaces] JSON parse error: \(error.localizedDescription)")
                    throw YabaiError.jsonParseError("JSON parsing failed: \(error.localizedDescription)")
                }
            }
        }
        let r = YabaiResponse(error: e, response: resp)
        return r
    }

    func focusSpace(index: Int) throws {
        NotificationCenter.default.post(name: Self.willFocusSpace, object: index)
        try yabaiSocketCall(
            "-m", "space", "--focus", "\(index)")
    }

    func focusWindow(id: UInt64) throws {
        try yabaiSocketCall(
            "-m", "window", "--focus", "\(id)")
    }

    func queryWindows() throws -> [Window] {
        do {
            let response = try yabaiSocketCall("-m", "query", "--windows")

            guard let r = response.response as? [[String: Any]] else {
                NSLog("[YabaiSpaces] Invalid response format - expected array of dictionaries")
                throw YabaiError.invalidResponse("Expected array of window dictionaries")
            }

            let windows = r.compactMap { (dict: [String: Any]) -> Window? in
                // Safe extraction with nil coalescing and logging
                guard let id = dict["id"] as? UInt64 else {
                    NSLog("[YabaiSpaces] Missing or invalid 'id' field in window data: \(dict)")
                    return nil
                }
                guard let pid = dict["pid"] as? UInt64 else {
                    NSLog("[YabaiSpaces] Missing or invalid 'pid' field for window id \(id)")
                    return nil
                }
                guard let app = dict["app"] as? String else {
                    NSLog("[YabaiSpaces] Missing 'app' field for window id \(id)")
                    return nil
                }
                let title = dict["title"] as? String ?? ""
                guard let frameDict = dict["frame"] as? [String: Double] else {
                    NSLog("[YabaiSpaces] Missing or invalid 'frame' for window \(app)#\(id)")
                    return nil
                }
                let x = frameDict["x"] ?? 0
                let y = frameDict["y"] ?? 0
                let w = frameDict["w"] ?? 0
                let h = frameDict["h"] ?? 0
                guard w > 0 && h > 0 else {
                    NSLog("[YabaiSpaces] Invalid frame dimensions for window \(app)#\(id): \(w)x\(h)")
                    return nil
                }
                let displayIndex = dict["display"] as? Int ?? 0
                let spaceIndex = dict["space"] as? Int ?? 0

                return Window(
                    id: id,
                    pid: pid,
                    app: app,
                    title: title,
                    frame: NSRect(x: x, y: y, width: w, height: h),
                    displayIndex: displayIndex,
                    spaceIndex: spaceIndex
                )
            }

            if windows.isEmpty && r.count > 0 {
                NSLog("[YabaiSpaces] All windows filtered out due to invalid data")
            }

            return windows
        } catch let error as YabaiError {
            throw error
        } catch {
            NSLog("[YabaiSpaces] Unexpected error in queryWindows: \(error.localizedDescription)")
            throw YabaiError.queryFailed(error.localizedDescription)
        }
    }
}

let gYabaiClient = YabaiClient()

final class WindowSwitchController {
    private let queue = DispatchQueue(label: "YabaiSpaces.window-switching")
    private let worker = DispatchQueue(label: "YabaiSpaces.navigation-worker")
    private let observationWorker = DispatchQueue(label: "YabaiSpaces.focus-query")
    private let maintenanceWorker = DispatchQueue(label: "YabaiSpaces.focus-signals")
    private var switching = WindowSwitching()
    private var journal = FocusJournal()
    private let client = YabaiClient()
    private var cycleTimer: DispatchSourceTimer?
    private var trackingTimer: DispatchSourceTimer?
    private var scheduledDeadline: TimeInterval?
    private var querying = false
    private var queryAgain = false
    private var generation: UInt64 = 0
    private var operation: UInt64?
    private var expected: UInt64?
    private var baseline: UInt64?
    private var checkingWindow = false
    private var operationWatermark: UInt64 = 0
    private var confirmedFocus: UInt64?
    private var lastSignalCheck: TimeInterval = 0
    private var tombstones = Set<UInt64>()
    private var identities: [UInt64: UInt64] = [:]
    private var lifetimes: [UInt64: UInt64] = [:]
    private var nextLifetime: UInt64 = 0
    private var revision: UInt64 = 0
    private var verifications: UInt64 = 0
    private var snapshots: UInt64 = 0
    private var signalsHealthy = false
    var onCycleChange: ((UInt64?, TimeInterval?) -> Void)?

    private struct Snapshot {
        let windows: [NavigationWindow]
        let known: Set<UInt64>
        let focused: UInt64?
        let ownFocus: Bool
        let pids: [UInt64: UInt64]
    }

    func startTracking() {
        queue.async {
            guard self.trackingTimer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: 1)
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                self.requestObservation()
                let now = ProcessInfo.processInfo.systemUptime
                if now - self.lastSignalCheck >= 30 {
                    self.lastSignalCheck = now
                    self.maintenanceWorker.async { self.ensureSignals() }
                }
            }
            self.trackingTimer = timer
            timer.resume()
        }
    }

    private func ensureSignals() {
        let executable = "/Applications/YabaiSpaces.app/Contents/MacOS/YabaiIndicator"
        let signals = [
            ("ys-focus-window", "window_focused", "\(executable) event window-focused \"$YABAI_WINDOW_ID\""),
            ("ys-focus-destroyed", "window_destroyed", "\(executable) event window-destroyed \"$YABAI_WINDOW_ID\""),
            ("ys-focus-front", "application_front_switched", "\(executable) event reconcile"),
            ("ys-focus-space", "space_changed", "\(executable) event reconcile"),
            ("ys-focus-wake", "system_woke", "\(executable) event reconcile")
        ]
        do {
            let response = try client.yabaiSocketCall("-m", "signal", "--list")
            guard let registered = response.response as? [[String: Any]] else {
                throw YabaiError.invalidResponse("Expected signal list")
            }
            let missing = signals.contains { label, event, action in
                !registered.contains { $0["label"] as? String == label && $0["event"] as? String == event && $0["action"] as? String == action }
            }
            if missing { queue.async { if self.signalsHealthy { self.journal.gap() }; self.signalsHealthy = false } }
            for (label, event, action) in signals where !registered.contains(where: {
                $0["label"] as? String == label && $0["event"] as? String == event && $0["action"] as? String == action
            }) {
                _ = try client.yabaiSocketCall("-m", "signal", "--add", "label=\(label)", "event=\(event)", "action=\(action)")
            }
            let verified = try client.yabaiSocketCall("-m", "signal", "--list").response as? [[String: Any]]
            guard signals.allSatisfy({ label, event, action in
                verified?.contains { $0["label"] as? String == label && $0["event"] as? String == event && $0["action"] as? String == action } == true
            }) else { throw YabaiError.invalidResponse("Focus signals were not registered") }
            queue.async { self.signalsHealthy = true }
        } catch {
            queue.async { self.signalsHealthy = false; self.journal.gap() }
            NSLog("[YabaiSpaces] Focus signal registration failed: \(error.localizedDescription)")
        }
    }

    func receive(_ event: FocusEventCommand) -> Bool {
        queue.sync {
            revision += 1
            if event.kind == .destroyed {
                journal.destroyed(event.windowID)
                tombstones.insert(event.windowID)
                switching.forget(event.windowID)
                synchronizeCycle()
                if expected == event.windowID { invalidateOperation() }
                requestObservation()
                return true
            }
            let accepted = journal.receive(event.windowID, now: ProcessInfo.processInfo.systemUptime, operation: operation)
            requestObservation()
            return accepted
        }
    }

    func diagnostics() -> String {
        queue.sync {
            let records: [[String: Any]] = journal.records.suffix(32).map {
                ["sequence": $0.sequence, "received": $0.received, "window": $0.windowID,
                 "operation": $0.operation.map { $0 as Any } ?? NSNull(), "resolution": $0.resolution,
                 "pid": $0.pid.map { $0 as Any } ?? NSNull(), "lifetime": $0.lifetime.map { $0 as Any } ?? NSNull(),
                 "source": "yabai-signal", "confidence": $0.operation == nil ? "unattributed" : "operation-correlated-not-proven"]
            }
            let status: [String: Any] = [
                "accepted": journal.accepted, "rejected": journal.rejected, "evicted": journal.evicted,
                "gaps": journal.gaps, "queryFailures": journal.queryFailures, "degraded": journal.degraded,
                "pending": journal.pending.count, "sequence": journal.sequence, "records": records,
                "signalsHealthy": signalsHealthy, "verifications": verifications, "snapshots": snapshots,
                "current": confirmedFocus.map { $0 as Any } ?? NSNull(), "history": Array(switching.history.prefix(64)),
                "cycling": switching.cycleDeadline != nil, "ordering": "receipt-order-with-live-reconciliation"
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: status, options: [.sortedKeys]),
                  let text = String(data: data, encoding: .utf8) else { return "error focus diagnostics unavailable" }
            return text
        }
    }

    private func invalidateOperation() {
        generation += 1
        operation = nil
        expected = nil
        checkingWindow = false
        switching.finishCycle()
        synchronizeCycle()
    }

    private func requestObservation() {
        guard !querying else { queryAgain = true; return }
        querying = true
        let watermark = journal.sequence
        let queryRevision = revision
        let queryGeneration = generation
        let operationAtStart = operation
        observationWorker.async {
            let result = Result { try self.snapshot() }
            self.queue.async {
                self.querying = false
                switch result {
                case .success(let snapshot):
                    self.journal.recovered()
                    if self.revision == queryRevision && self.generation == queryGeneration && self.operation == operationAtStart {
                        self.reconcile(snapshot, watermark: watermark)
                    } else {
                        self.queryAgain = true
                    }
                case .failure(let error):
                    let wasDegraded = self.journal.degraded
                    self.journal.failed()
                    self.invalidateOperation()
                    if !wasDegraded { NSLog("[YabaiSpaces] Focus tracking degraded: \(error.localizedDescription)") }
                }
                if self.queryAgain {
                    self.queryAgain = false
                    self.requestObservation()
                }
            }
        }
    }

    private func reconcile(_ snapshot: Snapshot, watermark: UInt64) {
        snapshots += 1
        for (identifier, pid) in snapshot.pids {
            if identities[identifier] != pid {
                if identities[identifier] != nil {
                    tombstones.remove(identifier)
                    journal.destroyed(identifier)
                    switching.forget(identifier)
                }
                nextLifetime += 1
                lifetimes[identifier] = nextLifetime
            }
        }
        identities = snapshot.pids
        lifetimes = lifetimes.filter { snapshot.known.contains($0.key) }
        confirmedFocus = snapshot.focused
        if operation != nil {
            if checkingWindow && watermark > operationWatermark && !snapshot.ownFocus &&
                snapshot.focused != expected && snapshot.focused != baseline {
                invalidateOperation()
            } else {
                return
            }
        }
        let now = ProcessInfo.processInfo.systemUptime
        let eligible = Set(snapshot.windows.map(\.id)).subtracting(tombstones)
        let metadata = Dictionary(uniqueKeysWithValues: identities.compactMap { identifier, pid in
            lifetimes[identifier].map { (identifier, (pid, $0)) }
        })
        let received = journal.resolve(eligible: eligible, known: snapshot.known, through: watermark, identities: metadata)
        let windows = snapshot.windows.filter { !tombstones.contains($0.id) }
        if snapshot.ownFocus {
            return
        }
        let cycleContinues = switching.cycleDeadline.map { $0 > now } == true &&
            switching.cycleWindowID == snapshot.focused
        if !cycleContinues { switching.finishCycle() }
        switching.observe(windows, now: now, cyclingFocus: cycleContinues)
        for identifier in received { switching.recordFocus(identifier) }
        switching.observe(windows, now: now, cyclingFocus: cycleContinues)
        tombstones.formIntersection(snapshot.known)
        synchronizeCycle()
    }

    private func snapshot() throws -> Snapshot {
        let response = try client.yabaiSocketCall("-m", "query", "--windows")
        guard let records = response.response as? [[String: Any]] else {
            throw YabaiError.invalidResponse("Expected navigation window records")
        }
        let focused = records.first { $0["has-focus"] as? Bool == true }
        let ownPID = UInt64(ProcessInfo.processInfo.processIdentifier)
        return Snapshot(windows: records.compactMap(NavigationWindow.init).filter { $0.pid != ownPID },
                        known: Set(records.compactMap { $0["id"] as? UInt64 }),
                        focused: focused?["id"] as? UInt64,
                        ownFocus: focused?["pid"] as? Int == Int(ProcessInfo.processInfo.processIdentifier),
                        pids: Dictionary(records.compactMap { record -> (UInt64, UInt64)? in
                            guard let identifier = record["id"] as? UInt64, let pid = record["pid"] as? UInt64 else { return nil }
                            return (identifier, pid)
                        }, uniquingKeysWith: { _, latest in latest }))
    }

    private func synchronizeCycle() {
        let deadline = switching.cycleDeadline
        if deadline != scheduledDeadline {
            cycleTimer?.cancel()
            cycleTimer = nil
            scheduledDeadline = deadline
            if let deadline {
                let timer = DispatchSource.makeTimerSource(queue: queue)
                timer.schedule(deadline: .now() + max(0, deadline - ProcessInfo.processInfo.systemUptime))
                timer.setEventHandler { [weak self] in
                    guard let self else { return }
                    self.cycleTimer?.cancel()
                    self.cycleTimer = nil
                    self.scheduledDeadline = nil
                    self.invalidateOperation()
                    self.requestObservation()
                }
                cycleTimer = timer
                timer.resume()
            }
        }
        let windowID = operation == nil ? switching.cycleWindowID : nil
        let handler = onCycleChange
        DispatchQueue.main.async { handler?(windowID, deadline) }
    }

    private func windows() throws -> [NavigationWindow] {
        try snapshot().windows
    }

    private func currentSpace() throws -> Int {
        let response = try client.yabaiSocketCall("-m", "query", "--spaces", "--space")
        guard let record = response.response as? [String: Any], let index = record["index"] as? Int else {
            throw YabaiError.invalidResponse("Expected current Space index")
        }
        return index
    }

    func observe(endingCycle: Bool = false) {
        queue.async {
            self.revision += 1
            if endingCycle { self.invalidateOperation() }
            self.requestObservation()
        }
    }

    func execute(_ command: SwitchCommand) {
        worker.async {
            let start = self.queue.sync { () -> (UInt64, UInt64) in
                self.generation += 1
                self.operation = self.generation
                self.checkingWindow = false
                return (self.generation, self.journal.sequence)
            }
            do {
                let snapshot = try self.snapshot()
                let space = try self.currentSpace()
                let selection: NavigationWindow? = try self.queue.sync {
                    guard self.operation == start.0 else { throw YabaiError.queryFailed("Navigation canceled during query") }
                    self.operation = nil
                    if self.journal.sequence == start.1 { self.reconcile(snapshot, watermark: start.1) }
                    let target = self.switching.target(command, windows: snapshot.windows, currentSpace: space,
                                                       now: ProcessInfo.processInfo.systemUptime)
                    self.operation = target == nil ? nil : start.0
                    self.expected = target?.id
                    self.baseline = snapshot.focused
                    self.operationWatermark = self.journal.sequence
                    self.synchronizeCycle()
                    return target
                }
                guard let target = selection else { return }
                try self.focus(target, cycling: true, token: start.0)
                NSLog("[YabaiSpaces] \(command.rawValue): focused window \(target.id) in Space \(target.space)")
            } catch {
                self.queue.sync { self.invalidateOperation(); self.requestObservation() }
                NSLog("[YabaiSpaces] \(command.rawValue) failed: \(error.localizedDescription)")
            }
        }
    }

    func execute(_ command: JumpCommand) {
        worker.async {
            let token = self.queue.sync { () -> UInt64 in
                self.invalidateOperation()
                self.operation = self.generation
                return self.generation
            }
            do {
                if let destination = command.destinationSpace {
                    try self.focusSpace(destination, token: token)
                    self.queue.sync { self.operation = nil; self.requestObservation() }
                } else if command.application != nil {
                    let snapshot = try self.snapshot()
                    let target = try self.queue.sync { () -> NavigationWindow? in
                        guard self.operation == token else { throw YabaiError.queryFailed("Jump canceled during query") }
                        let target = self.switching.target(command, windows: snapshot.windows,
                                                           now: ProcessInfo.processInfo.systemUptime)
                        self.expected = target?.id
                        self.baseline = snapshot.focused
                        self.operationWatermark = self.journal.sequence
                        return target
                    }
                    guard let target else {
                        self.queue.sync { self.operation = nil; self.requestObservation() }
                        NSLog("[YabaiSpaces] \(command.rawValue): no matching eligible window")
                        return
                    }
                    try self.focus(target, token: token)
                    NSLog("[YabaiSpaces] \(command.rawValue): focused window \(target.id) in Space \(target.space)")
                } else { self.queue.sync { self.operation = nil; self.requestObservation() } }
            } catch {
                self.queue.sync { self.invalidateOperation(); self.requestObservation() }
                NSLog("[YabaiSpaces] \(command.rawValue) failed: \(error.localizedDescription)")
            }
        }
    }

    private func checkOperation(_ token: UInt64) throws {
        guard queue.sync(execute: { operation == token }) else {
            throw YabaiError.queryFailed("Navigation superseded by focus change or cancellation")
        }
    }

    private func focusSpace(_ space: Int, token: UInt64) throws {
        try checkOperation(token)
        guard try currentSpace() != space else { return }
        try client.focusSpace(index: space)
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        while try currentSpace() != space {
            try checkOperation(token)
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                throw YabaiError.queryFailed("Space transition did not complete")
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
    }

    private func focus(_ target: NavigationWindow, cycling: Bool = false, token: UInt64) throws {
        try focusSpace(target.space, token: token)
        guard try windows().contains(where: { $0.id == target.id && $0.space == target.space }) else {
            throw YabaiError.queryFailed("Target window closed or moved during switching")
        }
        try checkOperation(token)
        queue.sync { checkingWindow = true }
        try client.focusWindow(id: target.id)
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        var observed = try windows()
        while !observed.contains(where: { $0.id == target.id && $0.focused }) {
            try checkOperation(token)
            guard ProcessInfo.processInfo.systemUptime < deadline else {
                throw YabaiError.queryFailed("Window focus did not complete")
            }
            Thread.sleep(forTimeInterval: 0.02)
            observed = try windows()
        }
        try checkOperation(token)
        try queue.sync {
            guard operation == token else { throw YabaiError.queryFailed("Focus completion superseded") }
            operation = nil
            expected = nil
            checkingWindow = false
            confirmedFocus = target.id
            verifications += 1
            switching.observe(observed, now: ProcessInfo.processInfo.systemUptime, cyclingFocus: cycling)
            synchronizeCycle()
            requestObservation()
        }
    }

    deinit { cycleTimer?.cancel(); trackingTimer?.cancel() }
}
