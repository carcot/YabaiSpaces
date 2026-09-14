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
    func waitForTesting() { queue.sync {} }
}
@main struct Checks {
    static func main() {
        let controller = WindowSwitchController()
        controller.execute(.nextAppInSpace)
        controller.waitForTesting()
        precondition(YabaiClient.focused == 2 && YabaiClient.calls == ["window"])
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
        precondition(state.target(.nextWindowInSpace, windows: windows(), currentSpace: 1, now: 0)?.id == 2)
        state.observe(windows(2), now: 0.1)
        precondition(state.target(.nextWindowInSpace, windows: windows(2), currentSpace: 1, now: 1)?.id == 3)
        state.observe(windows(3), now: 1.1)
        precondition(state.target(.nextWindowInSpace, windows: windows(3), currentSpace: 1, now: 3)?.id == 1)
        precondition(state.history == [3, 1, 2, 4])
        state = WindowSwitching()
        precondition(state.target(.nextAppInSpace, windows: windows(), currentSpace: 1, now: 0)?.id == 3)
        precondition(state.target(.nextAppInSpace, windows: windows(3), currentSpace: 1, now: 1)?.id == 1)
        state = WindowSwitching()
        precondition(state.target(.previousAppAcrossSpaces, windows: windows(), currentSpace: 1, now: 0)?.id == 4)
        state = WindowSwitching()
        precondition(state.target(.previousWindowInSpace, windows: windows(), currentSpace: 1, now: 0)?.id == 3)
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
