from pathlib import Path
import json
import platform
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
    def test_excluded_capture_memory_stays_bounded(self):
        self.check_capture_memory(excluded=True)

    def test_display_capture_memory_stays_bounded(self):
        self.check_capture_memory(excluded=False)

    def check_capture_memory(self, excluded):
        harness = r'''import AppKit
import Darwin
struct Display { let id: UInt32 }
func footprint() -> UInt64 {
    var information = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: information) / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &information) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    precondition(result == KERN_SUCCESS)
    return information.phys_footprint
}
@main struct Checks {
    static func main() {
        guard CGPreflightScreenCaptureAccess() else { exit(77) }
        let displayID = CGMainDisplayID()
        let display = Display(id: displayID)
        let capture = PrivateWindowCapture()
        let excludedWindowIDs: Set<CGWindowID> = EXCLUDED_WINDOWS
        for _ in 0..<4 {
            autoreleasepool {
                precondition(capture.captureSpace(display: display, targetSize: CGSize(width: 160, height: 90),
                                                  excludingWindowIDs: excludedWindowIDs)?.isEmpty == false)
            }
        }
        let before = footprint()
        for _ in 0..<24 {
            autoreleasepool {
                precondition(capture.captureSpace(display: display, targetSize: CGSize(width: 160, height: 90),
                                                  excludingWindowIDs: excludedWindowIDs)?.isEmpty == false)
            }
        }
        let after = footprint()
        let frameBytes = UInt64(CGDisplayPixelsWide(displayID) * CGDisplayPixelsHigh(displayID) * 4)
        let output = ["before": before, "after": after, "limit": max(32 * 1024 * 1024, frameBytes * 3)]
        let data = try! JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
        print(String(data: data, encoding: .utf8)!)
    }
}
'''.replace("EXCLUDED_WINDOWS", "[CGWindowID.max]" if excluded else "[]")
        with tempfile.TemporaryDirectory(prefix="ys-thumbnail-memory-", dir="/tmp") as directory:
            root = Path(directory)
            source = root / "Checks.swift"
            source.write_text(harness)
            binary = root / "checks"
            subprocess.run([
                "xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(root / "cache"),
                "-target", f"{platform.machine()}-apple-macos11.6",
                str(ROOT / "YabaiIndicator/PrivateWindowCapture.swift"), str(source), "-o", str(binary),
            ], check=True, timeout=120)
            result = subprocess.run([str(binary)], capture_output=True, text=True, timeout=60)
            if result.returncode == 77:
                self.skipTest("Capture memory verification requires existing Screen Recording permission; no permission was requested")
            self.assertEqual(result.returncode, 0, result.stderr)
            memory = json.loads(result.stdout)
            print(f"Capture footprint (excluded={excluded}): {memory}", flush=True)
            self.assertLessEqual(memory["after"] - memory["before"], memory["limit"],
                                 "Repeated captures retain full-screen image buffers")

    def test_shared_service_ownership_validation_and_failure(self):
        harness = r'''import AppKit
struct Display { let id: UInt32 }
class Lifetime {
    var released = 0
    var captures = 0
    var encodes = 0
}
func image(_ lifetime: Lifetime) -> CGImage {
    let pixels = UnsafeMutableRawPointer.allocate(byteCount: 16, alignment: 8)
    pixels.initializeMemory(as: UInt8.self, repeating: 255, count: 16)
    let provider = CGDataProvider(dataInfo: Unmanaged.passUnretained(lifetime).toOpaque(),
                                  data: pixels, size: 16, releaseData: { context, bytes, _ in
        Unmanaged<Lifetime>.fromOpaque(context!).takeUnretainedValue().released += 1
        UnsafeMutableRawPointer(mutating: bytes).deallocate()
    })!
    return CGImage(width: 2, height: 2, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 8,
                   space: CGColorSpaceCreateDeviceRGB(),
                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                   provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
}
@main struct Checks {
    static func main() {
        let lifetime = Lifetime()
        var failCapture = false
        var encoding: Data? = Data([1, 2, 3])
        let service = ScreenshotCaptureService(captureImage: { request in
            precondition(request.excludedWindowIDs == [42])
            lifetime.captures += 1
            return failCapture ? nil : image(lifetime)
        }, encodePNG: { scaled in
            precondition(scaled.width == 1 && scaled.height == 1)
            lifetime.encodes += 1
            return encoding
        })
        let request = ScreenshotRequest(displayID: CGMainDisplayID(), targetSize: CGSize(width: 1, height: 1),
                                        excludedWindowIDs: [42])
        for _ in 0..<20 {
            guard case .success(let data) = service.capture(request) else { fatalError("Capture failed") }
            precondition(data == Data([1, 2, 3]))
        }
        precondition(lifetime.released == 20 && lifetime.captures == 20 && lifetime.encodes == 20)
        for output: Data? in [nil, Data()] {
            encoding = output
            guard case .failure(.encodingFailed) = service.capture(request) else { fatalError("Bad encoding accepted") }
        }
        precondition(lifetime.released == 22)
        failCapture = true
        guard case .failure(.captureUnavailable) = service.capture(request) else { fatalError("Fallback bypassed failure") }
        precondition(lifetime.captures == 23 && lifetime.encodes == 22 && lifetime.released == 22)
        let invalidSizes = [CGSize.zero, CGSize(width: -1, height: 1), CGSize(width: CGFloat.nan, height: 1),
                            CGSize(width: CGFloat.infinity, height: 1), CGSize(width: 8193, height: 1),
                            CGSize(width: 8192, height: 8192)]
        for size in invalidSizes {
            let invalid = ScreenshotRequest(displayID: request.displayID, targetSize: size, excludedWindowIDs: [42])
            guard case .failure(.invalidRequest) = service.capture(invalid) else { fatalError("Bad size accepted") }
        }
        for identifier: CGDirectDisplayID in [0, .max] {
            let invalid = ScreenshotRequest(displayID: identifier, targetSize: request.targetSize)
            guard case .failure(.invalidRequest) = service.capture(invalid) else { fatalError("Bad display accepted") }
        }
        let invalid = ScreenshotRequest(displayID: request.displayID, targetSize: request.targetSize, excludedWindowIDs: [0])
        guard case .failure(.invalidRequest) = service.capture(invalid) else { fatalError("Bad exclusion accepted") }
        precondition(lifetime.captures == 23 && lifetime.encodes == 22)
        print("Shared service releases buffers on success/failure, rejects invalid requests, and never retries without exclusions")
    }
}
'''
        with tempfile.TemporaryDirectory(prefix="ys-capture-service-", dir="/tmp") as directory:
            root = Path(directory)
            source = root / "Checks.swift"
            source.write_text(harness)
            binary = root / "checks"
            subprocess.run([
                "xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(root / "cache"),
                "-target", f"{platform.machine()}-apple-macos11.6",
                str(ROOT / "YabaiIndicator/PrivateWindowCapture.swift"), str(source), "-o", str(binary),
            ], check=True, timeout=120)
            subprocess.run([str(binary)], check=True, timeout=15)

    def test_capture_ignores_unrepresentable_window_numbers(self):
        delegate = (ROOT / "YabaiIndicator/YabaiAppDelegate.swift").read_text()
        harness = r'''import Foundation
import CoreGraphics
typealias CGWindowID = UInt32
struct Space { let display = 1; let spaceid: UInt64 = 42 }
struct Display { let index = 0; let frame = CGRect(x: 0, y: 0, width: 1920, height: 1080) }
class NativeClient { func queryDisplays() -> [Display] { [Display()] } }
let gNativeClient = NativeClient()
struct Window { let windowNumber: Int }
struct Application {
    let windows = [-1, 0, 123, Int(UInt32.max), Int(UInt32.max) + 1, Int.max].map { Window(windowNumber: $0) }
}
let NSApp = Application()
class Capture {
    func captureSpace(display: Display, targetSize: CGSize, excludingWindowIDs: Set<CGWindowID>) -> Data? {
        precondition(excludingWindowIDs == [123, UInt32.max])
        return Data([1, 2, 3])
    }
}
let gPrivateWindowCapture = Capture()
class Cache {
    var captured = false
    func set(spaceId: UInt64, data: Data) {
        precondition(spaceId == 42 && data == Data([1, 2, 3]))
        captured = true
    }
}
let gThumbnailCache = Cache()
struct Layout { let scale: CGFloat = 1 }
class Delegate {
    let panelLayout = Layout()
''' + method(delegate, "func captureThumbnail(for space: Space)") + r'''
}
@main struct Checks {
    static func main() {
        Delegate().captureThumbnail(for: Space())
        precondition(gThumbnailCache.captured)
    }
}
'''
        with tempfile.TemporaryDirectory(prefix="ys-thumbnail-ids-", dir="/tmp") as directory:
            root = Path(directory)
            source = root / "Checks.swift"
            source.write_text(harness)
            binary = root / "checks"
            subprocess.run([
                "xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(root / "cache"),
                str(source), "-o", str(binary),
            ], check=True, timeout=120)
            subprocess.run([str(binary)], check=True, timeout=10)

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
var scene = "before-panel"
var capturedScenes: [Int: String] = [:]
class WindowHandlingController {
    var previewVisible = false
    func cancel() {
        precondition(Thread.isMainThread)
        previewVisible = false
    }
}
class CyclingWindowBorder {
    var visible = false
    func hide() { visible = false }
}
class Delegate {
    let windowHandlingController = WindowHandlingController()
    let cyclingWindowBorder = CyclingWindowBorder()
    var floatingPanel: Panel? = Panel()
    var panelManager: Panel? { floatingPanel }
    func captureThumbnail(for space: Space) {
        precondition(Thread.isMainThread)
        precondition(floatingPanel?.isVisible != true)
        precondition(!windowHandlingController.previewVisible)
        precondition(!cyclingWindowBorder.visible)
        events.append("capture-\(space.yabaiIndex)")
        capturedScenes[space.yabaiIndex] = scene
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
        delegate.cyclingWindowBorder.visible = true
        delegate.captureVisibleThumbnails()
        precondition(events == ["capture-1", "capture-3"])
        precondition(capturedScenes[1] == "before-panel")
        delegate.floatingPanel?.isVisible = true
        scene = "just-before-departure"
        events = []
        delegate.captureVisibleThumbnails()
        precondition(events.isEmpty)
        try client.focusSpace(index: 2)
        precondition(events == ["hide", "capture-1", "focus-2"])
        precondition(capturedScenes[1] == "just-before-departure")
        precondition(delegate.panelManager?.cursorRestorationPolicy == .skip)
        events = []
        delegate.windowHandlingController.previewVisible = true
        delegate.cyclingWindowBorder.visible = true
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

    def test_departure_pixels_are_fresh_after_real_panel_hide(self):
        delegate = (ROOT / "YabaiIndicator/YabaiAppDelegate.swift").read_text()
        manager = (ROOT / "YabaiIndicator/Managers/PanelManager.swift").read_text()
        self.assertIn("panel.animationBehavior = .none", method(manager, "func createPanel()"))
        preparation = "\n".join(method(delegate, signature) for signature in (
            "func captureVisibleThumbnails()", "func prepareForSpaceSwitch(to index: Int)",
        ))
        harness = r'''import AppKit
struct Display { let id: UInt32 }
struct Space {
    let yabaiIndex: Int
    let display: Int
    let active: Bool
    let visible: Bool
}
class NativeClient {
    func querySpaces() -> [Space] {
        [Space(yabaiIndex: 1, display: 1, active: true, visible: true),
         Space(yabaiIndex: 2, display: 1, active: false, visible: false)]
    }
}
let gNativeClient = NativeClient()
enum CursorRestorationPolicy { case restore, skip }
class Manager {
    var panel: NSPanel?
    var cursorRestorationPolicy = CursorRestorationPolicy.restore
    var onPanelHide: (() -> Void)?
    func stopClickOutsideMonitor() {}
    func restoreCursorPosition() { preconditionFailure("Unexpected cursor restoration") }
''' + method(manager, "func hide()") + r'''
}
class WindowHandlingController { func cancel() {} }
class CyclingWindowBorder { func hide() {} }
func currentPixel(excludingWindowIDs: Set<CGWindowID> = []) -> NSColor {
    let data = gPrivateWindowCapture.captureSpace(
        display: Display(id: CGMainDisplayID()), targetSize: CGSize(width: 400, height: 200),
        excludingWindowIDs: excludingWindowIDs)!
    let bitmap = NSBitmapImageRep(data: data)!
    return bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2)!.usingColorSpace(.deviceRGB)!
}
class Delegate {
    let windowHandlingController = WindowHandlingController()
    let cyclingWindowBorder = CyclingWindowBorder()
    let panelManager = Manager()
    var floatingPanel: NSPanel? { panelManager.panel }
    var pixel: NSColor?
    func captureThumbnail(for space: Space) {
        precondition(!floatingPanel!.isVisible)
        pixel = currentPixel(excludingWindowIDs: [CGWindowID(floatingPanel!.windowNumber)])
    }
    func hidePanel() { panelManager.hide() }
''' + preparation.replace("panelManager?.", "panelManager.") + r'''
}
@main struct Checks {
    static func main() {
        guard CGPreflightScreenCaptureAccess() else { exit(77) }
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        let originalApplication = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let screen = NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == CGMainDisplayID()
        }!
        let frame = CGRect(x: screen.frame.midX - 140, y: screen.frame.midY - 100, width: 280, height: 200)
        let background = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                 backing: .buffered, defer: false)
        background.level = .floating
        background.animationBehavior = .none
        background.hasShadow = false
        background.backgroundColor = .red
        background.orderFrontRegardless()
        let delegate = Delegate()
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: background.level.rawValue + 1)
        panel.animationBehavior = .none
        panel.hasShadow = false
        panel.backgroundColor = .blue
        delegate.panelManager.panel = panel
        defer { panel.orderOut(nil); background.orderOut(nil) }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        delegate.captureVisibleThumbnails()
        precondition(delegate.pixel!.redComponent > 0.8 && delegate.pixel!.greenComponent < 0.2)
        for _ in 0..<8 {
            background.backgroundColor = .red
            panel.orderFrontRegardless()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.08))
            precondition(currentPixel().blueComponent > 0.8)
            background.backgroundColor = .green
            background.displayIfNeeded()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.04))
            delegate.prepareForSpaceSwitch(to: 2)
            let pixel = delegate.pixel!
            precondition(pixel.greenComponent > 0.8 && pixel.redComponent < 0.2 && pixel.blueComponent < 0.2,
                         "Departure image is stale or contains the panel: \(pixel)")
        }
        precondition(NSWorkspace.shared.frontmostApplication?.processIdentifier == originalApplication)
    }
}
'''
        with tempfile.TemporaryDirectory(prefix="ys-thumbnail-pixels-", dir="/tmp") as directory:
            root = Path(directory)
            source = root / "Checks.swift"
            source.write_text(harness)
            binary = root / "checks"
            subprocess.run([
                "xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(root / "cache"),
                "-target", f"{platform.machine()}-apple-macos11.6",
                str(ROOT / "YabaiIndicator/PrivateWindowCapture.swift"), str(source), "-o", str(binary),
            ], check=True, timeout=120)
            result = subprocess.run([str(binary)], timeout=15)
            if result.returncode == 77:
                self.skipTest("Pixel verification requires existing Screen Recording permission; no permission was requested")
            self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
