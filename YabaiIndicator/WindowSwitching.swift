import Foundation

struct NavigationWindow: Equatable {
    let id: UInt64
    let pid: UInt64
    let space: Int
    let focused: Bool
    let application: String

    init(id: UInt64, pid: UInt64, space: Int, focused: Bool = false, application: String = "") {
        self.id = id
        self.pid = pid
        self.space = space
        self.focused = focused
        self.application = application
    }

    init?(_ data: [String: Any]) {
        guard let id = data["id"] as? UInt64, id > 0,
              let pid = data["pid"] as? UInt64, pid > 0,
              let space = data["space"] as? Int, space > 0,
              data["subrole"] as? String == "AXStandardWindow",
              data["is-minimized"] as? Bool == false,
              data["is-hidden"] as? Bool == false else { return nil }
        self.init(id: id, pid: pid, space: space, focused: data["has-focus"] as? Bool == true,
                  application: data["app"] as? String ?? "")
    }
}

struct WindowSwitching {
    static let timeout: TimeInterval = 2
    private(set) var history: [UInt64] = []
    private var cycle: [UInt64] = []
    private var deadline: TimeInterval = 0
    private var scope: String?
    private var lastFocused: UInt64?

    var cycleDeadline: TimeInterval? { scope == nil ? nil : deadline }
    var cycleWindowID: UInt64? { scope == nil ? nil : lastFocused }

    mutating func recordFocus(_ identifier: UInt64) {
        if scope == nil { promote(identifier) }
    }

    mutating func forget(_ identifier: UInt64) {
        if lastFocused == identifier { finishCycle(); lastFocused = nil }
        history.removeAll { $0 == identifier }
        cycle.removeAll { $0 == identifier }
    }

    private mutating func promote(_ id: UInt64?) {
        guard let id = id, history.contains(id) else { return }
        history.removeAll { $0 == id }
        history.insert(id, at: 0)
    }

    mutating func finishCycle() {
        promote(lastFocused)
        cancel()
    }

    mutating func observe(_ windows: [NavigationWindow], now: TimeInterval, cyclingFocus: Bool = false) {
        let available = Set(windows.map(\.id))
        history.removeAll { !available.contains($0) }
        cycle.removeAll { !available.contains($0) }
        for window in windows where !history.contains(window.id) { history.append(window.id) }
        let focused = windows.first(where: \.focused)?.id
        if scope != nil && (now >= deadline || (!cyclingFocus && focused != lastFocused)) {
            finishCycle()
        }
        lastFocused = focused
        if scope == nil { promote(lastFocused) }
    }

    mutating func target(_ command: SwitchCommand, windows: [NavigationWindow], currentSpace: Int,
                         now: TimeInterval) -> NavigationWindow? {
        observe(windows, now: now)
        let requestedScope = command == .nextRecentSpace ? "recent-spaces" : "\(command.applications)-\(command.acrossSpaces ? 0 : currentSpace)"
        if scope != requestedScope {
            finishCycle()
            cycle = history
            scope = requestedScope
        }
        let byID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        if command == .nextRecentSpace {
            var seenSpaces = Set<Int>()
            let ordered = cycle.compactMap { byID[$0] }.filter { seenSpaces.insert($0.space).inserted }
            if let current = ordered.firstIndex(where: { $0.space == currentSpace }),
               let target = ordered.dropFirst(current + 1).first(where: { $0.space != currentSpace }) {
                deadline = now + Self.timeout
                return target
            }
            if let target = ordered.first(where: { $0.space != currentSpace }) {
                deadline = now + Self.timeout
                return target
            }
            finishCycle()
            return nil
        }
        var candidates = cycle.compactMap { byID[$0] }.filter { command.acrossSpaces || $0.space == currentSpace }
        let focused = windows.first(where: \.focused)
        if command.applications {
            var seen = Set<UInt64>()
            candidates = candidates.filter { seen.insert($0.pid).inserted }
        }
        guard !candidates.isEmpty else { finishCycle(); return nil }
        let position = candidates.firstIndex {
            command.applications ? $0.pid == focused?.pid : $0.id == focused?.id
        }
        let nextIndex: Int
        if let position = position {
            nextIndex = (position + (command.backwards ? candidates.count - 1 : 1)) % candidates.count
        } else {
            nextIndex = command.backwards ? candidates.count - 1 : 0
        }
        let target = candidates[nextIndex]
        guard target.id != focused?.id, !command.applications || target.pid != focused?.pid else {
            finishCycle()
            return nil
        }
        deadline = now + Self.timeout
        return target
    }

    mutating func cancel() {
        scope = nil
        cycle = []
        deadline = 0
    }

    mutating func target(_ command: JumpCommand, windows: [NavigationWindow], now: TimeInterval) -> NavigationWindow? {
        finishCycle()
        observe(windows, now: now)
        let byID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        return history.compactMap { byID[$0] }.first {
            command.matches(application: $0.application, space: $0.space)
        }
    }
}

struct FocusJournal {
    static let capacity = 1024
    struct Record {
        let sequence: UInt64
        let received: TimeInterval
        let windowID: UInt64
        let operation: UInt64?
        var resolution: String
        var pid: UInt64?
        var lifetime: UInt64?
    }
    private(set) var sequence: UInt64 = 0
    private(set) var records: [Record] = []
    private(set) var pending: [Record] = []
    private(set) var accepted: UInt64 = 0
    private(set) var rejected: UInt64 = 0
    private(set) var evicted: UInt64 = 0
    private(set) var gaps: UInt64 = 0
    private(set) var queryFailures: UInt64 = 0
    private(set) var degraded = false

    mutating func gap() { gaps += 1 }

    mutating func receive(_ identifier: UInt64, now: TimeInterval, operation: UInt64?) -> Bool {
        guard pending.count < Self.capacity else {
            rejected += 1
            gaps += 1
            return false
        }
        sequence += 1
        accepted += 1
        let record = Record(sequence: sequence, received: now, windowID: identifier,
                            operation: operation, resolution: "unresolved")
        pending.append(record)
        records.append(record)
        if records.count > Self.capacity {
            records.removeFirst()
            evicted += 1
        }
        return true
    }

    mutating func resolve(eligible: Set<UInt64>, known: Set<UInt64>, through watermark: UInt64,
                          identities: [UInt64: (UInt64, UInt64)] = [:]) -> [UInt64] {
        let ready = pending.filter { $0.sequence <= watermark }
        pending.removeAll { $0.sequence <= watermark }
        for index in records.indices where records[index].sequence <= watermark && records[index].resolution == "unresolved" {
            let identifier = records[index].windowID
            records[index].resolution = eligible.contains(identifier) ? "eligible" : (known.contains(identifier) ? "ineligible" : "unavailable")
            records[index].pid = identities[identifier]?.0
            records[index].lifetime = identities[identifier]?.1
        }
        return ready.filter { eligible.contains($0.windowID) }.map(\.windowID)
    }

    mutating func destroyed(_ identifier: UInt64) {
        pending.removeAll { $0.windowID == identifier }
        for index in records.indices where records[index].windowID == identifier {
            records[index].resolution = "destroyed"
        }
    }

    mutating func failed() {
        queryFailures += 1
        if !degraded { gaps += 1 }
        degraded = true
    }

    mutating func recovered() { degraded = false }
}
