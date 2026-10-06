from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent


class CapsPrefixTests(unittest.TestCase):
    def test_selection_timeout_and_key_consumption(self):
        source = (ROOT / "YabaiIndicator/Managers/HotkeyManager.swift").read_text()
        controller = source.split("final class CapsPrefixController", 1)[1].split(
            "// MARK: - Carbon-based Hotkey", 1
        )[0]
        harness = "import AppKit\nimport Carbon\nfinal class CapsPrefixController" + controller + r'''
extension CapsPrefixController {
    func timeoutForTesting() -> TimeInterval? { timer?.fireDate.timeIntervalSinceNow }
    func armForTesting() { session.start(now: ProcessInfo.processInfo.systemUptime) }
    func eventForTesting(_ code: CGKeyCode, down: Bool, repeatKey: Bool = false) -> Bool {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down)!
        event.flags = []
        event.setIntegerValueField(.keyboardEventAutorepeat, value: repeatKey ? 1 : 0)
        return handle(type: down ? .keyDown : .keyUp, event: event) == nil
    }
}
@main struct Checks {
    static func main() {
        var session = PrefixSession()
        precondition(!session.isActive(now: 1))
        session.start(now: 1)
        precondition(PrefixSession.timeout == 2)
        precondition(session.isActive(now: 2.99))
        precondition(!session.isActive(now: 3))
        precondition(session.select("s", now: 3) == nil)
        session.start(now: 5)
        session.start(now: 6)
        precondition(session.isActive(now: 7.99))
        precondition(session.select("h", now: 7.99)?.applicationSpace == 8)
        precondition(!session.isActive(now: 7.99))
        session.start(now: 10)
        precondition(session.select("?", now: 10) == nil)
        precondition(session.isActive(now: 10))
        precondition(session.select("q", now: 10)?.application == nil)
        precondition(!session.isActive(now: 10))
        for invalid in ["jump", "jump aa", "jump A", "jump s extra", "jump \ns", "jump /", "jump .", "prefix s"] {
            precondition(JumpCommand(rawValue: invalid) == nil)
        }
        precondition(JumpCommand(rawValue: "jump 0")?.destinationSpace == 10)
        precondition(JumpCommand(rawValue: "jump -")?.destinationSpace == 11)
        precondition(JumpCommand(rawValue: "jump =")?.destinationSpace == 12)
        let names = ["a": "Word", "w": "Word", "s": "Safari", "d": "Discord", "f": "Firefox",
                     "g": "GoodNotes", "h": "Brave Browser", "j": "iTerm2", "k": "kitty", "l": "Logseq",
                     "z": "zoom.us", "x": "Excel", "c": "Brave Browser", "v": "Code", "b": "Brave Browser",
                     "n": "Signal", "m": "Messages", "r": "Friendly Streaming", "y": "Spotify", "p": "PowerPoint"]
        for (key, name) in names { precondition(JumpCommand(rawValue: "jump \(key)")?.application == name) }
        var state = WindowSwitching()
        let windows = [NavigationWindow(id: 1, pid: 10, space: 6, focused: true, application: "Brave Browser"),
                       NavigationWindow(id: 2, pid: 10, space: 7, application: "Brave Browser"),
                       NavigationWindow(id: 3, pid: 10, space: 8, application: "Brave Browser"),
                       NavigationWindow(id: 4, pid: 20, space: 9, application: "Microsoft Word"),
                       NavigationWindow(id: 5, pid: 20, space: 10, application: "Microsoft Word")]
        for (key, expected) in [("c", UInt64(1)), ("b", 2), ("h", 3), ("a", 4), ("w", 4)] {
            precondition(state.target(JumpCommand(rawValue: "jump \(key)")!, windows: windows, now: 0)?.id == expected)
        }
        let refocused = windows.map {
            NavigationWindow(id: $0.id, pid: $0.pid, space: $0.space, focused: $0.id == 5, application: $0.application)
        }
        _ = state.target(.nextRecentSpace, windows: windows, currentSpace: 6, now: 0)
        precondition(state.target(JumpCommand(rawValue: "jump w")!, windows: refocused, now: 0.1)?.id == 5)
        precondition(state.target(JumpCommand(rawValue: "jump h")!, windows: windows.filter { $0.id != 3 }, now: 1) == nil)
        precondition(state.target(JumpCommand(rawValue: "jump s")!, windows: windows, now: 1) == nil)
        var handled: [String] = []
        let prefix = CapsPrefixController { handled.append($0.key) }
        precondition(!prefix.eventForTesting(CGKeyCode(kVK_ANSI_Period), down: true))
        prefix.armForTesting()
        precondition(prefix.eventForTesting(CGKeyCode(kVK_ANSI_Period), down: true))
        precondition(prefix.eventForTesting(CGKeyCode(kVK_ANSI_Period), down: false))
        precondition(!prefix.eventForTesting(12, down: true))
        precondition(handled.isEmpty)
        precondition(!prefix.eventForTesting(12, down: true))
        prefix.armForTesting()
        precondition(prefix.eventForTesting(12, down: true))
        precondition(prefix.eventForTesting(12, down: true, repeatKey: true))
        precondition(prefix.eventForTesting(12, down: false))
        precondition(!prefix.eventForTesting(12, down: true))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        precondition(handled == ["q"])
        prefix.armForTesting()
        precondition(prefix.eventForTesting(53, down: true))
        precondition(prefix.eventForTesting(53, down: false))
        precondition(!prefix.eventForTesting(12, down: true))
        prefix.armForTesting()
        prefix.cancel()
        precondition(!prefix.eventForTesting(12, down: true))
        precondition(prefix.eventForTesting(CGKeyCode(kVK_F20), down: true))
        precondition(prefix.eventForTesting(CGKeyCode(kVK_F20), down: false))
        precondition(prefix.eventForTesting(CGKeyCode(kVK_ANSI_M), down: true))
        precondition(prefix.eventForTesting(CGKeyCode(kVK_ANSI_M), down: false))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        precondition(handled == ["q", "m"])
        precondition(!prefix.eventForTesting(CGKeyCode(kVK_ANSI_M), down: true))
        precondition(prefix.eventForTesting(CGKeyCode(kVK_F20), down: true))
        precondition(prefix.eventForTesting(CGKeyCode(kVK_F20), down: false))
        precondition((1.8...2.0).contains(prefix.timeoutForTesting()!))
        Thread.sleep(forTimeInterval: 2.1)
        precondition(!prefix.eventForTesting(CGKeyCode(kVK_ANSI_M), down: true))
        precondition(handled == ["q", "m"])
    }
}
'''
        with tempfile.TemporaryDirectory(prefix="ys-prefix-tests-", dir="/tmp") as directory:
            root = Path(directory)
            checks = root / "Checks.swift"
            checks.write_text(harness)
            binary = root / "checks"
            subprocess.run([
                "xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(root / "cache"),
                str(ROOT / "YabaiIndicator/Models/PanelHotkey.swift"),
                str(ROOT / "YabaiIndicator/WindowSwitching.swift"), str(checks), "-o", str(binary),
            ], check=True, timeout=120)
            subprocess.run([str(binary)], check=True, timeout=10)


if __name__ == "__main__":
    unittest.main()
