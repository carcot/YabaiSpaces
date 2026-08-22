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
import OSLog

// Custom panel that can become key window even with nonactivating style
class KeyPanel: NSPanel {
    override var canBecomeKey: Bool {
        return true
    }
}

// Policy for cursor restoration when panel closes
enum CursorRestorationPolicy {
    case restore    // Restore cursor to saved position when panel closes
    case skip       // Don't restore cursor (user clicked elsewhere or switched spaces)
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
            return ButtonStyle(rawValue: self.integer(forKey: "buttonStyle")) ?? .windows
        }
    }

    @objc dynamic var gridPosition: GridPosition {
        get {
            return GridPosition(rawValue: self.integer(forKey: "gridPosition")) ?? .atCursor
        }
    }

    @objc dynamic var cursorPosition: CursorPosition {
        get {
            return CursorPosition(rawValue: self.integer(forKey: "cursorPosition")) ?? .onThumbnail
        }
    }

    @objc dynamic var showMenubar: Bool {
        return bool(forKey: "showMenubar")
    }

    @objc dynamic var showPanel: Bool {
        return bool(forKey: "showPanel")
    }

    @objc dynamic var panelColumns: Int {
        return integer(forKey: "panelColumns")
    }

    @objc dynamic var panelRows: Int {
        return integer(forKey: "panelRows")
    }
}

class YabaiAppDelegate: NSObject, NSApplicationDelegate, PanelHotkeyDelegate {
    var settingsWindow: NSWindow?
    var statusBarItem: NSStatusItem?
    var application: NSApplication = NSApplication.shared
    var spaceModel = SpaceModel()

    // Panel manager
    private var panelManager: PanelManager!

    // MARK: PanelHotkeyDelegate

    var floatingPanel: NSPanel? {
        return panelManager?.panel
    }

    // Track last active space for thumbnail capture
    // (currently unused - reserved for future external switch capture implementation)
    private var lastActiveSpaceId: UInt64 = 0

    // Flag to prevent double-capture when we initiate the switch ourselves
    // (currently unused - reserved for future implementation)
    private var didCaptureBeforeSwitch = false

    // Ensure hotkeys are only set up once (Combine publisher may fire during init)
    private var hasSetupHotkeys = false

    let statusBarHeight: CGFloat = 22
    let panelPadding: CGFloat = 8

    // Panel layout - scale calculated from screen height
    var panelLayout: PanelLayout = PanelLayout()

    var sinks: [AnyCancellable?] = []
    var receiverQueue = DispatchQueue(label: "yabai-indicator.socket.receiver")

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

        DispatchQueue.main.async {
            self.spaceModel.displays = displays
            self.spaceModel.spaces = spaceElems
        }
    }

    // Capture thumbnail for a specific space (call when space becomes inactive)
    func captureThumbnail(for space: Space) {
        let displays = gNativeClient.queryDisplays()
        guard space.display - 1 >= 0, space.display - 1 < displays.count else {
            return
        }
        let display = displays[space.display - 1]

        // CRITICAL: Query windows synchronously BEFORE space switch
        let windows = gYabaiClient.queryWindows()
        let spaceWindows = windows.filter { $0.spaceIndex == space.yabaiIndex }

        // Calculate thumbnail size proportional to display aspect ratio
        let baseHeight: CGFloat = 20 * panelLayout.scale
        let aspect = display.frame.width / display.frame.height
        let targetSize = CGSize(width: baseHeight * aspect, height: baseHeight)

        if let data = gPrivateWindowCapture.captureSpace(
            windows: spaceWindows,
            display: display,
            targetSize: targetSize
        ) {
            gThumbnailCache.set(spaceId: space.spaceid, data: data)
        }
    }

    func onWindowRefresh() {
        // Always query windows for panel (hybrid preview needs window outlines)
        // regardless of menubar button style
        let windows = gYabaiClient.queryWindows()
        DispatchQueue.main.async {
            self.spaceModel.windows = windows
        }
    }
    
    func refreshBar() {
        let showDisplaySeparator = UserDefaults.standard.bool(forKey: "showDisplaySeparator")
        let showCurrentSpaceOnly = UserDefaults.standard.bool(forKey: "showCurrentSpaceOnly")
        let buttonStyle = UserDefaults.standard.buttonStyle

        // Calculate width based on actual button sizes (matches MenubarView rendering)
        // MenubarView uses scale 1.0, not the panel's 3x scale
        let menubarLayout = PanelLayout(scale: 1.0)
        let buttonSpacing: CGFloat = 4
        let menubarPadding: CGFloat = 2  // from MenubarView .padding(2)

        var contentWidth: CGFloat = 0
        var buttonCount = 0
        var lastDisplay = 0

        for space in spaceModel.spaces {
            // Add divider between displays if enabled
            if lastDisplay > 0 && space.display != lastDisplay {
                if showDisplaySeparator {
                    // Divider is a thin line - contributes minimal width
                    contentWidth += 1
                }
            }

            // Filter spaces based on showCurrentSpaceOnly
            if space.visible || !showCurrentSpaceOnly {
                switch space.type {
                case .standard:
                    if buttonStyle == .numeric {
                        // Numeric buttons: fixed width from menubar PanelLayout.imageSize.width
                        contentWidth += menubarLayout.imageSize.width
                    } else {
                        // Windows/thumbnail: width = baseImageHeight × aspect ratio
                        let displayIndex = space.display - 1
                        if displayIndex >= 0 && displayIndex < spaceModel.displays.count {
                            let display = spaceModel.displays[displayIndex]
                            let aspect = display.frame.width / display.frame.height
                            contentWidth += menubarLayout.baseImageHeight * aspect
                        } else {
                            // Fallback to numeric width if display data invalid
                            contentWidth += menubarLayout.imageSize.width
                        }
                    }
                case .fullscreen:
                    // Fullscreen buttons always use numeric style
                    contentWidth += menubarLayout.imageSize.width
                case .divider:
                    // Divider width handled above
                    break
                }
                buttonCount += 1
            }
            lastDisplay = space.display
        }

        // Add spacing between buttons
        if buttonCount > 0 {
            contentWidth += CGFloat(buttonCount - 1) * buttonSpacing
        }

        // Add menubar padding (2px on each side)
        let newWidth = contentWidth + menubarPadding * 2

        // Update status bar width (floating panel has fixed size)
        statusBarItem?.button?.frame.size.width = newWidth
        statusBarItem?.button?.subviews[0].frame.size.width = newWidth
    }

    // MARK: - Memory Logging

    func logMemoryUsage(context: String = "panel_open") {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }

        if result == KERN_SUCCESS {
            let mb = info.resident_size / 1024 / 1024
            NSLog("[YabaiSpaces] Memory usage: \(mb) MB (\(context))")
        }
    }

    func showPanel(at mouseLocation: NSPoint, modifiers: PanelModifiers = .none) {
        logMemoryUsage(context: "panel_open")

        // Capture current space thumbnail before showing panel
        if let currentSpace = spaceModel.spaces.first(where: { $0.active }) {
            captureThumbnail(for: currentSpace)
        }

        // Map CursorPosition to PanelModifiers
        let panelModifiers: PanelModifiers
        switch UserDefaults.standard.cursorPosition {
        case .stayPut:
            panelModifiers = .none
        case .centerGrid:
            panelModifiers = .moveCursorToGridCenter
        case .onThumbnail:
            panelModifiers = .moveCursorToPanel
        }

        panelManager.show(at: mouseLocation, modifiers: panelModifiers)
        resetPanelSelection()
    }

    func showPanelCentered(modifiers: PanelModifiers = .none) {
        logMemoryUsage(context: "panel_open_centered")

        let mouseLoc = NSEvent.mouseLocation

        // Capture current space thumbnail before showing panel
        if let currentSpace = spaceModel.spaces.first(where: { $0.active }) {
            captureThumbnail(for: currentSpace)
        }

        panelManager.show(at: mouseLoc, modifiers: modifiers)
        resetPanelSelection()
    }

    func hidePanel() {
        panelManager?.hide()
    }

    func confirmPanelSelection() {
        guard floatingPanel?.isVisible == true else { return }
        let spaces = spaceModel.spaces.filter { $0.type == .standard }
        let selectedIndex = panelSelectedIndex ?? spaces.firstIndex(where: { $0.active }) ?? 0
        if spaces.indices.contains(selectedIndex) {
            let selectedSpace = spaces[selectedIndex]
            if !selectedSpace.active && selectedSpace.yabaiIndex > 0 {
                switchSpace(to: selectedSpace.yabaiIndex)
            }
        }
        hidePanel()
    }

    @objc
    func toggleButtonStyle() {
        let currentStyle = UserDefaults.standard.buttonStyle
        let newStyle: ButtonStyle
        switch currentStyle {
        case .numeric: newStyle = .windows
        case .windows: newStyle = .numeric
        default: newStyle = .numeric
        }
        UserDefaults.standard.set(newStyle.rawValue, forKey: "buttonStyle")
    }

    // MARK: - Panel Keyboard Navigation

    // Notification names for panel navigation
    static let panelNavigationNotification = Notification.Name("panelNavigation")
    private var panelSelectedIndex: Int? = nil

    // MARK: PanelHotkeyDelegate - Keyboard Event Handling

    func handleKeyEvent(_ event: NSEvent) -> Bool {
        return handlePanelKeyEvent(event)
    }

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
        let currentIndex = panelSelectedIndex ?? {
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
            confirmPanelSelection()
            return true
        case 53: // Escape
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

    func setupDefaultHotkeys() {
        // Idempotent guard - only set up hotkeys once
        // (Combine publishers may fire during app initialization)
        guard !hasSetupHotkeys else { return }
        hasSetupHotkeys = true

        // Set this as the delegate for hotkey actions
        HotkeyManager.shared.setDelegate(self)

        // Determine panel position based on user settings
        let gridPosition = UserDefaults.standard.gridPosition
        let panelPosition: PanelPositioning = gridPosition == .centered ? .centered : .atMouse(.zero)

        // Define bindings declaratively
        let bindings: [HotkeyBinding] = [
            // Cmd+Option+Ctrl+Shift+Space - toggle panel
            HotkeyBinding(
                id: 1,
                keyCode: 49,  // Space
                modifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey),
                action: .toggle(panelPosition)
            ),
            HotkeyBinding(
                id: 3,
                keyCode: 79,
                modifiers: UInt32(cmdKey | optionKey | controlKey | shiftKey),
                action: .confirmOrShow(panelPosition)
            ),
        ]

        // Register all bindings
        for binding in bindings {
            if !HotkeyManager.shared.register(binding) {
                NSLog("[YabaiSpaces] Failed to register hotkey \(binding.id)")
            } else {
                NSLog("[YabaiSpaces] Registered hotkey \(binding.id) keyCode=\(binding.keyCode) trigger=\(binding.trigger)")
            }
        }
    }

    func updateHotkeyPosition() {
        // Re-register hotkeys with new panel position setting
        HotkeyManager.shared.unregisterAll()
        hasSetupHotkeys = false  // Reset to allow re-registration
        setupDefaultHotkeys()
    }

    func updateMenubarVisibility() {
        let show = UserDefaults.standard.showMenubar
        if show {
            // Create status bar item if it doesn't exist
            if statusBarItem == nil {
                statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                refreshButtonStyle()
            }
            statusBarItem?.isVisible = true
        } else {
            // Remove status bar item
            if let item = statusBarItem {
                NSStatusBar.system.removeStatusItem(item)
                statusBarItem = nil
            }
        }
    }

    func updatePanelHotkeys() {
        let show = UserDefaults.standard.showPanel
        if show {
            // Register hotkeys if not already registered
            if !hasSetupHotkeys {
                setupDefaultHotkeys()
            }
        } else {
            // Unregister all hotkeys
            HotkeyManager.shared.unregisterAll()
            hasSetupHotkeys = false
        }
    }

    @MainActor
    func executePanelCommand(_ command: PanelCommand) {
        switch command.operation(isVisible: floatingPanel?.isVisible == true) {
        case .show:
            if UserDefaults.standard.gridPosition == .centered {
                showPanelCentered()
            } else {
                showPanel(at: NSEvent.mouseLocation)
            }
        case .hide: hidePanel()
        case .activateSelected: confirmPanelSelection()
        case .none: break
        }
    }

    private func readSocketMessage(_ descriptor: Int32) -> String? {
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        var bytes: [UInt8] = []
        while bytes.count <= 256 {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { return nil }
            var event = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
            guard poll(&event, 1, Int32(remaining * 1000)) > 0 else { return nil }
            var buffer = [UInt8](repeating: 0, count: 257 - bytes.count)
            let count = recv(descriptor, &buffer, buffer.count, 0)
            if count == 0 {
                return String(bytes: bytes, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard count > 0 else { return nil }
            bytes.append(contentsOf: buffer.prefix(count))
            guard bytes.count <= 256 else { return nil }
            if let newline = bytes.firstIndex(of: 10) {
                guard bytes[(newline + 1)...].allSatisfy({ $0 == 10 || $0 == 13 }) else { return nil }
                return String(bytes: bytes[..<newline], encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    func socketServer() async {
        do {
            let socket = try Socket.create(family: .unix, type: .stream, proto: .unix)
            try socket.listen(on: "/tmp/yabai-indicator.socket")
            guard chmod("/tmp/yabai-indicator.socket", 0o600) == 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }

            while true {
                do {
                    let conn = try socket.acceptClientConnection()
                    defer { conn.close() }

                    // Set socket timeout to prevent hangs
                    var timeout = timeval(tv_sec: 2, tv_usec: 0)
                    let sockfd = conn.socketfd
                    setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
                    setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
                    var noSignal: Int32 = 1
                    setsockopt(sockfd, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal)))
                    var peerUser: uid_t = 0
                    var peerGroup: gid_t = 0
                    guard getpeereid(sockfd, &peerUser, &peerGroup) == 0, peerUser == getuid() else { continue }

                    let msg = readSocketMessage(sockfd)
                    var accepted = true

                    if let msg = msg, let command = PanelCommand(rawValue: msg) {
                        Task { @MainActor in
                            self.executePanelCommand(command)
                        }
                    } else if msg == "refresh" {
                        self.refreshData()
                    } else if msg == "refresh spaces" {
                        Task { @MainActor in
                            self.onSpaceRefresh()
                        }
                    } else if msg == "refresh windows" {
                        Task { @MainActor in
                            self.onWindowRefresh()
                        }
                    } else {
                        accepted = false
                    }
                    let reply = accepted ? "ok queued\n" : "error invalid-command\n"
                    reply.withCString { pointer in
                        _ = send(sockfd, pointer, reply.utf8.count, 0)
                    }
                } catch let error where error is Socket.Error {
                    // Socket error - log and continue
                    NSLog("[YabaiSpaces] Socket operation failed: \(error.localizedDescription)")
                    continue
                } catch {
                    // Other errors
                    NSLog("[YabaiSpaces] Unexpected error in socket server: \(error.localizedDescription)")
                    continue
                }
            }
        } catch {
            NSLog("[YabaiSpaces] Socket server error: \(error.localizedDescription)")
        }
    }
    
    @objc
    func quit() {
        NSApp.terminate(self)
    }

    @objc
    func showAbout() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let message = "YabaiIndicator\nVersion \(version) (Build \(build))\n\nA menu bar indicator for Yabai spaces."

        let alert = NSAlert()
        alert.messageText = "About YabaiIndicator"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc
    func openPreferences() {
        // Get panel position before hiding (for centering preferences over panel)
        let panelFrame = floatingPanel?.frame

        // Hide panel immediately without restoring cursor
        panelManager?.cursorRestorationPolicy = .skip
        hidePanel()

        NSApp.activate(ignoringOtherApps: true)

        // Reuse existing window if it's still valid
        if let window = settingsWindow, window.isVisible {
            window.orderFrontRegardless()
            return
        }

        // Clear old reference and create new window
        settingsWindow = nil

        let hostingView = NSHostingView(rootView: SettingsView())
        let fittingSize = hostingView.fittingSize

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: fittingSize.width, height: fittingSize.height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "YabaiIndicator Settings"
        window.isReleasedWhenClosed = false
        window.contentView = hostingView

        // Center over the panel's position, or fall back to screen center
        if let panelFrame = panelFrame {
            let x = panelFrame.midX - fittingSize.width / 2
            let y = panelFrame.midY - fittingSize.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }

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
            withTitle: "About",
            action: #selector(showAbout),
            keyEquivalent: "")
        statusBarMenu.addItem(NSMenuItem.separator())
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
        NotificationCenter.default.addObserver(self, selector: #selector(self.onOpenPreferencesNotification(_:)), name: NSNotification.Name("OpenPreferences"), object: nil)
    }

    @objc func onOpenPreferencesNotification(_ notification: Notification) {
        openPreferences()
    }

    // Switch spaces, optionally focusing a specific window
    func switchSpace(to yabaiIndex: Int, focusWindowId: UInt64? = nil) {
        // Perform the space switch
        gYabaiClient.focusSpace(index: yabaiIndex)

        // Hide panel after switch (don't restore cursor - we're on a new desktop)
        panelManager?.cursorRestorationPolicy = .skip
        hidePanel()

        // Update space model after switch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            // Query spaces SYNCHRONOUSLY to get updated active flags
            let spaceElems = gNativeClient.querySpaces()
            DispatchQueue.main.async {
                self.spaceModel.spaces = spaceElems
            }

            // Focus specific window if requested
            if let windowId = focusWindowId {
                gYabaiClient.focusWindow(id: windowId)
            }
        }
    }

    func refreshButtonStyle() {
        // Update status bar - show current space(s)
        for subView in statusBarItem?.button?.subviews ?? [] {
            subView.removeFromSuperview()
        }

        // Use dedicated MenubarView (simple state, no panel conflicts)
        let menubarView = NSHostingView(rootView: MenubarView().environmentObject(spaceModel))
        menubarView.setFrameSize(NSSize(width: 0, height: statusBarHeight))
        statusBarItem?.button?.addSubview(menubarView)

        // Always clear cache when button style changes - thumbnails will be captured on space switch
        gThumbnailCache.clear()

        refreshData()
    }

    func updatePanelLayout() {
        let screenHeight = NSScreen.main?.frame.height ?? 1080
        let baseScale = PanelLayout.scale(from: screenHeight)

        // Read grid size from UserDefaults
        let columns = max(1, min(12, UserDefaults.standard.integer(forKey: "panelColumns")))
        let rows = max(1, min(12, UserDefaults.standard.integer(forKey: "panelRows")))

        // Always use 3x scale for floating panel
        panelLayout = PanelLayout(scale: baseScale * 3, columnCount: columns, rowCount: rows)

        // Clear thumbnail cache so new size is used
        gThumbnailCache.clear()

        // Save to UserDefaults so PanelContentView can read it
        panelLayout.save()

        // Update panel with new layout
        panelManager?.updateLayout(panelLayout)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard

        // Check for unpersisted panel defaults BEFORE register()
        // (object(forKey) returns nil for truly missing values before registration)
        let needsPanelColumns = (defaults.object(forKey: "panelColumns") == nil)
        let needsPanelRows = (defaults.object(forKey: "panelRows") == nil)

        if let prefs = Bundle.main.path(forResource: "defaults", ofType: "plist"),
            let dict = NSDictionary(contentsOfFile: prefs) as? [String : Any] {
          defaults.register(defaults: dict)
        }

        // Write defaults after register() so they persist
        if needsPanelColumns {
            defaults.set(4, forKey: "panelColumns")
        }
        if needsPanelRows {
            defaults.set(3, forKey: "panelRows")
        }
        defaults.synchronize()

        sinks = [
            spaceModel.objectWillChange.sink{_ in self.refreshBar()},
            UserDefaults.standard.publisher(for: \.showDisplaySeparator).sink {_ in self.refreshBar()},
            UserDefaults.standard.publisher(for: \.showCurrentSpaceOnly).sink {_ in self.refreshBar()},
            UserDefaults.standard.publisher(for: \.buttonStyle).sink {_ in self.refreshButtonStyle()},
            UserDefaults.standard.publisher(for: \.gridPosition).sink {_ in self.updateHotkeyPosition()},
            UserDefaults.standard.publisher(for: \.showMenubar).sink {_ in self.updateMenubarVisibility()},
            UserDefaults.standard.publisher(for: \.showPanel).sink {_ in self.updatePanelHotkeys()},
            UserDefaults.standard.publisher(for: \.panelColumns).sink {_ in self.updatePanelLayout()},
            UserDefaults.standard.publisher(for: \.panelRows).sink {_ in self.updatePanelLayout()}
        ]

        // Calculate panel layout FIRST (before any views are created)
        // This ensures UserDefaults has the correct scale before views read it
        updatePanelLayout()

        // Initialize panel manager
        panelManager = PanelManager(spaceModel: spaceModel, panelLayout: panelLayout)
        panelManager.keyboardDelegate = self
        _ = panelManager.createPanel()

        // Run socket server in background - suppress Sendable warning as this is intentional
        Task.detached(priority: .background) { [weak self] in
            await self?.socketServer()
        }

        // Create status bar item if enabled
        if UserDefaults.standard.showMenubar {
            statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            statusBarItem?.menu = createMenu()
            refreshButtonStyle()
        }

        // Set up hotkeys if panel is enabled
        if UserDefaults.standard.showPanel {
            setupDefaultHotkeys()
        }

        registerObservers()

        // Log memory usage at startup
        logMemoryUsage(context: "startup")
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clear caches to free memory
        gButtonImageCache.clear()
        gThumbnailCache.clear()
    }
}
