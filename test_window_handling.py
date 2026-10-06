from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent


class WindowHandlingTests(unittest.TestCase):
    def test_geometry_backend_and_input_lifecycle(self):
        harness = r'''
import AppKit
enum YabaiError: Error {
    case queryFailed(String), invalidResponse(String)
}
class YabaiClient {
    func _yabaiSocketCall(_ arguments: [String]) -> (Int, String) { fatalError("Live IPC prohibited") }
}
let gYabaiClient = YabaiClient()
extension WindowHandlingController {
    func armForTesting(_ value: WindowDrag) {
        drag = value
        cancelled = false
        consumedButton = value.resizing ? .rightMouseDown : .leftMouseDown
    }
    func cancelForTesting() -> Bool {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: true)!
        _ = handle(type: .keyDown, event: event)
        return cancelled && drag == nil
    }
    func releaseForTesting() -> Bool {
        let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                            mouseCursorPosition: .zero, mouseButton: .left)!
        return handle(type: .leftMouseUp, event: event) == nil && consumedButton == nil
    }
}
func record(_ identifier: UInt64, originX: Double = 0, floating: Bool = false) -> [String: Any] {
    ["id": identifier, "pid": 123, "space": 1, "subrole": "AXStandardWindow",
     "is-visible": true, "is-hidden": false, "is-minimized": false,
     "is-native-fullscreen": false, "has-fullscreen-zoom": false, "has-parent-zoom": false,
     "is-sticky": false, "can-move": true, "can-resize": true, "has-ax-reference": true,
     "is-floating": floating, "has-focus": identifier == 1,
     "frame": ["x": originX, "y": 30.0, "w": 400.0, "h": 300.0]]
}
@main struct Checks {
    static func main() throws {
        let frame = CGRect(x: -400, y: -300, width: 400, height: 300)
        for (point, edge) in [(CGPoint(x: -399, y: -150), PlacementEdge.left),
                              (CGPoint(x: -1, y: -150), .right),
                              (CGPoint(x: -200, y: -299), .top),
                              (CGPoint(x: -200, y: -1), .bottom)] {
            precondition(PlacementTarget.resolve(pointer: point, draggedID: 1,
                         intendedSlots: [2: frame])?.edge == edge)
        }
        precondition(PlacementTarget.resolve(pointer: frame.origin, draggedID: 1,
                     intendedSlots: [1: frame]) == nil)
        precondition(PlacementTarget.resolve(pointer: frame.origin, draggedID: 1,
                     intendedSlots: [2: frame, 3: frame]) == nil)
        precondition(PlacementTarget.resolve(pointer: CGPoint(x: CGFloat.nan, y: 0), draggedID: 1,
                     intendedSlots: [2: frame]) == nil)
        precondition(PlacementTarget.resolve(pointer: .zero, draggedID: 1,
                     intendedSlots: [2: .zero]) == nil)
        precondition(PlacementEdge.right.preview(in: frame) == CGRect(x: -200, y: -300, width: 200, height: 300))
        for flag in ["is-minimized", "is-hidden", "is-native-fullscreen", "is-sticky",
                     "has-fullscreen-zoom", "has-parent-zoom"] {
            var data = record(1)
            data[flag] = true
            precondition(HandledWindow(data) == nil)
        }
        for flag in ["is-visible", "has-ax-reference", "can-move"] {
            var data = record(1)
            data[flag] = false
            precondition(HandledWindow(data) == nil)
        }
        var records = [record(1), record(2, originX: 400)]
        var layout = "float"
        var calls: [[String]] = []
        var failWarp = false
        let backend = WindowHandlingBackend { arguments in
            if arguments == ["query", "--windows"] { return records }
            if arguments == ["query", "--spaces"] {
                return [["index": 1, "type": layout, "is-visible": true]]
            }
            calls.append(arguments)
            if failWarp && arguments.contains("--warp") { throw YabaiError.queryFailed("injected") }
            return []
        }
        let floating = try backend.snapshot()
        precondition(floating.isFree(floating.windows[0]))
        var drag = WindowDrag(window: floating.windows[0], snapshot: floating,
                              start: CGPoint(x: 100, y: 100), resizing: false,
                              pointer: CGPoint(x: 140, y: 150))
        precondition(drag.preview == CGRect(x: 40, y: 80, width: 400, height: 300))
        try backend.apply(drag)
        precondition(calls == [["window", "1", "--move", "abs:40:80"]])
        calls = []
        drag.pointer = drag.start
        try backend.apply(drag)
        precondition(calls.isEmpty && drag.preview == nil)
        try backend.execute(.wider)
        precondition(calls == [["window", "1", "--resize", "abs:440:300"]])
        calls = []
        let shrinking = WindowDrag(window: floating.windows[0], snapshot: floating,
                                   start: .zero, resizing: true, pointer: CGPoint(x: -1000, y: -1000))
        precondition(shrinking.frame.size == CGSize(width: 160, height: 100))
        layout = "bsp"
        let tiled = try backend.snapshot()
        precondition(tiled.isTiled(tiled.windows[0]))
        let insertion = WindowDrag(window: tiled.windows[0], snapshot: tiled,
                                   start: CGPoint(x: 100, y: 100), resizing: false,
                                   pointer: CGPoint(x: 401, y: 180))
        precondition(insertion.target?.edge == .left)
        precondition(insertion.preview == CGRect(x: 400, y: 30, width: 200, height: 300))
        try backend.apply(insertion)
        precondition(calls == [["window", "2", "--insert", "east"],
                               ["window", "2", "--insert", "west"],
                               ["window", "1", "--warp", "2"]])
        calls = []
        failWarp = true
        do { try backend.apply(insertion); preconditionFailure("Expected failure") } catch {}
        precondition(calls.last == ["window", "2", "--insert", "west"])
        calls = []
        failWarp = false
        records[1] = record(2, originX: 450)
        do { try backend.apply(insertion); preconditionFailure("Expected stale target rejection") } catch {}
        precondition(calls.isEmpty)
        records[1] = record(2, originX: 400)
        records[0] = record(1, originX: 10)
        do { try backend.apply(insertion); preconditionFailure("Expected stale source rejection") } catch {}
        precondition(calls.isEmpty)
        records[0] = record(1)
        layout = "float"
        do { try backend.apply(insertion); preconditionFailure("Expected layout rejection") } catch {}
        precondition(calls.isEmpty)
        layout = "bsp"
        try backend.execute(.taller)
        precondition(calls == [["window", "1", "--resize", "bottom_right:0:40"]])
        calls = []
        try backend.execute(.toggleSplit)
        try backend.execute(.toggleFloat)
        try backend.execute(.tile)
        try backend.execute(.untile)
        precondition(calls == [["window", "1", "--toggle", "split"],
                               ["window", "1", "--toggle", "float"],
                               ["space", "--layout", "bsp"], ["space", "--layout", "float"]])
        calls = []
        do { try backend.execute(.moveLeft); preconditionFailure("Expected tiled move rejection") } catch {}
        precondition(calls.isEmpty)
        let controller = WindowHandlingController()
        controller.armForTesting(insertion)
        precondition(controller.cancelForTesting())
        precondition(controller.releaseForTesting())
        for command in WindowHandlingCommand.allCases {
            precondition(WindowHandlingCommand(rawValue: command.rawValue) == command)
        }
        precondition(WindowHandlingCommand(rawValue: "window wider extra") == nil)
    }
}
'''
        with tempfile.TemporaryDirectory(prefix="ys-handling-tests-", dir="/tmp") as directory:
            root = Path(directory)
            checks = root / "Checks.swift"
            checks.write_text(harness)
            controller = (ROOT / "YabaiIndicator/WindowHandling.swift").read_text()
            combined = root / "WindowHandling.swift"
            combined.write_text(controller + harness)
            binary = root / "checks"
            subprocess.run([
                "xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(root / "cache"),
                str(ROOT / "YabaiIndicator/Models/PanelHotkey.swift"), str(combined), "-o", str(binary),
            ], check=True, timeout=120)
            subprocess.run([str(binary)], check=True, timeout=10)


if __name__ == "__main__":
    unittest.main()
