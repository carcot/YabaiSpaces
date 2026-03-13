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

// Global hotkey using Carbon
class GlobalHotkey {
    private var hotkeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) -> Bool {
        self.handler = handler

        var hotkeyID = EventHotKeyID(signature: OSType(0x59494920), id: 1) // 'YI ' + 1

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status != noErr {
            NSLog("Failed to register hotkey: \(status)")
            return false
        }

        // Install event handler
        var mySpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var handlerRef: EventHandlerRef?

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            if let userData = userData {
                let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()
                hotkey.handler?()
            }
            return noErr
        }, 1, &mySpec, selfPtr, &handlerRef)

        return true
    }
}

// Global key handler using Carbon (for keys like Escape that need to work globally)
class GlobalKeyHandler {
    private var handlerRef: EventHandlerRef?
    private var keyCode: UInt32
    private var handler: () -> Void

    init(keyCode: UInt32, handler: @escaping () -> Void) {
        self.keyCode = keyCode
        self.handler = handler
    }

    func start() -> Bool {
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventRawKeyDown))

        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        let status = InstallEventHandler(GetApplicationEventTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            if let userData = userData {
                let keyHandler = Unmanaged<GlobalKeyHandler>.fromOpaque(userData).takeUnretainedValue()

                // Get the key code from the event
                var keyCode: UInt32 = 0
                GetEventParameter(theEvent, EventParamName(kEventParamKeyCode), EventParamType(typeUInt32), nil, MemoryLayout<UInt32>.size, nil, &keyCode)

                if keyCode == keyHandler.keyCode {
                    keyHandler.handler()
                    return noErr  // Consume the event
                }
            }
            return CallNextEventHandler(nextHandler, theEvent)
        }, 1, &eventSpec, selfPtr, &handlerRef)

        return status == noErr
    }

    func stop() {
        if let ref = handlerRef {
            RemoveEventHandler(ref)
            handlerRef = nil
        }
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

    let statusBarHeight: CGFloat = 22
    let itemWidth: CGFloat = 30
    let panelPadding: CGFloat = 8

    var sinks: [AnyCancellable?] = []
    var receiverQueue = DispatchQueue(label: "yabai-indicator.socket.receiver")
    var eventMonitors: [Any] = []
    var globalHotkey: GlobalHotkey?
    var escapeKeyHandler: GlobalKeyHandler?

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
    
    func onWindowRefresh() {
        if UserDefaults.standard.buttonStyle == .windows {
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
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 145, height: 90),
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

        // Grid layout: 4 columns, each 32px wide with 2px spacing
        let columns = 4
        let columnWidth: CGFloat = 32
        let columnSpacing: CGFloat = 2
        let buttonHeight: CGFloat = 20
        let rowSpacing: CGFloat = 4
        let padding: CGFloat = 4

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
        panel.orderFrontRegardless()

        // Don't activate the app - it interferes with other windows like Settings
        // NSApp.activate(ignoringOtherApps: true)

        // Start monitoring for clicks outside
        startClickOutsideMonitor()
    }

    func hidePanel() {
        floatingPanel?.orderOut(nil)
        stopClickOutsideMonitor()
    }

    func startClickOutsideMonitor() {
        stopClickOutsideMonitor() // Remove any existing monitor

        // Local monitor for clicks within our app
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            NSLog("Local click: button=\(event.buttonNumber), location=\(event.locationInWindow)")
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

        // Global monitor for clicks in other apps - hide on any click
        // Note: This may cause benign Mach port warnings in logs when accessing events from other processes
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.hidePanel()
        }

        if let local = localMonitor { eventMonitors.append(local) }
        if let global = globalMonitor { eventMonitors.append(global) }
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
        let newStyle: ButtonStyle = currentStyle == .numeric ? .windows : .numeric
        UserDefaults.standard.set(newStyle.rawValue, forKey: "buttonStyle")
    }

    func stopClickOutsideMonitor() {
        for monitor in eventMonitors {
            NSEvent.removeMonitor(monitor)
        }
        eventMonitors.removeAll()
    }

    func setupTripleClickMonitor() {
        // Use Carbon for reliable global hotkey
        let hotkey = GlobalHotkey()
        // KeyCode 49 = Space, modifiers: cmdKey = 256 (0x100), optionKey = 2048 (0x800)
        let modifiers: UInt32 = UInt32(cmdKey | optionKey)
        let success = hotkey.register(keyCode: 49, modifiers: modifiers) { [weak self] in
            self?.togglePanel(at: NSEvent.mouseLocation)
        }

        if success {
            globalHotkey = hotkey
        }

        // Set up Escape key handler to hide the panel
        let escapeHandler = GlobalKeyHandler(keyCode: 53) { [weak self] in  // KeyCode 53 = Escape
            self?.hidePanel()
        }
        if escapeHandler.start() {
            escapeKeyHandler = escapeHandler
        }
    }

    func togglePanel(at mouseLocation: NSPoint) {
        guard let panel = floatingPanel else {
            return
        }

        if panel.isVisible {
            // Move panel to new location instead of hiding
            showPanel(at: mouseLocation)
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
                    receiverQueue.async {
                        // log("Refreshing on main thread")
                        self.onSpaceRefresh()
                    }
                } else if msg == "refresh windows" {
                    receiverQueue.async {
                        // log("Refreshing on main thread")
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

        refreshData()
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

        Task {
            await self.socketServer()
        }

        // Create status bar item (for menu access)
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Create floating panel
        createFloatingPanel()

        // Set up triple-click monitor
        setupTripleClickMonitor()

        refreshButtonStyle()
        registerObservers()
    }
}
