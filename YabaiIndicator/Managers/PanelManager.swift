//
//  PanelManager.swift
//  YabaiIndicator
//
//  Manages the floating panel display and positioning.
//

import Cocoa
import SwiftUI

class PanelManager: NSObject {
    private(set) var panel: NSPanel?
    private var spaceModel: SpaceModel
    private var panelLayout: PanelLayout

    // Cursor restoration
    private var savedCursorPosition: NSPoint?
    var cursorRestorationPolicy = CursorRestorationPolicy.restore

    // Event monitoring
    private var eventMonitors: [Any] = []
    var onPanelHide: (() -> Void)?

    init(spaceModel: SpaceModel, panelLayout: PanelLayout) {
        self.spaceModel = spaceModel
        self.panelLayout = panelLayout
        super.init()
    }

    // MARK: - Panel Creation

    func createPanel() -> NSPanel {
        let contentRect = NSRect(x: 0, y: 0, width: panelLayout.panelSize.width, height: panelLayout.panelSize.height)

        let panel = KeyPanel(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .hudWindow, .resizable],
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
        hostingView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.8).cgColor
        hostingView.layer?.borderWidth = 2
        hostingView.layer?.borderColor = NSColor.white.withAlphaComponent(0.3).cgColor
        panel.contentView = hostingView

        self.panel = panel
        return panel
    }

    // MARK: - Show/Hide

    func show(at mouseLocation: NSPoint, modifiers: PanelModifiers = .none, captureThumbnail: (() -> Void)? = nil) {
        guard let panel = panel else { return }

        // Save cursor position for restoration when panel closes
        cursorRestorationPolicy = .restore
        if UserDefaults.standard.bool(forKey: "saveRestoreCursor") {
            saveCursorPosition()
        }

        // Capture current space thumbnail before showing panel
        captureThumbnail?()

        let panelSize = panel.frame.size

        if UserDefaults.standard.gridPosition == .centered {
            positionCentered(panelSize: panelSize)
        } else {
            positionAtCursor(mouseLocation: mouseLocation, panelSize: panelSize)
        }

        panel.makeKeyAndOrderFront(nil)
        startClickOutsideMonitor()

        // Handle cursor positioning based on user preferences
        switch UserDefaults.standard.cursorPosition {
        case .stayPut:
            break
        case .centerGrid:
            moveCursorToGridCenter()
        case .onThumbnail:
            moveCursorToActiveThumbnail()
        }
    }

    func hide() {
        panel?.orderOut(nil)
        stopClickOutsideMonitor()

        // Restore cursor AFTER panel is hidden (if enabled and unless policy says skip)
        if cursorRestorationPolicy == .restore && UserDefaults.standard.bool(forKey: "saveRestoreCursor") {
            restoreCursorPosition()
        }

        onPanelHide?()
    }

    // MARK: - Positioning

    private func positionCentered(panelSize: CGSize) {
        let mouseLoc = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLoc) }) ?? NSScreen.main else { return }

        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.midX - panelSize.width / 2
        let y = visibleFrame.midY - panelSize.height / 2
        panel?.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func positionAtCursor(mouseLocation: NSPoint, panelSize: CGSize) {
        guard let panel = panel else { return }

        let showDisplaySeparator = UserDefaults.standard.bool(forKey: "showDisplaySeparator")

        var activeGridIndex = 0
        var lastDisplay = 0

        for space in spaceModel.spaces {
            if lastDisplay > 0 && space.display != lastDisplay && showDisplaySeparator {
                activeGridIndex += 1
            }
            if space.active {
                break
            }
            activeGridIndex += 1
            lastDisplay = space.display
        }

        let columns = panelLayout.columnCount
        let columnWidth = panelLayout.columnWidth
        let columnSpacing = panelLayout.columnSpacing
        let buttonHeight = panelLayout.buttonHeight
        let rowSpacing = panelLayout.rowSpacing
        let padding = panelLayout.padding

        let row = activeGridIndex / columns
        let col = activeGridIndex % columns

        let thumbnailCenterX = padding + CGFloat(col) * (columnWidth + columnSpacing) + columnWidth / 2
        let thumbnailCenterY = panel.frame.height - (padding + CGFloat(row) * (buttonHeight + rowSpacing) + buttonHeight / 2)

        let x = mouseLocation.x - thumbnailCenterX
        let y = mouseLocation.y - thumbnailCenterY

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Cursor Movement

    private func moveCursorToActiveThumbnail() {
        guard let panel = panel else { return }

        let showDisplaySeparator = UserDefaults.standard.bool(forKey: "showDisplaySeparator")

        var activeGridIndex = 0
        var lastDisplay = 0

        for space in spaceModel.spaces {
            if lastDisplay > 0 && space.display != lastDisplay && showDisplaySeparator {
                activeGridIndex += 1
            }
            if space.active {
                break
            }
            activeGridIndex += 1
            lastDisplay = space.display
        }

        let columns = panelLayout.columnCount
        let columnWidth = panelLayout.columnWidth
        let columnSpacing = panelLayout.columnSpacing
        let buttonHeight = panelLayout.buttonHeight
        let rowSpacing = panelLayout.rowSpacing
        let padding = panelLayout.padding

        let row = activeGridIndex / columns
        let col = activeGridIndex % columns

        let thumbnailCenterX = padding + CGFloat(col) * (columnWidth + columnSpacing) + columnWidth / 2
        let thumbnailCenterY = panel.frame.height - (padding + CGFloat(row) * (buttonHeight + rowSpacing) + buttonHeight / 2)

        let screenPoint = NSPoint(
            x: panel.frame.origin.x + thumbnailCenterX,
            y: panel.frame.origin.y + thumbnailCenterY
        )

        moveCursor(to: screenPoint)
    }

    private func moveCursorToGridCenter() {
        guard let panel = panel else { return }

        let panelSize = panel.frame.size
        let panelCenterX = panel.frame.origin.x + panelSize.width / 2
        let panelCenterY = panel.frame.origin.y + panelSize.height / 2
        moveCursor(to: NSPoint(x: panelCenterX, y: panelCenterY))
    }

    // MARK: - Cursor Save/Restore

    private func saveCursorPosition() {
        savedCursorPosition = NSEvent.mouseLocation
    }

    private func restoreCursorPosition() {
        guard let saved = savedCursorPosition else { return }

        guard let mainScreen = NSScreen.main else { return }
        let flippedY = mainScreen.frame.height - saved.y
        let flippedPoint = CGPoint(x: saved.x, y: flippedY)

        if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: flippedPoint, mouseButton: .left) {
            event.post(tap: .cgSessionEventTap)
        }
    }

    private func moveCursor(to point: NSPoint) {
        guard let mainScreen = NSScreen.main else { return }
        let flippedY = mainScreen.frame.height - point.y
        let flippedPoint = CGPoint(x: point.x, y: flippedY)

        if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: flippedPoint, mouseButton: .left) {
            event.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: - Click Outside Monitor

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()

        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let panel = self?.panel, panel.isVisible else {
                return event
            }

            if event.buttonNumber == 1 {
                self?.showPanelMenu(at: event.locationInWindow)
                return nil
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.cursorRestorationPolicy = .skip
                self?.hide()
            }
            return event
        }

        let keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let panel = self?.panel, panel.isVisible else {
                return event
            }
            return event
        }

        let globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 {
                self?.hide()
            }
        }

        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.cursorRestorationPolicy = .skip
            self?.hide()
        }

        if let local = localMonitor { eventMonitors.append(local) }
        if let key = keyMonitor { eventMonitors.append(key) }
        if let globalKey = globalKeyMonitor { eventMonitors.append(globalKey) }
        if let global = globalMonitor { eventMonitors.append(global) }
    }

    private func stopClickOutsideMonitor() {
        eventMonitors.forEach { NSEvent.removeMonitor($0) }
        eventMonitors.removeAll()
    }

    // MARK: - Panel Menu

    private func showPanelMenu(at location: NSPoint) {
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
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        panel?.menu = menu
        menu.popUp(positioning: nil, at: location, in: panel?.contentView)
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func openPreferences() {
        // Post notification to open preferences (handled by YabaiAppDelegate)
        NotificationCenter.default.post(name: NSNotification.Name("OpenPreferences"), object: nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Layout Updates

    func updateLayout(_ newLayout: PanelLayout) {
        self.panelLayout = newLayout

        if let panel = panel {
            let newFrame = NSRect(origin: panel.frame.origin, size: newLayout.panelSize)
            panel.setFrame(newFrame, display: true)
        }
    }
}
