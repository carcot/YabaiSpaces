from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent


class WindowSwitchingTests(unittest.TestCase):
    def test_serialized_execution_and_failures(self):
        source = (ROOT / "YabaiIndicator/Connectors/YabaiClient.swift").read_text()
        controller = source[source.index("final class WindowSwitchController") :]
        with tempfile.TemporaryDirectory(prefix="ys-switch-controller-", dir="/tmp") as directory:
            root = Path(directory)
            harness = root / "ControllerChecks.swift"
            harness.write_text('''import Foundation
struct YabaiResponse { let response: Any }
enum YabaiError: Error { case invalidResponse(String), queryFailed(String) }
class YabaiClient {
    static var space = 1
    static var focused: UInt64 = 1
    static var failSpace = false
    static var failFocus = false
    static var missingTarget = false
    static var calls: [String] = []
    func yabaiSocketCall(_ args: String...) throws -> YabaiResponse {
        if args.contains("--windows") {
            return YabaiResponse(response: [(UInt64(1), 1), (UInt64(2), 1), (UInt64(3), 2)].filter {
                !(Self.missingTarget && Self.space == 2 && $0.0 == 3)
            }.map { window -> [String: Any] in
                ["id": window.0, "pid": window.0, "space": window.1, "subrole": "AXStandardWindow",
                 "app": window.0 == 3 ? "Safari" : "Microsoft Word",
                 "is-minimized": false, "is-hidden": false, "has-focus": Self.focused == window.0]
            })
        }
        return YabaiResponse(response: ["index": Self.space])
    }
    func focusSpace(index: Int) throws {
        Self.calls.append("space")
        if Self.failSpace { throw YabaiError.queryFailed("test failure") }
        Self.space = index
    }
    func focusWindow(id: UInt64) throws {
        Self.calls.append("window")
        if !Self.failFocus { Self.focused = id }
    }
}
''' + controller + '''
extension WindowSwitchController {
    func waitForTesting() {
        worker.sync {}
        for _ in 0..<4 { queue.sync {}; observationWorker.sync {}; queue.sync {} }
    }
    func historyForTesting() -> [UInt64] { queue.sync { switching.history } }
    func deadlineForTesting() -> TimeInterval? { queue.sync { switching.cycleDeadline } }
}
@main struct Checks {
    static func main() {
        let controller = WindowSwitchController()
        controller.execute(.nextAppInSpace)
        controller.waitForTesting()
        precondition(YabaiClient.focused == 2 && YabaiClient.calls == ["window"])
        precondition(controller.historyForTesting().first == 1)
        YabaiClient.focused = 3
        YabaiClient.space = 2
        controller.observe(endingCycle: true)
        controller.waitForTesting()
        precondition(controller.historyForTesting().first == 3)
        controller.execute(.nextRecentSpace)
        controller.waitForTesting()
        precondition(YabaiClient.focused == 2)
        YabaiClient.space = 1
        YabaiClient.focused = 1
        YabaiClient.calls = []
        let across = WindowSwitchController()
        across.execute(.previousAppAcrossSpaces)
        across.waitForTesting()
        precondition(YabaiClient.focused == 3 && YabaiClient.calls == ["space", "window"])
        YabaiClient.space = 1
        YabaiClient.focused = 1
        YabaiClient.calls = []
        YabaiClient.failSpace = true
        let failing = WindowSwitchController()
        failing.execute(.previousAppAcrossSpaces)
        failing.waitForTesting()
        precondition(YabaiClient.focused == 1 && YabaiClient.calls == ["space"])
        YabaiClient.failSpace = false
        YabaiClient.missingTarget = true
        YabaiClient.calls = []
        failing.execute(.previousAppAcrossSpaces)
        failing.waitForTesting()
        precondition(YabaiClient.focused == 1 && YabaiClient.calls == ["space"])
        YabaiClient.missingTarget = false
        YabaiClient.space = 1
        YabaiClient.failFocus = true
        failing.execute(.nextAppInSpace)
        failing.waitForTesting()
        precondition(YabaiClient.focused == 1)
        YabaiClient.failFocus = false
        failing.execute(.nextAppInSpace)
        failing.waitForTesting()
        precondition(YabaiClient.focused == 2)
        let jumping = WindowSwitchController()
        YabaiClient.calls = []
        jumping.execute(JumpCommand(rawValue: "jump s")!)
        jumping.waitForTesting()
        precondition(YabaiClient.focused == 3 && YabaiClient.calls == ["space", "window"])
        YabaiClient.calls = []
        jumping.execute(JumpCommand(rawValue: "jump h")!)
        jumping.waitForTesting()
        precondition(YabaiClient.calls.isEmpty && YabaiClient.focused == 3)
        jumping.execute(JumpCommand(rawValue: "jump q")!)
        jumping.waitForTesting()
        precondition(YabaiClient.calls.isEmpty)
        jumping.execute(JumpCommand(rawValue: "jump 1")!)
        jumping.waitForTesting()
        precondition(YabaiClient.space == 1 && YabaiClient.calls == ["space"])
        YabaiClient.focused = 1
        let timed = WindowSwitchController()
        var highlighted: UInt64?
        var borderDeadline: TimeInterval?
        timed.onCycleChange = { highlighted = $0; borderDeadline = $1 }
        timed.execute(.nextWindowInSpace)
        timed.waitForTesting()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        precondition(highlighted == 2 && borderDeadline == timed.deadlineForTesting())
        Thread.sleep(forTimeInterval: 1)
        timed.execute(.nextWindowInSpace)
        timed.waitForTesting()
        precondition(YabaiClient.focused == 1)
        Thread.sleep(forTimeInterval: 1.1)
        precondition(timed.deadlineForTesting() != nil)
        Thread.sleep(forTimeInterval: 1.1)
        timed.waitForTesting()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        precondition(timed.deadlineForTesting() == nil && highlighted == nil && borderDeadline == nil)
        precondition(timed.historyForTesting().first == 1)
        timed.execute(.nextWindowInSpace)
        timed.waitForTesting()
        YabaiClient.focused = 3
        YabaiClient.space = 2
        timed.observe()
        timed.waitForTesting()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        precondition(timed.historyForTesting().prefix(2) == [3, 2])
        precondition(timed.deadlineForTesting() == nil && highlighted == nil)
    }
}
''')
            binary = root / "checks"
            subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(root / "cache"),
                            str(ROOT / "YabaiIndicator/Models/PanelHotkey.swift"),
                            str(ROOT / "YabaiIndicator/WindowSwitching.swift"), str(harness),
                            "-o", str(binary)], check=True, timeout=120)
            subprocess.run([str(binary)], check=True, timeout=10)

    def test_selection_and_history(self):
        with tempfile.TemporaryDirectory(prefix="ys-switch-tests-", dir="/tmp") as directory:
            root = Path(directory)
            harness = root / "Checks.swift"
            harness.write_text('''import Foundation
@main struct Checks {
    static func main() {
        func windows(_ focused: UInt64 = 1) -> [NavigationWindow] {
            [(UInt64(1), UInt64(10), 1), (2, 10, 1), (3, 20, 1), (4, 30, 2)].map {
                NavigationWindow(id: $0.0, pid: $0.1, space: $0.2, focused: $0.0 == focused)
            }
        }
        var state = WindowSwitching()
        func refocused(_ windows: [NavigationWindow], _ identifier: UInt64) -> [NavigationWindow] {
            windows.map { NavigationWindow(id: $0.id, pid: $0.pid, space: $0.space, focused: $0.id == identifier) }
        }
        let interleaved = [NavigationWindow(id: 1, pid: 1, space: 1, focused: true),
                           NavigationWindow(id: 2, pid: 2, space: 2),
                           NavigationWindow(id: 3, pid: 3, space: 1),
                           NavigationWindow(id: 4, pid: 4, space: 3)]
        precondition(state.target(.nextRecentSpace, windows: interleaved, currentSpace: 1, now: 0)?.id == 2)
        state.observe(refocused(interleaved, 2), now: 0.1, cyclingFocus: true)
        precondition(state.target(.nextRecentSpace, windows: refocused(interleaved, 2), currentSpace: 2, now: 0.2)?.id == 4)
        state.observe(refocused(interleaved, 4), now: 0.3, cyclingFocus: true)
        precondition(state.target(.nextRecentSpace, windows: refocused(interleaved, 4), currentSpace: 3, now: 0.4)?.id == 1)
        state.cancel()
        let panelFocused = interleaved.map {
            NavigationWindow(id: $0.id, pid: $0.pid, space: $0.space, focused: $0.id == 3)
        }
        state.observe(panelFocused, now: 0.5)
        precondition(state.history.first == 3)
        precondition(state.target(.nextRecentSpace, windows: panelFocused, currentSpace: 1, now: 0.6)?.id == 2)
        state.observe(refocused(interleaved, 2), now: 0.7, cyclingFocus: true)
        precondition(state.target(.nextRecentSpace, windows: refocused(interleaved, 2), currentSpace: 2, now: 0.8)?.id == 4)
        state.observe(refocused(interleaved, 4), now: 0.9, cyclingFocus: true)
        precondition(state.target(.nextRecentSpace, windows: refocused(interleaved, 4), currentSpace: 3, now: 1)?.id == 3)
        state = WindowSwitching()
        precondition(state.target(.nextRecentSpace, windows: windows(), currentSpace: 1, now: 0)?.id == 4)
        state.observe(windows(4), now: 0.1, cyclingFocus: true)
        precondition(state.target(.nextRecentSpace, windows: windows(4), currentSpace: 2, now: 1)?.id == 1)
        precondition(state.target(.nextRecentSpace, windows: windows().filter { $0.space == 1 }, currentSpace: 1, now: 1.5) == nil)
        state = WindowSwitching()
        precondition(state.target(.nextWindowInSpace, windows: windows(), currentSpace: 1, now: 0)?.id == 2)
        state.observe(windows(2), now: 0.1, cyclingFocus: true)
        precondition(state.target(.nextWindowInSpace, windows: windows(2), currentSpace: 1, now: 1)?.id == 3)
        state.observe(windows(3), now: 1.1, cyclingFocus: true)
        precondition(state.target(.nextWindowInSpace, windows: windows(3), currentSpace: 1, now: 3)?.id == 1)
        precondition(state.history == [3, 1, 2, 4])
        state = WindowSwitching()
        precondition(state.target(.nextAppInSpace, windows: windows(), currentSpace: 1, now: 0)?.id == 3)
        state.observe(windows(3), now: 0.1, cyclingFocus: true)
        precondition(state.target(.nextAppInSpace, windows: windows(3), currentSpace: 1, now: 1)?.id == 1)
        state = WindowSwitching()
        precondition(state.target(.previousAppAcrossSpaces, windows: windows(), currentSpace: 1, now: 0)?.id == 4)
        state = WindowSwitching()
        precondition(state.target(.previousWindowInSpace, windows: windows(), currentSpace: 1, now: 0)?.id == 3)
        state.observe(windows(3), now: 0.1, cyclingFocus: true)
        precondition(state.target(.nextWindowInSpace, windows: windows(3), currentSpace: 1, now: 1)?.id == 1)
        state = WindowSwitching()
        _ = state.target(.nextWindowInSpace, windows: windows(), currentSpace: 1, now: 0)
        precondition(state.target(.nextWindowInSpace, windows: windows().filter { $0.id != 2 }, currentSpace: 1, now: 1)?.id == 3)
        precondition(!state.history.contains(2))
        precondition(state.target(.nextAppInSpace, windows: [], currentSpace: 1, now: 2) == nil)
        precondition(state.target(.nextAppInSpace, windows: windows().filter { $0.pid == 10 }, currentSpace: 1, now: 3) == nil)
        precondition(state.target(.nextWindowInSpace, windows: [windows()[0]], currentSpace: 1, now: 4) == nil)
        state = WindowSwitching()
        state.observe(windows(3), now: 0)
        state.observe(windows(2), now: 1)
        precondition(state.history.prefix(2) == [2, 3])
        state.cancel()
        state.observe(windows(4), now: 1.1)
        precondition(state.history.first == 4)
        precondition(state.target(.nextAppInSpace, windows: windows(4), currentSpace: 2, now: 2) == nil)
        state = WindowSwitching()
        _ = state.target(.nextWindowInSpace, windows: windows(), currentSpace: 1, now: 0)
        state.observe(windows(2), now: 0.1, cyclingFocus: true)
        precondition(state.history.first == 1 && state.cycleDeadline == 2)
        state.observe(windows(2), now: 0.2)
        precondition(state.cycleDeadline == 2)
        precondition(state.target(.nextWindowInSpace, windows: windows(2), currentSpace: 1, now: 0.3)?.id == 3)
        state.observe(windows(3), now: 0.4, cyclingFocus: true)
        precondition(state.history.first == 1 && state.cycleWindowID == 3)
        precondition(state.target(.nextWindowInSpace, windows: windows(3), currentSpace: 1, now: 0.5)?.id == 1)
        state.observe(windows(1), now: 0.6, cyclingFocus: true)
        state.observe(windows(4), now: 0.7)
        precondition(state.history.prefix(2) == [4, 1] && state.cycleDeadline == nil)
        precondition(state.target(.nextRecentSpace, windows: windows(4), currentSpace: 2, now: 0.8)?.id == 1)
        state.observe(windows(1), now: 0.9, cyclingFocus: true)
        state.observe(windows(3), now: 1)
        precondition(state.history.prefix(2) == [3, 1] && state.cycleDeadline == nil)
        precondition(state.target(.nextRecentSpace, windows: windows(3), currentSpace: 1, now: 1.1)?.id == 4)
        state.observe(windows(4), now: 1.2, cyclingFocus: true)
        state.observe(windows(4), now: 3.1)
        precondition(state.history.first == 4 && state.cycleWindowID == nil)
        state = WindowSwitching()
        _ = state.target(.nextWindowInSpace, windows: windows(), currentSpace: 1, now: 0)
        state.observe(windows(2), now: 0.1, cyclingFocus: true)
        state.observe(windows().filter { $0.id != 2 }.map {
            NavigationWindow(id: $0.id, pid: $0.pid, space: $0.space)
        }, now: 0.2)
        precondition(!state.history.contains(2) && state.cycleDeadline == nil)
        var record: [String: Any] = ["id": UInt64(1), "pid": UInt64(2), "space": 1,
            "subrole": "AXStandardWindow", "is-minimized": false, "is-hidden": false, "has-focus": true]
        precondition(NavigationWindow(record)?.focused == true)
        record["is-minimized"] = true
        precondition(NavigationWindow(record) == nil)
        record["is-minimized"] = false
        record["is-hidden"] = true
        precondition(NavigationWindow(record) == nil)
        record["is-hidden"] = false
        record["subrole"] = "AXDialog"
        precondition(NavigationWindow(record) == nil)
        precondition(NavigationWindow([:]) == nil)
    }
}
''')
            binary = root / "checks"
            subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(root / "cache"),
                            str(ROOT / "YabaiIndicator/Models/PanelHotkey.swift"),
                            str(ROOT / "YabaiIndicator/WindowSwitching.swift"), str(harness),
                            "-o", str(binary)], check=True, timeout=120)
            subprocess.run([str(binary)], check=True, timeout=5)


if __name__ == "__main__":
    unittest.main()
