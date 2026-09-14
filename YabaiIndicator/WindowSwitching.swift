import Foundation

struct NavigationWindow: Equatable {
    let id: UInt64
    let pid: UInt64
    let space: Int
    let focused: Bool

    init(id: UInt64, pid: UInt64, space: Int, focused: Bool = false) {
        self.id = id
        self.pid = pid
        self.space = space
        self.focused = focused
    }

    init?(_ data: [String: Any]) {
        guard let id = data["id"] as? UInt64, id > 0,
              let pid = data["pid"] as? UInt64, pid > 0,
              let space = data["space"] as? Int, space > 0,
              data["subrole"] as? String == "AXStandardWindow",
              data["is-minimized"] as? Bool == false,
              data["is-hidden"] as? Bool == false else { return nil }
        self.init(id: id, pid: pid, space: space, focused: data["has-focus"] as? Bool == true)
    }
}

struct WindowSwitching {
    private(set) var history: [UInt64] = []
    private var cycle: [UInt64] = []
    private var deadline: TimeInterval = 0
    private var scope: String?
    private var lastFocused: UInt64?

    private mutating func promote(_ id: UInt64?) {
        guard let id = id, history.contains(id) else { return }
        history.removeAll { $0 == id }
        history.insert(id, at: 0)
    }

    mutating func observe(_ windows: [NavigationWindow], now: TimeInterval) {
        let available = Set(windows.map(\.id))
        history.removeAll { !available.contains($0) }
        cycle.removeAll { !available.contains($0) }
        for window in windows where !history.contains(window.id) { history.append(window.id) }
        if now >= deadline {
            promote(lastFocused)
            cycle = []
            scope = nil
        }
        lastFocused = windows.first(where: \.focused)?.id
        if scope == nil { promote(lastFocused) }
    }

    mutating func target(_ command: SwitchCommand, windows: [NavigationWindow], currentSpace: Int,
                         now: TimeInterval) -> NavigationWindow? {
        observe(windows, now: now)
        let requestedScope = "\(command.applications)-\(command.acrossSpaces ? 0 : currentSpace)"
        if scope != requestedScope {
            promote(lastFocused)
            cycle = history
            scope = requestedScope
        }
        deadline = now + 2
        let byID = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        var candidates = cycle.compactMap { byID[$0] }.filter { command.acrossSpaces || $0.space == currentSpace }
        let focused = windows.first(where: \.focused)
        if command.applications {
            var seen = Set<UInt64>()
            candidates = candidates.filter { seen.insert($0.pid).inserted }
        }
        guard !candidates.isEmpty else { return nil }
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
        if command.applications && target.pid == focused?.pid { return nil }
        return target.id == focused?.id ? nil : target
    }

    mutating func cancel() {
        scope = nil
        cycle = []
        deadline = 0
    }
}
