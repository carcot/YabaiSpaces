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
    var floatingPanel: NSPanel?
    var settingsWindow: NSWindow?
    var statusBarItem: NSStatusItem?
    var application: NSApplication = NSApplication.shared
    var spaceModel = SpaceModel()

    // Track last active space for thumbnail capture
    private var lastActiveSpaceId: UInt64 = 0

    // Save/restore cursor position when panel opens/closes
    private var savedCursorPosition: NSPoint?
    private var hideWithoutRestore = false  // Don't restore cursor after space selection

    // Ensure hotkeys are only set up once (Combine publisher may fire during init)
    private var hasSetupHotkeys = false

    let statusBarHeight: CGFloat = 22
    let panelPadding: CGFloat = 8

    // Panel layout - scale calculated from screen height
    var panelLayout: PanelLayout = PanelLayout()

    var sinks: [AnyCancellable?] = []
    var receiverQueue = DispatchQueue(label: "yabai-indicator.socket.receiver")
    var eventMonitors: [Any] = []

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
    func captureThumbnail(for space: Space) {
        let displays = gNativeClient.queryDisplays()
        guard space.display - 1 >= 0, space.display - 1 < displays.count else {
            NSLog("captureThumbnail: invalid display index for space \(space.index)")
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

        if let thumbnail = gPrivateWindowCapture.captureSpace(
            windows: spaceWindows,
            display: display,
            targetSize: targetSize
        ) {
            gThumbnailCache.set(spaceId: space.spaceid, image: thumbnail)
        }
    }

    func onWindowRefresh() {
        let buttonStyle = UserDefaults.standard.buttonStyle

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

    func showPanel(at mouseLocation: NSPoint, modifiers: PanelModifiers = .none) {
        guard let panel = floatingPanel else { return }

        // Save cursor position for restoration when panel closes (if enabled)
        hideWithoutRestore = false
        if UserDefaults.standard.bool(forKey: "saveRestoreCursor") {
            saveCursorPosition()
        }

        // Capture current space thumbnail before showing panel
        // TODO: Make this configurable via preferences (instant show vs fresh thumbnails)
        // Latency: ~140-150ms, tested as acceptable
        if let currentSpace = spaceModel.spaces.first(where: { $0.active }) {
            captureThumbnail(for: currentSpace)
        }

        let panelSize = panel.frame.size

        if UserDefaults.standard.gridPosition == .centered {
            // Center panel on screen containing cursor
            let mouseLoc = NSEvent.mouseLocation
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLoc) }) ?? NSScreen.main {
                let visibleFrame = screen.visibleFrame
                let x = visibleFrame.midX - panelSize.width / 2
                let y = visibleFrame.midY - panelSize.height / 2
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        } else {
            // Position panel with thumbnail at cursor
            // Panel always shows ALL spaces (including dividers)
            let showDisplaySeparator = UserDefaults.standard.bool(forKey: "showDisplaySeparator")

            var activeGridIndex = 0
            var lastDisplay = 0

            for space in spaceModel.spaces {
                // Add divider before new display (if enabled) - dividers take a grid slot
                if lastDisplay > 0 && space.display != lastDisplay && showDisplaySeparator {
                    activeGridIndex += 1
                }

                // Panel shows all spaces, count every space
                if space.active {
                    break
                }
                activeGridIndex += 1
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
        }

        // Reset keyboard selection to active space
        resetPanelSelection()

        panel.orderFrontRegardless()
        panel.makeKey()

        // Don't activate the app - it interferes with other windows like Settings
        // NSApp.activate(ignoringOtherApps: true)

        // Start monitoring for clicks outside
        startClickOutsideMonitor()

        // Handle cursor positioning based on settings
        switch UserDefaults.standard.cursorPosition {
        case .stayPut:
            break // Don't move cursor
        case .centerGrid:
            moveCursorToPanelGridCenter()
        case .onThumbnail:
            moveMouseToPanelCenter()
        }
    }

    func showPanelCentered(modifiers: PanelModifiers = .none) {
        guard let panel = floatingPanel else { return }

        // Use the screen containing the cursor
        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLoc) }) ?? NSScreen.main else { return }

        // Save cursor position for restoration when panel closes (if enabled)
        hideWithoutRestore = false
        if UserDefaults.standard.bool(forKey: "saveRestoreCursor") {
            saveCursorPosition()
        }

        // Capture current space thumbnail before showing panel
        if let currentSpace = spaceModel.spaces.first(where: { $0.active }) {
            captureThumbnail(for: currentSpace)
        }

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

        // Move cursor based on cursorPosition setting
        let cursorPosition = UserDefaults.standard.cursorPosition
        switch cursorPosition {
        case .stayPut:
            break
        case .centerGrid:
            moveCursorToPanelGridCenter()
        case .onThumbnail:
            moveMouseToPanelCenter()
        }
    }

    private func moveMouseToPanelCenter() {
        guard let panel = floatingPanel else { return }

        NSLog("DEBUG: panel.frame=\(panel.frame)")

        // Find the current active space's thumbnail position within the panel
        // Panel always shows ALL spaces (including dividers)
        let showDisplaySeparator = UserDefaults.standard.bool(forKey: "showDisplaySeparator")

        var activeGridIndex = 0
        var lastDisplay = 0

        for space in spaceModel.spaces {
            // Add divider before new display (if enabled) - dividers take a grid slot
            if lastDisplay > 0 && space.display != lastDisplay && showDisplaySeparator {
                activeGridIndex += 1
            }

            // Panel shows all spaces, count every space
            if space.active {
                break
            }
            activeGridIndex += 1
            lastDisplay = space.display
        }

        NSLog("DEBUG: activeGridIndex=\(activeGridIndex)")

        // Calculate thumbnail center position (same logic as panel layout)
        let columns = panelLayout.columnCount
        let columnWidth = panelLayout.columnWidth
        let columnSpacing = panelLayout.columnSpacing
        let buttonHeight = panelLayout.buttonHeight
        let rowSpacing = panelLayout.rowSpacing
        let padding = panelLayout.padding

        let row = activeGridIndex / columns
        let col = activeGridIndex % columns

        NSLog("DEBUG: row=\(row), col=\(col)")

        // Thumbnail center relative to panel origin (bottom-left)
        let thumbnailCenterX = padding + CGFloat(col) * (columnWidth + columnSpacing) + columnWidth / 2
        let thumbnailCenterY = panel.frame.height - (padding + CGFloat(row) * (buttonHeight + rowSpacing) + buttonHeight / 2)

        NSLog("DEBUG: thumbnailCenter in panel coords: x=\(thumbnailCenterX), y=\(thumbnailCenterY)")

        // Convert to screen coordinates
        let screenPoint = NSPoint(
            x: panel.frame.origin.x + thumbnailCenterX,
            y: panel.frame.origin.y + thumbnailCenterY
        )

        NSLog("Moving cursor to thumbnail center: screen=\(screenPoint)")
        moveCursor(to: screenPoint)
    }

    private func moveCursorToPanelGridCenter() {
        guard let panel = floatingPanel else { return }

        NSLog("DEBUG: moveCursorToPanelGridCenter - panel frame: \(panel.frame)")

        // Move cursor to center of the panel
        let panelSize = panel.frame.size
        let panelCenterX = panel.frame.origin.x + panelSize.width / 2
        let panelCenterY = panel.frame.origin.y + panelSize.height / 2
        NSLog("DEBUG: moveCursorToPanelGridCenter - panel center: x=\(panelCenterX), y=\(panelCenterY)")
        moveCursor(to: NSPoint(x: panelCenterX, y: panelCenterY))
    }

    private func moveCursorToScreenCenter() {
        // Find the screen containing the cursor, or main screen as fallback
        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLoc) }) ?? NSScreen.main else { return }
        let center = NSPoint(
            x: screen.visibleFrame.midX,
            y: screen.visibleFrame.midY
        )
        moveCursor(to: center)
    }

    private func saveCursorPosition() {
        savedCursorPosition = NSEvent.mouseLocation
        NSLog("DEBUG: Saved cursor position: \(savedCursorPosition!)")
    }

    private func restoreCursorPosition() {
        guard let saved = savedCursorPosition else { return }
        NSLog("DEBUG: Restoring cursor to: \(saved)")

        // Flip Y coordinate for CGEvent (top-left origin)
        guard let mainScreen = NSScreen.main else { return }
        let flippedY = mainScreen.frame.height - saved.y
        let flippedPoint = CGPoint(x: saved.x, y: flippedY)

        if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: flippedPoint, mouseButton: .left) {
            event.post(tap: .cgSessionEventTap)
            NSLog("DEBUG: Sent restore event to flipped: \(flippedPoint)")
        } else {
            NSLog("DEBUG: Failed to create restore event")
        }
        savedCursorPosition = nil
    }

    private func moveCursor(to point: NSPoint) {
        NSLog("DEBUG: moveCursor called with point=\(point)")

        // Try flipping Y coordinate (CGEvent might use top-left origin)
        guard let mainScreen = NSScreen.main else { return }
        let flippedY = mainScreen.frame.height - point.y
        let flippedPoint = CGPoint(x: point.x, y: flippedY)

        NSLog("DEBUG: flipped point=\(flippedPoint), screenHeight=\(mainScreen.frame.height)")

        if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: flippedPoint, mouseButton: .left) {
            event.post(tap: .cgSessionEventTap)
            NSLog("DEBUG: sent flipped event")
        } else {
            NSLog("DEBUG: failed to create event")
        }
    }

    func hidePanel() {
        floatingPanel?.orderOut(nil)
        stopClickOutsideMonitor()

        // Restore cursor AFTER panel is hidden (if enabled and unless hiding after space selection)
        if !hideWithoutRestore && UserDefaults.standard.bool(forKey: "saveRestoreCursor") {
            restoreCursorPosition()
        }
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

        let aboutItem = NSMenuItem(
            title: "About",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ""
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit YabaiIndicator",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        // Show menu at the click location
        // Note: NSMenu uses top-left origin, so we need to flip the Y coordinate
        if let panel = floatingPanel, let contentView = panel.contentView {
            let flippedLocation = NSPoint(x: location.x, y: contentView.frame.height - location.y)
            menu.popUp(positioning: nil, at: flippedLocation, in: contentView)
        }
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
            // Cmd+Option+Space - toggle panel (position based on gridPosition setting)
            HotkeyBinding(
                id: 1,
                keyCode: 49,  // Space
                modifiers: UInt32(cmdKey | optionKey),
                action: .toggle(panelPosition)
            ),
            // Cmd+Option+Ctrl+Space - toggle panel (redundant now, same as above)
            HotkeyBinding(
                id: 2,
                keyCode: 49,  // Space
                modifiers: UInt32(cmdKey | optionKey | controlKey),
                action: .toggle(panelPosition)
            ),
            // Right Shift - toggle panel on quick tap
            // Uses tap trigger with 0.25s threshold to distinguish tap from hold
            HotkeyBinding(
                id: 3,
                keyCode: 60,  // Right Shift
                modifiers: 0,
                action: .toggle(panelPosition),
                trigger: .tap(threshold: 0.25),
                detectTyping: true
            ),
        ]

        // Register all bindings
        for binding in bindings {
            if !HotkeyManager.shared.register(binding) {
                NSLog("Failed to register hotkey \(binding.id)")
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
        hideWithoutRestore = true
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
    }

    // Switch spaces
    func switchSpace(to yabaiIndex: Int) {
        // Perform the space switch
        NSLog("switchSpace: calling focusSpace(\(yabaiIndex))")
        gYabaiClient.focusSpace(index: yabaiIndex)

        // Hide panel after switch (don't restore cursor - we're on a new desktop)
        hideWithoutRestore = true
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

        // Read grid size from UserDefaults (with defaults if not set)
        let columns = max(1, min(12, UserDefaults.standard.integer(forKey: "panelColumns")))
        let rows = max(1, min(6, UserDefaults.standard.integer(forKey: "panelRows")))

        // Always use 3x scale for floating panel
        panelLayout = PanelLayout(scale: baseScale * 3, columnCount: columns, rowCount: rows)

        // Clear thumbnail cache so new size is used
        gThumbnailCache.clear()

        // Save to UserDefaults so PanelContentView can read it
        panelLayout.save()

        NSLog("PanelLayout updated: scale=\(panelLayout.scale), columns=\(panelLayout.columnCount), rows=\(panelLayout.rowCount)")

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
    }
}
