//
//  YabaiAppDelegate.swift
//  YabaiIndicator
//
//  Created by Max Zhao on 26/12/2021.
//

import SwiftUI
import Socket
import Combine
import Carbon
import ApplicationServices

// Custom panel that can become key window even with nonactivating style
class KeyPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
}

// Global hotkey using Carbon
class GlobalHotkey {
    private var hotkeyRef: EventHotKeyRef?

    func register(keyCode: UInt32, modifiers: UInt32, id: UInt32 = 1) -> Bool {
        let hotkeyID = EventHotKeyID(signature: OSType(0x59494920), id: id) // 'YI ' + id

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status != noErr {
            NSLog("Failed to register hotkey \(id): \(status)")
            return false
        }

        NSLog("Registered hotkey \(id): keyCode=\(keyCode), modifiers=\(modifiers)")
        return true
    }
}

// Global modifier key hotkey using CGEventTap
// Required for modifier keys like Shift, which don't work with Carbon RegisterEventHotKey
// Behavior: Quick tap (press & release quickly) shows panel; hold or typing does not
class ModifierKeyHotkey {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let handler: () -> Void
    private let targetKeyCode: UInt32
    private var longHoldTimer: DispatchWorkItem?
    private let longHoldThreshold: TimeInterval = 0.25  // 250ms = boundary between tap and hold
    private var isTyping = false  // Tracks if another key was pressed while Shift held
    private var isLongHold = false  // Tracks if Shift was held past threshold
    private var wasPressed = false  // Track Shift key state

    init(keyCode: UInt32, handler: @escaping () -> Void) {
        self.targetKeyCode = keyCode
        self.handler = handler
        setupEventTap()
    }

    private func setupEventTap() {
        // Listen to both flagsChanged AND keyDown events
        let flagsChangedMask = (1 << CGEventType.flagsChanged.rawValue)
        let keyDownMask = (1 << CGEventType.keyDown.rawValue)
        let eventMask = flagsChangedMask | keyDownMask

        let userData = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if let refcon = refcon {
                    let hotkey = Unmanaged<ModifierKeyHotkey>.fromOpaque(refcon).takeUnretainedValue()
                    return hotkey.handleEvent(proxy: proxy, type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: userData
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func cancelLongHoldTimer() {
        longHoldTimer?.cancel()
        longHoldTimer = nil
    }

    private func scheduleLongHoldTimer() {
        // Cancel any existing timer
        cancelLongHoldTimer()

        // Schedule timer to mark this as a long hold
        let workItem = DispatchWorkItem { [weak self] in
            self?.isLongHold = true
            self?.longHoldTimer = nil
        }
        longHoldTimer = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + longHoldThreshold, execute: workItem)
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .flagsChanged {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // Check if this is the target key (Right Shift = 60)
            if keyCode == Int64(targetKeyCode) {
                let shiftPressed = flags.contains(.maskShift)

                // On press: start long hold timer, reset state
                if shiftPressed && !wasPressed {
                    isTyping = false
                    isLongHold = false
                    scheduleLongHoldTimer()
                    wasPressed = true
                }

                // On release: show panel only if quick tap (not long hold, not typing)
                if !shiftPressed && wasPressed {
                    cancelLongHoldTimer()
                    if !isLongHold && !isTyping {
                        handler()
                    }
                    // Reset state
                    wasPressed = false
                }
            }
        } else if type == .keyDown {
            // If Shift is pressed and another key is pressed, mark as typing
            if wasPressed {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                // Ignore modifier key codes (56-63 are modifiers on macOS)
                let isModifier = (keyCode >= 56 && keyCode <= 63)
                if !isModifier {
                    isTyping = true
                }
            }
        }
        return Unmanaged.passUnretained(event)
    }

    deinit {
        cancelLongHoldTimer()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
    }
}

// Global hotkey event dispatcher - single handler for all hotkeys
class HotkeyEventDispatcher {
    static let shared = HotkeyEventDispatcher()
    private var handlers: [UInt32: () -> Void] = [:]
    private var eventHandlerRef: EventHandlerRef?

    private init() {
        setupEventHandler()
    }

    func setHandler(id: UInt32, handler: @escaping () -> Void) {
        handlers[id] = handler
    }

    private func setupEventHandler() {
        var mySpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            if let userData = userData {
                let dispatcher = Unmanaged<HotkeyEventDispatcher>.fromOpaque(userData).takeUnretainedValue()
                return dispatcher.handleEvent(theEvent)
            }
            return noErr
        }, 1, &mySpec, selfPtr, &eventHandlerRef)
    }

    private func handleEvent(_ event: EventRef?) -> OSStatus {
        guard let event = event else { return noErr }

        var hotkeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )

        if status == noErr {
            NSLog("Hotkey pressed: id=\(hotkeyID.id)")
            if let handler = handlers[hotkeyID.id] {
                handler()
            }
        }

        return noErr
    }
}

extension UserDefaults {
    @objc dynamic var showDisplaySeparator: Bool {
        return bool(forKey: "showDisplaySeparator")
    }
    
    @objc dynamic var showCurrentSpaceOnly: Bool {
        return bool(forKey: "showCurrentSpaceOnly")
    }
    
    @objc dynamic var buttonStyle: ButtonStyle {
        get {
            return ButtonStyle(rawValue: self.integer(forKey: "buttonStyle")) ?? ButtonStyle.numeric
        }
    }
}

class YabaiAppDelegate: NSObject, NSApplicationDelegate {
    var floatingPanel: NSPanel?
    var settingsWindow: NSWindow?
    var statusBarItem: NSStatusItem?
    var application: NSApplication = NSApplication.shared
    var spaceModel = SpaceModel()

    // Track last active space for thumbnail capture
    private var lastActiveSpaceId: UInt64 = 0

    let statusBarHeight: CGFloat = 22
    let itemWidth: CGFloat = 30
    let panelPadding: CGFloat = 8

    // Panel layout - scale calculated from screen height
    var panelLayout: PanelLayout = PanelLayout()

    var sinks: [AnyCancellable?] = []
    var receiverQueue = DispatchQueue(label: "yabai-indicator.socket.receiver")
    var eventMonitors: [Any] = []
    var globalHotkey: GlobalHotkey?
    var centeredHotkey: GlobalHotkey?
    var rightShiftHotkey: ModifierKeyHotkey?

    @objc
    func onSpaceChanged(_ notification: Notification) {
        onSpaceRefresh()
    }
    
    @objc
    func onDisplayChanged(_ notification: Notification) {
        onSpaceRefresh()
    }
    
    func refreshData() {
        // log("Refreshing")
        receiverQueue.async {
            self.onSpaceRefresh()
            self.onWindowRefresh()
        }
    }
    
    func onSpaceRefresh() {
        let displays = gNativeClient.queryDisplays()
        let spaceElems = gNativeClient.querySpaces()

        // NOTE: Thumbnail capture is now only done in switchSpace() to avoid duplicates
        // onSpaceRefresh() is called AFTER space switch, so we'd be capturing wrong state

        // NOTE: Don't clear cache on every refresh - thumbnails should persist
        // Only clear when spaces are actually reconfigured (not just switching)

        DispatchQueue.main.async {
            self.spaceModel.displays = displays
            self.spaceModel.spaces = spaceElems
        }
    }

    // Capture thumbnail for a specific space (call when space becomes inactive)
    // Returns immediately after starting async capture
    func captureThumbnail(for space: Space) {
        NSLog("captureThumbnail START: space \(space.index) (yabaiIndex: \(space.yabaiIndex), spaceId: \(space.spaceid), display \(space.display))")

        let displays = gNativeClient.queryDisplays()
        guard space.display - 1 >= 0, space.display - 1 < displays.count else {
            NSLog("  ERROR: invalid display index \(space.display - 1), displays.count: \(displays.count)")
            return
        }
        let display = displays[space.display - 1]
        NSLog("  Display frame: \(display.frame)")

        // CRITICAL: Query windows synchronously BEFORE space switch
        let windows = gYabaiClient.queryWindows()
        let spaceWindows = windows.filter { $0.spaceIndex == space.yabaiIndex }

        NSLog("  Total windows from yabai: \(windows.count)")
        NSLog("  Windows filtered for yabaiIndex \(space.yabaiIndex): \(spaceWindows.count)")
        for w in spaceWindows.prefix(5) {  // Log first 5 windows
            NSLog("    - window: \(w.title.prefix(30)) [id: \(w.id), space: \(w.spaceIndex), display: \(w.displayIndex)]")
        }

        // Capture SYNCHRONOUSLY so cache is updated before we return
        // This ensures the new space's view will find the cached thumbnail
        // Calculate thumbnail size proportional to display aspect ratio
        let baseHeight: CGFloat = 20 * panelLayout.scale
        let aspect = display.frame.width / display.frame.height
        let targetSize = CGSize(width: baseHeight * aspect, height: baseHeight)

        if let thumbnail = gPrivateWindowCapture.captureSpace(
            windows: spaceWindows,
            display: display,
            targetSize: targetSize
        ) {
            NSLog("captureThumbnail DONE: caching for spaceId \(space.spaceid), size: \(thumbnail.size)")
            gThumbnailCache.set(spaceId: space.spaceid, image: thumbnail)
        } else {
            NSLog("captureThumbnail FAILED: for spaceId: \(space.spaceid)")
        }
    }

    func onWindowRefresh() {
        let buttonStyle = UserDefaults.standard.buttonStyle
        if buttonStyle == .windows || buttonStyle == .thumbnail {
            let windows = gYabaiClient.queryWindows()
            DispatchQueue.main.async {
                self.spaceModel.windows = windows
            }
        }
    }
    
    func refreshBar() {
        let showDisplaySeparator = UserDefaults.standard.bool(forKey: "showDisplaySeparator")
        let showCurrentSpaceOnly = UserDefaults.standard.bool(forKey: "showCurrentSpaceOnly")

        let numButtons = showCurrentSpaceOnly ?  spaceModel.displays.count : spaceModel.spaces.count

        var newWidth = CGFloat(numButtons) * itemWidth
        if !showDisplaySeparator {
            newWidth -= CGFloat((spaceModel.displays.count - 1) * 10)
        }
        newWidth += panelPadding * 2

        // Update status bar width (floating panel has fixed size)
        statusBarItem?.button?.frame.size.width = newWidth
        statusBarItem?.button?.subviews[0].frame.size.width = newWidth
    }

    func createFloatingPanel() {
        let panelSize = panelLayout.panelSize
        let panel = KeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelSize.width, height: panelSize.height),
            styleMask: [.nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = false

        let hostingView = NSHostingView(rootView: PanelContentView().environmentObject(spaceModel))
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 6
        hostingView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        panel.contentView = hostingView

        floatingPanel = panel
    }

    func showPanel(at mouseLocation: NSPoint) {
        guard let panel = floatingPanel else { return }

        let panelSize = panel.frame.size

        // Find active space and calculate its position in the grid
        let showDisplaySeparator = UserDefaults.standard.bool(forKey: "showDisplaySeparator")
        let showCurrentSpaceOnly = UserDefaults.standard.bool(forKey: "showCurrentSpaceOnly")

        var activeGridIndex = 0
        var currentIndex = 0
        var lastDisplay = 0

        for space in spaceModel.spaces {
            // Add divider before new display (if enabled)
            if lastDisplay > 0 && space.display != lastDisplay && showDisplaySeparator {
                currentIndex += 1
            }

            // Check if this space should be shown
            if space.visible || !showCurrentSpaceOnly {
                if space.active {
                    activeGridIndex = currentIndex
                    break
                }
                currentIndex += 1
            }

            lastDisplay = space.display
        }

        // Grid layout from PanelLayout
        let columns = panelLayout.columnCount
        let columnWidth = panelLayout.columnWidth
        let columnSpacing = panelLayout.columnSpacing
        let buttonHeight = panelLayout.buttonHeight
        let rowSpacing = panelLayout.rowSpacing
        let padding = panelLayout.padding

        let row = activeGridIndex / columns
        let col = activeGridIndex % columns

        // Calculate center of the active space button within the panel
        let buttonCenterX = padding + CGFloat(col) * (columnWidth + columnSpacing) + columnWidth / 2
        let buttonCenterY = panelSize.height - (padding + CGFloat(row) * (buttonHeight + rowSpacing) + buttonHeight / 2)

        // Position panel so mouse is over the active space button
        var newX = mouseLocation.x - buttonCenterX
        var newY = mouseLocation.y - buttonCenterY

        // Keep panel on screen - get the screen containing the mouse
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let panelFrame = NSRect(x: newX, y: newY, width: panelSize.width, height: panelSize.height)

            // Adjust horizontally if off screen
            if panelFrame.minX < visibleFrame.minX {
                newX = visibleFrame.minX
            } else if panelFrame.maxX > visibleFrame.maxX {
                newX = visibleFrame.maxX - panelSize.width
            }

            // Adjust vertically if off screen
            if panelFrame.minY < visibleFrame.minY {
                newY = visibleFrame.minY
            } else if panelFrame.maxY > visibleFrame.maxY {
                newY = visibleFrame.maxY - panelSize.height
            }
        }

        panel.setFrameOrigin(NSPoint(x: newX, y: newY))

        // Reset keyboard selection to active space
        resetPanelSelection()

        panel.orderFrontRegardless()
        panel.makeKey()

        // Don't activate the app - it interferes with other windows like Settings
        // NSApp.activate(ignoringOtherApps: true)

        // Start monitoring for clicks outside
        startClickOutsideMonitor()
    }

    func showPanelCentered() {
        guard let panel = floatingPanel else { return }
        guard let screen = NSScreen.main else { return }

        let panelSize = panel.frame.size
        let visibleFrame = screen.visibleFrame

        // Center panel in visible frame
        let x = visibleFrame.midX - panelSize.width / 2
        let y = visibleFrame.midY - panelSize.height / 2

        panel.setFrameOrigin(NSPoint(x: x, y: y))

        resetPanelSelection()
        panel.orderFrontRegardless()
        panel.makeKey()

        startClickOutsideMonitor()
    }

    func hidePanel() {
        floatingPanel?.orderOut(nil)
        stopClickOutsideMonitor()
    }

    func startClickOutsideMonitor() {
        NSLog("startClickOutsideMonitor: setting up event monitors")
        stopClickOutsideMonitor() // Remove any existing monitor

        // Local monitor for clicks within our app - ONLY for panel interactions
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            // Only intercept clicks if panel is visible
            guard let panel = self?.floatingPanel, panel.isVisible else {
                return event  // Let all other clicks pass through normally
            }

            NSLog("Local click (panel visible): button=\(event.buttonNumber), location=\(event.locationInWindow)")
            // Right-click (button=1 on macOS) shows menu
            if event.buttonNumber == 1 {
                NSLog("Right-click detected, showing menu")
                self?.showPanelMenu(at: event.locationInWindow)
                return nil  // Consume right-click
            }
            // Left-click: let the click pass through first, then hide
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.hidePanel()
            }
            return event
        }

        // Local monitor for Escape key to hide panel - ONLY when panel is visible
        let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Only handle keys if panel is visible
            guard let panel = self?.floatingPanel, panel.isVisible else {
                return event  // Let keys pass through normally
            }
            NSLog("Local keyDown: keyCode=\(event.keyCode), panel.visible=\(panel.isVisible)")

            // Handle navigation keys for panel
            let handled = self?.handlePanelKeyEvent(event) ?? false
            if handled {
                return nil  // Consume the event
            }

            return event
        }

        // Global monitor for Escape key - needed because panel is non-activating
        let globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            NSLog("Global keyDown: keyCode=\(event.keyCode)")
            if event.keyCode == 53 {  // 53 = Escape
                NSLog("Escape pressed (global), hiding panel")
                self?.hidePanel()
            }
        }

        // Global monitor for clicks in other apps - hide on any click
        // Note: This may cause benign Mach port warnings in logs when accessing events from other processes
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.hidePanel()
        }

        if let local = localMonitor { eventMonitors.append(local) }
        if let key = keyMonitor { eventMonitors.append(key) }
        if let globalKey = globalKeyMonitor { eventMonitors.append(globalKey) }
        if let global = globalMonitor { eventMonitors.append(global) }
        NSLog("startClickOutsideMonitor: \(eventMonitors.count) monitors registered")
    }

    func showPanelMenu(at location: NSPoint) {
        let menu = NSMenu()

        let prefsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ""
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        let toggleItem = NSMenuItem(
            title: "Toggle Button Style",
            action: #selector(toggleButtonStyle),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit YabaiIndicator",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        // Show menu at the click location
        if let panel = floatingPanel {
            menu.popUp(positioning: nil, at: location, in: panel.contentView)
        }
    }

    @objc
    func toggleButtonStyle() {
        let currentStyle = UserDefaults.standard.buttonStyle
        let newStyle: ButtonStyle
        switch currentStyle {
        case .numeric: newStyle = .windows
        case .windows: newStyle = .thumbnail
        case .thumbnail: newStyle = .numeric
        }
        UserDefaults.standard.set(newStyle.rawValue, forKey: "buttonStyle")
    }

    // MARK: - Panel Keyboard Navigation

    // Notification names for panel navigation
    static let panelNavigationNotification = Notification.Name("panelNavigation")
    private var panelSelectedIndex: Int? = nil

    func resetPanelSelection() {
        // Reset selection to active space and post notification
        let spaces = spaceModel.spaces.filter { $0.type == .standard }
        if let activeIndex = spaces.firstIndex(where: { $0.active }) {
            panelSelectedIndex = activeIndex
            NotificationCenter.default.post(
                name: YabaiAppDelegate.panelNavigationNotification,
                object: nil,
                userInfo: ["selectedIndex": activeIndex]
            )
        } else {
            panelSelectedIndex = nil
            NotificationCenter.default.post(
                name: YabaiAppDelegate.panelNavigationNotification,
                object: nil,
                userInfo: ["selectedIndex": -1]  // -1 means clear selection
            )
        }
    }

    func handlePanelKeyEvent(_ event: NSEvent) -> Bool {
        let spaces = spaceModel.spaces.filter { $0.type == .standard }
        guard !spaces.isEmpty else { return false }

        let panelLayout = PanelLayout(from: UserDefaults.standard)
        let columnCount = panelLayout.columns.count
        let maxIndex = spaces.count - 1

        // Initialize selection to active space if none selected
        var currentIndex = panelSelectedIndex ?? {
            if let activeSpace = spaces.firstIndex(where: { $0.active }) {
                return activeSpace
            }
            return 0
        }()

        var newIndex = currentIndex

        switch event.keyCode {
        case 126: // Up Arrow
            if currentIndex >= columnCount {
                newIndex = currentIndex - columnCount
            } else {
                // Wrap to bottom row, same column
                let currentCol = currentIndex % columnCount
                // Find bottom row position for this column
                var bottomRowColIndex = currentCol
                while bottomRowColIndex + columnCount <= maxIndex {
                    bottomRowColIndex += columnCount
                }
                newIndex = bottomRowColIndex
            }
        case 125: // Down Arrow
            let nextRow = currentIndex + columnCount
            if nextRow <= maxIndex {
                newIndex = nextRow
            } else {
                // Wrap to top row, same column
                let currentCol = currentIndex % columnCount
                newIndex = currentCol
            }
        case 123: // Left Arrow
            let currentRow = currentIndex / columnCount
            if currentIndex % columnCount != 0 {
                newIndex = currentIndex - 1
            } else {
                // Wrap to end of same row
                let rowEnd = min((currentRow + 1) * columnCount - 1, maxIndex)
                newIndex = rowEnd
            }
        case 124: // Right Arrow
            let currentRow = currentIndex / columnCount
            let nextIndex = currentIndex + 1
            let rowEnd = min((currentRow + 1) * columnCount - 1, maxIndex)
            if nextIndex <= rowEnd {
                newIndex = nextIndex
            } else {
                // Wrap to start of same row
                let rowStart = currentRow * columnCount
                newIndex = rowStart
            }
        case 36, 49: // Return or Space
            // Always hide panel - if different space selected, switch to it first
            let selectedSpace = spaces[currentIndex]
            if !selectedSpace.active && selectedSpace.yabaiIndex > 0 {
                switchSpace(to: selectedSpace.yabaiIndex)
            }
            // Always hide panel after selection
            hidePanel()
            return true
        case 53: // Escape
            NSLog("Escape pressed, hiding panel")
            hidePanel()
            return true
        default:
            return false
        }

        panelSelectedIndex = newIndex

        // Post notification for SwiftUI to update selection
        NotificationCenter.default.post(
            name: YabaiAppDelegate.panelNavigationNotification,
            object: nil,
            userInfo: ["selectedIndex": newIndex]
        )

        return true
    }

    func stopClickOutsideMonitor() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
    }

    func setupGlobalHotkeys() {
        // Cmd+Option+Space hotkey - panel at mouse position
        let hotkey = GlobalHotkey()
        // KeyCode 49 = Space, modifiers: cmdKey = 256 (0x100), optionKey = 2048 (0x800)
        let modifiers: UInt32 = UInt32(cmdKey | optionKey)
        if hotkey.register(keyCode: 49, modifiers: modifiers, id: 1) {
            globalHotkey = hotkey
            HotkeyEventDispatcher.shared.setHandler(id: 1) { [weak self] in
                self?.togglePanel(at: NSEvent.mouseLocation)
            }
        }

        // Cmd+Option+Ctrl+Space hotkey - centered panel
        let centeredHotkey = GlobalHotkey()
        // KeyCode 49 = Space, modifiers: cmdKey | optionKey | controlKey
        let centeredModifiers: UInt32 = UInt32(cmdKey | optionKey | controlKey)
        if centeredHotkey.register(keyCode: 49, modifiers: centeredModifiers, id: 2) {
            self.centeredHotkey = centeredHotkey
            HotkeyEventDispatcher.shared.setHandler(id: 2) { [weak self] in
                if let panel = self?.floatingPanel, panel.isVisible {
                    self?.hidePanel()
                } else {
                    self?.showPanelCentered()
                }
            }
        }

        // Right Shift hotkey - centered panel
        // Uses CGEventTap because Carbon RegisterEventHotKey doesn't work for modifier keys
        // KeyCode 60 = Right Shift (based on HIToolbox/Events.h)
        rightShiftHotkey = ModifierKeyHotkey(keyCode: 60) { [weak self] in
            if let panel = self?.floatingPanel, panel.isVisible {
                self?.hidePanel()
            } else {
                self?.showPanelCentered()
            }
        }
    }

    func togglePanel(at mouseLocation: NSPoint) {
        guard let panel = floatingPanel else { return }

        if panel.isVisible {
            hidePanel()
        } else {
            showPanel(at: mouseLocation)
        }
    }
    
    func socketServer() async {
        do {
            let socket = try Socket.create(family: .unix, type: .stream, proto: .unix)
            try socket.listen(on: "/tmp/yabai-indicator.socket")
            while true {
                let conn = try socket.acceptClientConnection()
                let msg = try conn.readString()?.trimmingCharacters(in: .whitespacesAndNewlines)
                conn.close()
                // log("Received message: \(msg!).")
                if msg == "refresh" {
                    self.refreshData()
                } else if msg == "refresh spaces" {
                    Task { @MainActor in
                        self.onSpaceRefresh()
                    }
                } else if msg == "refresh windows" {
                    Task { @MainActor in
                        self.onWindowRefresh()
                    }
                }
            }
        } catch {
            NSLog("SocketServer Error: \(error)")
        }
        NSLog("SocketServer Ended")
    }
    
    @objc
    func quit() {
        NSApp.terminate(self)
    }
    
    @objc
    func openPreferences() {
        NSApp.activate(ignoringOtherApps: true)

        // Reuse existing window if it's still valid
        if let window = settingsWindow, window.isVisible {
            window.orderFrontRegardless()
            return
        }

        // Clear old reference and create new window
        settingsWindow = nil

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 375, height: 150),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "YabaiIndicator Settings"
        window.center()
        window.isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: SettingsView())
        window.contentView = hostingView

        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }
    
    func createStatusItemView() -> NSView {
        let view = NSHostingView(
            rootView: ContentView().environmentObject(spaceModel)
        )
        view.setFrameSize(NSSize(width: 0, height: statusBarHeight))
        return view
    }
    
    func createMenu() -> NSMenu {
        let statusBarMenu = NSMenu()
        statusBarMenu.addItem(
            withTitle: "Preferences",
            action: #selector(openPreferences),
            keyEquivalent: "")
        statusBarMenu.addItem(NSMenuItem.separator())

        statusBarMenu.addItem(
            withTitle: "Quit",
            action: #selector(quit),
            keyEquivalent: "")
        return statusBarMenu
    }
    
    func registerObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.onSpaceChanged(_:)), name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(self.onDisplayChanged(_:)), name: Notification.Name("NSWorkspaceActiveDisplayDidChangeNotification"), object: nil)
    }

    // Switch spaces
    func switchSpace(to yabaiIndex: Int) {
        // Perform the space switch
        NSLog("switchSpace: calling focusSpace(\(yabaiIndex))")
        gYabaiClient.focusSpace(index: yabaiIndex)

        // Hide panel after switch
        hidePanel()

        // Capture thumbnail of the NEW space after switching (panel is now hidden)
        // Small delay to ensure Yabai has completed the switch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            // Query spaces SYNCHRONOUSLY to get updated active flags
            // (refreshData is async and won't complete in time)
            let spaceElems = gNativeClient.querySpaces()
            DispatchQueue.main.async {
                self.spaceModel.spaces = spaceElems
            }

            // Debug: log all active spaces
            let activeSpaces = spaceElems.filter { $0.active }
            NSLog("switchSpace async: active spaces after switch: \(activeSpaces.map { "[index:\($0.index), yabaiIndex:\($0.yabaiIndex), type:\($0.type)]" }.joined(separator: ", "))")

            // Find space by yabaiIndex - capture even if 'active' flag isn't set correctly
            // (macOS sometimes misreports active status, especially for spaces with empty UUIDs)
            if let newActive = spaceElems.first(where: { $0.yabaiIndex == yabaiIndex }) {
                NSLog("switchSpace: capturing thumbnail for space \(newActive.index) (yabaiIndex: \(newActive.yabaiIndex), active: \(newActive.active))")
                self.captureThumbnail(for: newActive)
            } else {
                NSLog("switchSpace: WARNING - no space found with yabaiIndex \(yabaiIndex)")
                // Log all spaces with their yabaiIndex for debugging
                NSLog("switchSpace: all spaces: \(spaceElems.map { "[index:\($0.index), yabaiIndex:\($0.yabaiIndex), active:\($0.active)]" }.joined(separator: ", "))")
            }
        }
    }

    func refreshButtonStyle() {
        // PanelContentView uses @AppStorage so it updates automatically - no need to replace contentView

        // Update status bar - show current space(s)
        for subView in statusBarItem?.button?.subviews ?? [] {
            subView.removeFromSuperview()
        }

        // Create a simple view showing current space for status bar
        let statusBarView = NSHostingView(rootView: StatusBarView().environmentObject(spaceModel))
        statusBarView.setFrameSize(NSSize(width: 60, height: statusBarHeight))
        statusBarItem?.button?.addSubview(statusBarView)

        // Always clear cache when button style changes - thumbnails will be captured on space switch
        gThumbnailCache.clear()

        refreshData()
    }

    func updatePanelLayout() {
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        let baseScale = PanelLayout.scale(from: screenHeight)
        // Always use 3x scale for floating panel
        panelLayout = PanelLayout(scale: baseScale * 3)

        // Clear thumbnail cache so new size is used
        gThumbnailCache.clear()

        // Save to UserDefaults so PanelContentView can read it
        panelLayout.save()

        NSLog("PanelLayout updated: scale=\(panelLayout.scale), baseScale=\(baseScale)")

        // Always create or recreate panel with new size
        if floatingPanel != nil {
            floatingPanel?.close()
        }
        createFloatingPanel()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let prefs = Bundle.main.path(forResource: "defaults", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: prefs) as? [String : Any] {
          UserDefaults.standard.register(defaults: dict)
        }

        sinks = [
            spaceModel.objectWillChange.sink{_ in self.refreshBar()},
            UserDefaults.standard.publisher(for: \.showDisplaySeparator).sink {_ in self.refreshBar()},
            UserDefaults.standard.publisher(for: \.showCurrentSpaceOnly).sink {_ in self.refreshBar()},
            UserDefaults.standard.publisher(for: \.buttonStyle).sink {_ in self.refreshButtonStyle()}

        ]

        // Calculate panel layout FIRST (before any views are created)
        // This ensures UserDefaults has the correct scale before views read it
        updatePanelLayout()

        // Run socket server in background - suppress Sendable warning as this is intentional
        Task.detached(priority: .background) { [weak self] in
            await self?.socketServer()
        }

        // Create status bar item (for menu access)
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Set up global hotkeys
        setupGlobalHotkeys()

        refreshButtonStyle()
        registerObservers()
    }
}
