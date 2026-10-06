import AppKit

enum PlacementEdge: String, CaseIterable {
    case left = "west", right = "east", top = "north", bottom = "south"

    var opposite: PlacementEdge {
        switch self {
        case .left: return .right
        case .right: return .left
        case .top: return .bottom
        case .bottom: return .top
        }
    }

    func preview(in frame: CGRect) -> CGRect {
        switch self {
        case .left: return CGRect(x: frame.minX, y: frame.minY, width: frame.width / 2, height: frame.height)
        case .right: return CGRect(x: frame.midX, y: frame.minY, width: frame.width / 2, height: frame.height)
        case .top: return CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: frame.height / 2)
        case .bottom: return CGRect(x: frame.minX, y: frame.midY, width: frame.width, height: frame.height / 2)
        }
    }
}

struct PlacementTarget: Equatable {
    let windowID: UInt64
    let edge: PlacementEdge

    static func resolve(pointer: CGPoint, draggedID: UInt64,
                        intendedSlots: [UInt64: CGRect]) -> PlacementTarget? {
        guard pointer.x.isFinite, pointer.y.isFinite else { return nil }
        let hits = intendedSlots.filter { windowID, frame in
            guard windowID != draggedID,
                  frame.origin.x.isFinite, frame.origin.y.isFinite,
                  frame.size.width.isFinite, frame.size.height.isFinite,
                  frame.size.width > 0, frame.size.height > 0 else { return false }
            return pointer.x >= frame.minX && pointer.x <= frame.maxX
                && pointer.y >= frame.minY && pointer.y <= frame.maxY
        }
        guard hits.count == 1, let (windowID, frame) = hits.first else { return nil }
        let distances: [(PlacementEdge, CGFloat)] = [
            (.left, (pointer.x - frame.minX) / frame.width),
            (.right, (frame.maxX - pointer.x) / frame.width),
            (.top, (pointer.y - frame.minY) / frame.height),
            (.bottom, (frame.maxY - pointer.y) / frame.height)
        ]
        let edge = distances.dropFirst().reduce(distances[0]) { nearest, candidate in
            candidate.1 < nearest.1 ? candidate : nearest
        }.0
        return PlacementTarget(windowID: windowID, edge: edge)
    }
}

struct HandledWindow: Equatable {
    let id: UInt64
    let pid: Int
    let space: Int
    let frame: CGRect
    let floating: Bool
    let resizable: Bool
    let focused: Bool

    init?(_ record: [String: Any]) {
        guard let id = record["id"] as? UInt64, id > 0,
              let pid = record["pid"] as? Int, pid > 0,
              let space = record["space"] as? Int, space > 0,
              record["subrole"] as? String == "AXStandardWindow",
              record["is-visible"] as? Bool == true,
              record["is-minimized"] as? Bool == false,
              record["is-hidden"] as? Bool == false,
              record["is-native-fullscreen"] as? Bool == false,
              record["has-fullscreen-zoom"] as? Bool == false,
              record["has-parent-zoom"] as? Bool == false,
              record["is-sticky"] as? Bool == false,
              record["can-move"] as? Bool == true,
              record["has-ax-reference"] as? Bool == true,
              let values = record["frame"] as? [String: Double],
              let originX = values["x"], let originY = values["y"],
              let width = values["w"], let height = values["h"],
              [originX, originY, width, height].allSatisfy({ $0.isFinite }),
              width > 0, height > 0 else { return nil }
        self.id = id
        self.pid = pid
        self.space = space
        frame = CGRect(x: originX, y: originY, width: width, height: height)
        floating = record["is-floating"] as? Bool == true
        resizable = record["can-resize"] as? Bool == true
        focused = record["has-focus"] as? Bool == true
    }
}

struct HandlingSnapshot {
    var windows: [HandledWindow] = []
    var layouts: [Int: String] = [:]
    var capturedAt: TimeInterval = 0

    func isTiled(_ window: HandledWindow) -> Bool { layouts[window.space] == "bsp" && !window.floating }
    func isFree(_ window: HandledWindow) -> Bool { layouts[window.space] == "float" || window.floating }
}

struct WindowDrag {
    let window: HandledWindow
    let snapshot: HandlingSnapshot
    let start: CGPoint
    let resizing: Bool
    var pointer: CGPoint

    var moved: Bool { hypot(pointer.x - start.x, pointer.y - start.y) >= 5 }
    var target: PlacementTarget? {
        guard !resizing, snapshot.isTiled(window) else { return nil }
        let candidates = snapshot.windows.filter {
            $0.space == window.space && snapshot.isTiled($0)
        }
        return PlacementTarget.resolve(pointer: pointer, draggedID: window.id,
                                       intendedSlots: Dictionary(uniqueKeysWithValues: candidates.map { ($0.id, $0.frame) }))
    }
    var frame: CGRect {
        let deltaX = pointer.x - start.x
        let deltaY = pointer.y - start.y
        if !resizing { return window.frame.offsetBy(dx: deltaX, dy: deltaY) }
        return CGRect(x: window.frame.minX, y: window.frame.minY,
                      width: max(160, window.frame.width + deltaX),
                      height: max(100, window.frame.height + deltaY))
    }
    var preview: CGRect? {
        guard moved else { return nil }
        if let target, let destination = snapshot.windows.first(where: { $0.id == target.windowID }) {
            return target.edge.preview(in: destination.frame)
        }
        return snapshot.isFree(window) || resizing ? frame : nil
    }
}

final class WindowHandlingBackend {
    typealias Request = ([String]) throws -> Any
    private let request: Request

    init(request: @escaping Request = { arguments in
        let result = gYabaiClient._yabaiSocketCall(["-m"] + arguments)
        guard result.0 == 0 else { throw YabaiError.queryFailed(result.1) }
        guard !result.1.isEmpty else { return [] }
        return try JSONSerialization.jsonObject(with: Data(result.1.utf8))
    }) { self.request = request }

    func snapshot() throws -> HandlingSnapshot {
        guard let records = try request(["query", "--windows"]) as? [[String: Any]],
              let spaces = try request(["query", "--spaces"]) as? [[String: Any]] else {
            throw YabaiError.invalidResponse("Expected window handling snapshot")
        }
        var result = HandlingSnapshot()
        result.windows = records.compactMap(HandledWindow.init)
        for space in spaces {
            if let index = space["index"] as? Int, let layout = space["type"] as? String,
               space["is-visible"] as? Bool == true { result.layouts[index] = layout }
        }
        result.capturedAt = ProcessInfo.processInfo.systemUptime
        return result
    }

    func apply(_ drag: WindowDrag) throws {
        guard drag.moved else { return }
        let current = try snapshot()
        guard current.windows.contains(drag.window),
              current.layouts[drag.window.space] == drag.snapshot.layouts[drag.window.space] else {
            throw YabaiError.queryFailed("Window or Space changed during drag; cancelled")
        }
        let identifier = String(drag.window.id)
        if let target = drag.target {
            let originalMembers = drag.snapshot.windows.filter { $0.space == drag.window.space }.sorted { $0.id < $1.id }
            let currentMembers = current.windows.filter { $0.space == drag.window.space }.sorted { $0.id < $1.id }
            guard originalMembers == currentMembers else {
                throw YabaiError.queryFailed("Space membership or geometry changed; cancelled")
            }
            guard let original = drag.snapshot.windows.first(where: { $0.id == target.windowID }),
                  current.windows.contains(original), current.isTiled(original) else {
                throw YabaiError.queryFailed("Insertion target changed; cancelled")
            }
            let destination = String(target.windowID)
            _ = try request(["window", destination, "--insert", target.edge.opposite.rawValue])
            _ = try request(["window", destination, "--insert", target.edge.rawValue])
            do {
                _ = try request(["window", identifier, "--warp", destination])
            } catch {
                _ = try? request(["window", destination, "--insert", target.edge.rawValue])
                throw error
            }
        } else if drag.resizing {
            guard drag.window.resizable else { return }
            let frame = drag.frame
            let size = current.isTiled(drag.window)
                ? "bottom_right:\(Int(frame.width - drag.window.frame.width)):\(Int(frame.height - drag.window.frame.height))"
                : "abs:\(Int(frame.width)):\(Int(frame.height))"
            _ = try request(["window", identifier, "--resize", size])
        } else if current.isFree(drag.window) {
            _ = try request(["window", identifier, "--move", "abs:\(Int(drag.frame.minX)):\(Int(drag.frame.minY))"])
        }
    }

    func execute(_ command: WindowHandlingCommand) throws {
        if command == .tile || command == .untile {
            _ = try request(["space", "--layout", command == .tile ? "bsp" : "float"])
            return
        }
        let state = try snapshot()
        guard let window = state.windows.first(where: \.focused) else {
            throw YabaiError.queryFailed("No eligible focused window")
        }
        let identifier = String(window.id)
        switch command {
        case .toggleFloat:
            guard state.layouts[window.space] == "bsp" else {
                throw YabaiError.queryFailed("Enable tiling on this Space first")
            }
            _ = try request(["window", identifier, "--toggle", "float"])
        case .toggleSplit:
            guard state.isTiled(window) else { throw YabaiError.queryFailed("Window is not tiled") }
            _ = try request(["window", identifier, "--toggle", "split"])
        default:
            let delta: CGPoint
            let resizing: Bool
            switch command {
            case .moveLeft: delta = CGPoint(x: -40, y: 0); resizing = false
            case .moveRight: delta = CGPoint(x: 40, y: 0); resizing = false
            case .moveUp: delta = CGPoint(x: 0, y: -40); resizing = false
            case .moveDown: delta = CGPoint(x: 0, y: 40); resizing = false
            case .wider: delta = CGPoint(x: 40, y: 0); resizing = true
            case .narrower: delta = CGPoint(x: -40, y: 0); resizing = true
            case .taller: delta = CGPoint(x: 0, y: 40); resizing = true
            case .shorter: delta = CGPoint(x: 0, y: -40); resizing = true
            default: return
            }
            if !resizing && !state.isFree(window) {
                throw YabaiError.queryFailed("Use edge dragging to move tiled windows")
            }
            try apply(WindowDrag(window: window, snapshot: state, start: .zero, resizing: resizing, pointer: delta))
        }
    }
}

final class WindowHandlingController {
    private let queue = DispatchQueue(label: "YabaiSpaces.window-handling")
    private let backend = WindowHandlingBackend()
    private var snapshot = HandlingSnapshot()
    private var refreshing = false
    private var timer: Timer?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var drag: WindowDrag?
    private var consumedButton: CGEventType?
    private var cancelled = false
    private var overlay: NSPanel?
    private var enabled = !UserDefaults.standard.bool(forKey: "windowHandlingDisabled")
    var isBlocked: () -> Bool = { false }

    func start() {
        guard tap == nil else { return }
        let events: [CGEventType] = [.leftMouseDown, .leftMouseDragged, .leftMouseUp,
                                     .rightMouseDown, .rightMouseDragged, .rightMouseUp, .keyDown]
        let mask = events.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let created = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                              options: .defaultTap, eventsOfInterest: mask,
                                              callback: { _, type, event, context in
            guard let context else { return Unmanaged.passUnretained(event) }
            return Unmanaged<WindowHandlingController>.fromOpaque(context).takeUnretainedValue()
                .handle(type: type, event: event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            NSLog("[YabaiSpaces] Window handling unavailable: event tap permission missing")
            return
        }
        tap = created
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
        timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(timer!, forMode: .common)
        refresh()
        NSLog("[YabaiSpaces] Window handling listener installed (Control-Option drag)")
    }

    func execute(_ command: WindowHandlingCommand) {
        cancel()
        if command == .enable || command == .disable {
            enabled = command == .enable
            UserDefaults.standard.set(!enabled, forKey: "windowHandlingDisabled")
            if enabled { start(); refresh() }
            return
        }
        queue.async {
            do {
                try self.backend.execute(command)
                NSLog("[YabaiSpaces] \(command.rawValue): applied")
            } catch { NSLog("[YabaiSpaces] \(command.rawValue): \(error.localizedDescription)") }
            DispatchQueue.main.async { self.refresh() }
        }
    }

    func cancel() {
        cancelled = true
        drag = nil
        overlay?.orderOut(nil)
    }

    private func refresh() {
        guard enabled, !refreshing else { return }
        refreshing = true
        queue.async {
            let result = (try? self.backend.snapshot()) ?? HandlingSnapshot()
            DispatchQueue.main.async {
                self.snapshot = result
                self.refreshing = false
            }
        }
    }

    private func frontWindow(at point: CGPoint) -> UInt64? {
        guard let records = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { return nil }
        for record in records {
            if record[kCGWindowNumber as String] as? Int == overlay?.windowNumber { continue }
            guard let bounds = record[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds), frame.contains(point),
                  (record[kCGWindowAlpha as String] as? Double ?? 1) > 0 else { continue }
            return record[kCGWindowNumber as String] as? UInt64
        }
        return nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            cancel()
            consumedButton = nil
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown {
            if event.getIntegerValueField(.keyboardEventKeycode) == 53 { cancel() }
            return Unmanaged.passUnretained(event)
        }
        if type == .leftMouseDown || type == .rightMouseDown {
            guard consumedButton == nil, enabled, !isBlocked(),
                  event.flags.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift, .maskSecondaryFn])
                    == [.maskControl, .maskAlternate],
                  ProcessInfo.processInfo.systemUptime - snapshot.capturedAt < 1,
                  let identifier = frontWindow(at: event.location),
                  let window = snapshot.windows.first(where: { $0.id == identifier }),
                  snapshot.isFree(window) || snapshot.isTiled(window),
                  type != .rightMouseDown || window.resizable else { return Unmanaged.passUnretained(event) }
            cancelled = false
            consumedButton = type
            drag = WindowDrag(window: window, snapshot: snapshot, start: event.location,
                              resizing: type == .rightMouseDown, pointer: event.location)
            return nil
        }
        guard let button = consumedButton else { return Unmanaged.passUnretained(event) }
        let isRelease = type == (button == .leftMouseDown ? .leftMouseUp : .rightMouseUp)
        let isDrag = type == (button == .leftMouseDown ? .leftMouseDragged : .rightMouseDragged)
        guard isRelease || isDrag else { return Unmanaged.passUnretained(event) }
        if isBlocked() { cancel() }
        drag?.pointer = event.location
        if isRelease {
            if let target = drag?.target, frontWindow(at: event.location) != target.windowID { cancel() }
            let completed = cancelled ? nil : drag
            cancel()
            consumedButton = nil
            if let completed {
                queue.async {
                    do {
                        try self.backend.apply(completed)
                        NSLog("[YabaiSpaces] Window drag completed for \(completed.window.id)")
                    } catch { NSLog("[YabaiSpaces] Window drag: \(error.localizedDescription)") }
                    DispatchQueue.main.async { self.refresh() }
                }
            }
        } else {
            showPreview(drag?.preview)
        }
        return nil
    }

    private func showPreview(_ frame: CGRect?) {
        guard let frame, let primary = NSScreen.screens.first else { overlay?.orderOut(nil); return }
        if overlay == nil {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.25)
            panel.ignoresMouseEvents = true
            panel.hasShadow = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
            panel.sharingType = .none
            overlay = panel
        }
        overlay?.setFrame(CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY,
                                width: frame.width, height: frame.height), display: true)
        overlay?.orderFrontRegardless()
    }

    deinit {
        timer?.invalidate()
        if let tap { CFMachPortInvalidate(tap) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
    }
}
