from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent


def method(source, signature):
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


class ThumbnailCaptureTests(unittest.TestCase):
    def test_capture_and_switch_ordering(self):
        delegate = (ROOT / "YabaiIndicator/YabaiAppDelegate.swift").read_text()
        client = (ROOT / "YabaiIndicator/Connectors/YabaiClient.swift").read_text()
        preparation = "\n".join(method(delegate, signature) for signature in (
            "func captureVisibleThumbnails()",
            "func prepareForSpaceSwitch(to index: Int)",
            "func onWillFocusSpace(_ notification: Notification)",
        ))
        focus = method(client, "func focusSpace(index: Int)")
        harness = r'''import Foundation
struct Space {
    let yabaiIndex: Int
    let display: Int
    let active: Bool
    let visible: Bool
}
class NativeClient {
    var spaces = [Space(yabaiIndex: 1, display: 1, active: true, visible: true),
                  Space(yabaiIndex: 2, display: 1, active: false, visible: false),
                  Space(yabaiIndex: 3, display: 2, active: false, visible: true),
                  Space(yabaiIndex: 4, display: 2, active: false, visible: false)]
    func querySpaces() -> [Space] { spaces }
}
let gNativeClient = NativeClient()
enum CursorPolicy { case restore, skip }
class Panel {
    var isVisible = false
    var cursorRestorationPolicy = CursorPolicy.restore
}
var events: [String] = []
class Delegate {
    var floatingPanel: Panel? = Panel()
    var panelManager: Panel? { floatingPanel }
    func captureThumbnail(for space: Space) {
        precondition(Thread.isMainThread)
        precondition(floatingPanel?.isVisible != true)
        events.append("capture-\(space.yabaiIndex)")
    }
    func hidePanel() {
        precondition(Thread.isMainThread)
        floatingPanel?.isVisible = false
        events.append("hide")
    }
''' + preparation + r'''
}
class YabaiClient {
    static let willFocusSpace = Notification.Name("YabaiSpaces.willFocusSpace")
    var fail = false
    func yabaiSocketCall(_ args: String...) throws {
        events.append("focus-\(args.last!)")
        if fail { throw NSError(domain: "test", code: 1) }
    }
''' + focus + r'''
}
@main struct Checks {
    static func main() throws {
        let delegate = Delegate()
        let observer = NotificationCenter.default.addObserver(
            forName: YabaiClient.willFocusSpace, object: nil, queue: nil
        ) { delegate.onWillFocusSpace($0) }
        defer { NotificationCenter.default.removeObserver(observer) }
        let client = YabaiClient()
        delegate.captureVisibleThumbnails()
        precondition(events == ["capture-1", "capture-3"])
        delegate.floatingPanel?.isVisible = true
        events = []
        delegate.captureVisibleThumbnails()
        precondition(events.isEmpty)
        try client.focusSpace(index: 2)
        precondition(events == ["hide", "focus-2"])
        precondition(delegate.panelManager?.cursorRestorationPolicy == .skip)
        events = []
        try client.focusSpace(index: 2)
        precondition(events == ["capture-1", "focus-2"])
        events = []
        try client.focusSpace(index: 4)
        precondition(events == ["capture-1", "capture-3", "focus-4"])
        events = []
        try client.focusSpace(index: 1)
        precondition(events == ["focus-1"])
        events = []
        try client.focusSpace(index: 99)
        precondition(events == ["focus-99"])
        gNativeClient.spaces = [Space(yabaiIndex: 2, display: 1, active: true, visible: true),
                               Space(yabaiIndex: 1, display: 1, active: false, visible: false)]
        events = []
        try client.focusSpace(index: 1)
        precondition(events == ["capture-2", "focus-1"])
        events = []
        client.fail = true
        do {
            try client.focusSpace(index: 1)
            preconditionFailure("Expected focus failure")
        } catch {}
        precondition(events == ["capture-2", "focus-1"])
        client.fail = false
        events = []
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            try! client.focusSpace(index: 1)
            done.signal()
        }
        while done.wait(timeout: .now()) != .success {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        precondition(events == ["capture-2", "focus-1"])
    }
}
'''
        with tempfile.TemporaryDirectory(prefix="ys-thumbnail-tests-", dir="/tmp") as directory:
            root = Path(directory)
            source = root / "Checks.swift"
            source.write_text(harness)
            binary = root / "checks"
            subprocess.run([
                "xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(root / "cache"),
                str(source), "-o", str(binary),
            ], check=True, timeout=120)
            subprocess.run([str(binary)], check=True, timeout=10)


if __name__ == "__main__":
    unittest.main()
