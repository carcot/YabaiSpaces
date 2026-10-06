from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent


class FocusTrackingTests(unittest.TestCase):
    def compile_and_run(self, source, controller=False):
        with tempfile.TemporaryDirectory(prefix="ys-focus-tests-", dir="/tmp") as directory:
            root = Path(directory)
            harness = root / "Checks.swift"
            if controller:
                production = (ROOT / "YabaiIndicator/Connectors/YabaiClient.swift").read_text()
                source = source.replace("CONTROLLER", production[production.index("final class WindowSwitchController"):])
            harness.write_text(source)
            binary = root / "checks"
            subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(root / "cache"),
                            str(ROOT / "YabaiIndicator/Models/PanelHotkey.swift"),
                            str(ROOT / "YabaiIndicator/WindowSwitching.swift"), str(harness),
                            "-o", str(binary)], check=True, timeout=120)
            subprocess.run([str(binary)], check=True, timeout=20)

    def test_parser_and_bounded_journal(self):
        self.compile_and_run('''import Foundation
@main struct Checks {
    static func main() {
        precondition(FocusEventCommand(rawValue: "event window-focused 42")?.windowID == 42)
        precondition(FocusEventCommand(rawValue: "event window-destroyed 4294967295")?.kind == .destroyed)
        for invalid in ["0", "-1", "+1", "4294967296", "18446744073709551616", "1 extra", " 1", "1\\t", ""] {
            precondition(FocusEventCommand(rawValue: "event window-focused " + invalid) == nil)
        }
        precondition(FocusEventCommand(rawValue: "event unsupported 42") == nil)
        var journal = FocusJournal()
        for identifier: UInt64 in [1, 2, 1, 99] {
            precondition(journal.receive(identifier, now: 1, operation: nil))
        }
        precondition(journal.records.map(\\.windowID) == [1, 2, 1, 99])
        precondition(journal.resolve(eligible: [1, 2], known: [1, 2, 99], through: 4) == [1, 2, 1])
        precondition(journal.records.last?.resolution == "ineligible")
        for identifier in 0..<FocusJournal.capacity {
            precondition(journal.receive(UInt64(identifier + 1), now: 2, operation: 7))
        }
        precondition(!journal.receive(1, now: 3, operation: nil))
        precondition(journal.rejected == 1 && journal.gaps == 1 && journal.evicted == 4)
        precondition(journal.records.count == 1024 && journal.pending.count == 1024)
        journal.destroyed(1)
        precondition(journal.records.first?.resolution == "destroyed")
        _ = journal.resolve(eligible: [2], known: [2], through: journal.sequence)
        precondition(journal.pending.isEmpty)
        precondition(journal.records.last?.resolution == "unavailable")
        journal.failed(); journal.failed()
        precondition(journal.queryFailures == 2 && journal.gaps == 2 && journal.degraded)
        journal.recovered()
        precondition(!journal.degraded)
    }
}
''')

    def test_events_reconciliation_concurrency_and_cancellation(self):
        self.compile_and_run('''import Foundation
struct YabaiResponse { let response: Any }
enum YabaiError: Error { case invalidResponse(String), queryFailed(String) }
class YabaiClient {
    static let lock = NSLock()
    static var focused: UInt64 = 1
    static var space = 1
    static var failQuery = false
    static var blockQuery = false
    static var blockFocus = false
    static var firstPID: UInt64 = 1
    static var signals: [[String: Any]] = []
    static let started = DispatchSemaphore(value: 0)
    static let resume = DispatchSemaphore(value: 0)
    static func setFocus(_ identifier: UInt64) { lock.lock(); focused = identifier; lock.unlock() }
    func yabaiSocketCall(_ args: String...) throws -> YabaiResponse {
        Self.lock.lock()
        if args.contains("signal") {
            if args.contains("--add") {
                let values = Dictionary(uniqueKeysWithValues: args.filter { $0.contains("=") }.map {
                    let fields = $0.split(separator: "=", maxSplits: 1)
                    return (String(fields[0]), String(fields[1]))
                })
                Self.signals.removeAll { $0["label"] as? String == values["label"] }
                Self.signals.append(["label": values["label"]!, "event": values["event"]!, "action": values["action"]!])
            }
            let records = Self.signals
            Self.lock.unlock()
            return YabaiResponse(response: records)
        }
        if !args.contains("--windows") {
            let space = Self.space
            Self.lock.unlock()
            return YabaiResponse(response: ["index": space])
        }
        let focused = Self.focused
        let firstPID = Self.firstPID
        let failing = Self.failQuery
        let blocking = Self.blockQuery
        Self.blockQuery = false
        Self.lock.unlock()
        if blocking { Self.started.signal(); precondition(Self.resume.wait(timeout: .now() + 5) == .success) }
        if failing { throw YabaiError.queryFailed("disconnected") }
        var records: [[String: Any]] = []
        for identifier in 1...4 {
            let windowID = UInt64(identifier)
            let subrole = identifier == 4 ? "AXDialog" : "AXStandardWindow"
            records.append(["id": windowID, "pid": identifier == 1 ? firstPID : windowID, "space": 1, "subrole": subrole,
                            "app": "Test", "is-minimized": false, "is-hidden": false, "has-focus": focused == windowID])
        }
        return YabaiResponse(response: records)
    }
    func focusSpace(index: Int) throws { Self.lock.lock(); Self.space = index; Self.lock.unlock() }
    func focusWindow(id: UInt64) throws {
        Self.setFocus(id)
        Self.lock.lock(); let blocking = Self.blockFocus; Self.blockFocus = false; Self.lock.unlock()
        if blocking { Self.started.signal(); precondition(Self.resume.wait(timeout: .now() + 5) == .success) }
    }
}
CONTROLLER
extension WindowSwitchController {
    func drain() {
        worker.sync {}
        for _ in 0..<6 { queue.sync {}; observationWorker.sync {}; queue.sync {} }
    }
    func drainObservations() {
        for _ in 0..<6 { queue.sync {}; observationWorker.sync {}; queue.sync {} }
    }
    func status() -> [String: Any] { try! JSONSerialization.jsonObject(with: Data(diagnostics().utf8)) as! [String: Any] }
    func history() -> [UInt64] { queue.sync { switching.history } }
    func cycle() -> TimeInterval? { queue.sync { switching.cycleDeadline } }
    func registerSignals() { ensureSignals(); queue.sync {} }
}
@main struct Checks {
    static func event(_ identifier: UInt64) -> FocusEventCommand { FocusEventCommand(rawValue: "event window-focused \\(identifier)")! }
    static func main() {
        let controller = WindowSwitchController()
        controller.observe(); controller.drain()
        precondition(controller.history() == [1, 2, 3])
        YabaiClient.blockQuery = true
        controller.observe()
        precondition(YabaiClient.started.wait(timeout: .now() + 2) == .success)
        YabaiClient.setFocus(3)
        let start = ProcessInfo.processInfo.systemUptime
        precondition(controller.receive(event(2)) && controller.receive(event(3)))
        precondition(ProcessInfo.processInfo.systemUptime - start < 0.2)
        precondition(controller.status()["accepted"] as? Int == 2)
        YabaiClient.resume.signal(); controller.drain()
        precondition(controller.history() == [3, 2, 1])
        precondition(controller.receive(event(3)) && controller.receive(event(2)))
        controller.drain()
        precondition(controller.history().first == 3)
        YabaiClient.setFocus(1)
        for identifier: UInt64 in [1, 2, 1] { precondition(controller.receive(event(identifier))) }
        controller.drain()
        let records = controller.status()["records"] as! [[String: Any]]
        precondition(records.suffix(3).map { $0["window"] as! Int } == [1, 2, 1])
        precondition(controller.history().first == 1)
        controller.execute(.nextWindowInSpace); controller.drain()
        precondition(controller.cycle() != nil)
        YabaiClient.setFocus(4); precondition(controller.receive(event(4))); controller.drain()
        precondition(controller.cycle() == nil && !controller.history().contains(4))
        precondition((controller.status()["records"] as! [[String: Any]]).last?["resolution"] as? String == "ineligible")
        precondition(controller.receive(event(99))); controller.drain()
        precondition((controller.status()["records"] as! [[String: Any]]).last?["resolution"] as? String == "unavailable")
        let beforeFailure = controller.history()
        YabaiClient.failQuery = true; controller.observe(); controller.drain()
        precondition(controller.history() == beforeFailure && controller.status()["degraded"] as? Bool == true)
        YabaiClient.failQuery = false; YabaiClient.setFocus(1); controller.observe(); controller.drain()
        precondition(controller.status()["degraded"] as? Bool == false && controller.history().first == 1)
        YabaiClient.blockFocus = true
        controller.execute(.nextWindowInSpace)
        precondition(YabaiClient.started.wait(timeout: .now() + 2) == .success)
        YabaiClient.setFocus(3); precondition(controller.receive(event(3)))
        controller.drainObservations()
        precondition(controller.cycle() == nil && controller.history().first == 3)
        YabaiClient.resume.signal(); controller.drain()
        precondition(controller.history().first == 3 && controller.cycle() == nil)
        controller.execute(.nextWindowInSpace); controller.drain()
        let cycleBefore = controller.cycle()
        let liveFocus = controller.status()["current"] as! Int
        precondition(controller.receive(event(99)))
        precondition(controller.receive(event(UInt64(liveFocus))))
        controller.drain()
        precondition(controller.cycle() == cycleBefore)
        controller.observe(endingCycle: true); controller.drain()
        precondition(controller.receive(FocusEventCommand(rawValue: "event window-destroyed 2")!))
        controller.drain()
        precondition(!controller.history().contains(2))
        YabaiClient.setFocus(3); controller.observe(); controller.drain()
        YabaiClient.firstPID = 100
        controller.observe(); controller.drain()
        precondition(controller.history() == [3, 1])
        YabaiClient.signals = [["label": "other-consumer", "event": "window_focused", "action": "unchanged"]]
        controller.registerSignals(); controller.registerSignals()
        precondition(YabaiClient.signals.count == 6)
        precondition(YabaiClient.signals.first?["action"] as? String == "unchanged")
        precondition(controller.status()["signalsHealthy"] as? Bool == true)
        let gaps = controller.status()["gaps"] as! Int
        YabaiClient.signals.removeAll { $0["label"] as? String == "ys-focus-window" }
        controller.registerSignals()
        precondition(YabaiClient.signals.count == 6 && controller.status()["gaps"] as! Int == gaps + 1)
    }
}
''', controller=True)


if __name__ == "__main__":
    unittest.main()
