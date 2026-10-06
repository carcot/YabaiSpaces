from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent


class CyclingBorderTests(unittest.TestCase):
    def test_border_tracks_window_and_expires_without_focus(self):
        harness = r'''import AppKit
extension CyclingWindowBorder {
    var visibleForTesting: Bool { panel?.isVisible == true }
    var panelForTesting: NSPanel? { panel }
    var deadlineForTesting: TimeInterval { deadline }
    var thicknessForTesting: CGFloat { borderLayer.lineWidth }
    func verifyAdjacentForTesting() {
        let path = borderLayer.path!.boundingBox
        let halfWidth = borderLayer.lineWidth / 2
        let bounds = panel!.contentView!.bounds
        precondition(abs(path.minX + halfWidth - 3) < 0.001)
        precondition(abs(path.minY + halfWidth - 3) < 0.001)
        precondition(abs(path.maxX - halfWidth - (bounds.maxX - 3)) < 0.001)
        precondition(abs(path.maxY - halfWidth - (bounds.maxY - 3)) < 0.001)
    }
}
@main struct Checks {
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        let originalApplication = NSWorkspace.shared.frontmostApplication?.processIdentifier
        precondition(CyclingWindowBorder.thickness(deadline: 12, now: 10) == 3)
        precondition(CyclingWindowBorder.thickness(deadline: 12, now: 11) == 1.5)
        precondition(CyclingWindowBorder.thickness(deadline: 12, now: 12) == 0)
        precondition(CyclingWindowBorder.thickness(deadline: 12, now: 13) == 0)
        let window = NSWindow(contentRect: CGRect(x: 100, y: 100, width: 200, height: 150),
                              styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.title = "YS border regression"
        window.orderBack(nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        defer { window.orderOut(nil) }
        let border = CyclingWindowBorder()
        let firstDeadline = ProcessInfo.processInfo.systemUptime + 0.5
        border.update(windowID: UInt64(window.windowNumber), deadline: firstDeadline)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        precondition(border.visibleForTesting, "Border missing for \(window.windowNumber): \(String(describing: CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(window.windowNumber))))")
        let panel = border.panelForTesting!
        precondition(panel.ignoresMouseEvents && !panel.canBecomeKey && !panel.canBecomeMain)
        precondition(panel.sharingType == .none && !panel.hasShadow)
        precondition(panel.animationBehavior == .none)
        let initialThickness = border.thicknessForTesting
        precondition(initialThickness > 0 && initialThickness < 3)
        border.verifyAdjacentForTesting()
        let oldFrame = panel.frame
        let oldWindowFrame = window.frame
        window.setFrameOrigin(CGPoint(x: 250, y: 220))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        precondition(border.thicknessForTesting < initialThickness)
        border.verifyAdjacentForTesting()
        precondition(panel.frame.origin.x - oldFrame.origin.x == window.frame.origin.x - oldWindowFrame.origin.x)
        precondition(panel.frame.origin.y - oldFrame.origin.y == window.frame.origin.y - oldWindowFrame.origin.y,
                     "Border \(oldFrame) -> \(panel.frame), window \(oldWindowFrame) -> \(window.frame)")
        border.isBlocked = { true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
        precondition(!border.visibleForTesting && border.deadlineForTesting == firstDeadline)
        border.isBlocked = { false }
        let renewedDeadline = ProcessInfo.processInfo.systemUptime + 0.5
        border.update(windowID: UInt64(window.windowNumber), deadline: renewedDeadline)
        precondition(border.panelForTesting === panel && border.visibleForTesting)
        let renewedThickness = border.thicknessForTesting
        border.verifyAdjacentForTesting()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        precondition(border.visibleForTesting)
        precondition(border.thicknessForTesting < renewedThickness)
        border.verifyAdjacentForTesting()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        precondition(!border.visibleForTesting && border.deadlineForTesting == 0)
        border.update(windowID: UInt64(window.windowNumber), deadline: ProcessInfo.processInfo.systemUptime + 2)
        precondition(border.visibleForTesting)
        precondition(border.thicknessForTesting > 2.9)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.05))
        precondition((1.3...1.6).contains(border.thicknessForTesting))
        border.verifyAdjacentForTesting()
        border.update(windowID: nil, deadline: nil)
        precondition(!border.visibleForTesting)
        precondition(NSWorkspace.shared.frontmostApplication?.processIdentifier == originalApplication)
    }
}
'''
        with tempfile.TemporaryDirectory(prefix="ys-border-tests-", dir="/tmp") as directory:
            root = Path(directory)
            checks = root / "Checks.swift"
            checks.write_text((ROOT / "YabaiIndicator/CyclingWindowBorder.swift").read_text() + harness)
            binary = root / "checks"
            subprocess.run([
                "xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(root / "cache"),
                str(ROOT / "YabaiIndicator/Models/PanelHotkey.swift"),
                str(ROOT / "YabaiIndicator/WindowSwitching.swift"),
                str(checks), "-o", str(binary),
            ], check=True, timeout=120)
            subprocess.run([str(binary)], check=True, timeout=10)


if __name__ == "__main__":
    unittest.main()
