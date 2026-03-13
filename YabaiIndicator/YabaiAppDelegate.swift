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

        statusBarItem?.button?.frame.size.width = newWidth
        statusBarItem?.button?.subviews[0].frame.size.width = newWidth

        floatingPanel?.setContentSize(NSSize(width: newWidth, height: statusBarHeight + panelPadding * 2))
    }

    func createFloatingPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 50),
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

        let hostingView = NSHostingView(rootView: ContentView().environmentObject(spaceModel))
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 6
        hostingView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
        panel.contentView = hostingView

        floatingPanel = panel
    }

    func showPanel(at mouseLocation: NSPoint) {
        guard let panel = floatingPanel else { return }


        // Calculate panel position centered on mouse
        let panelSize = panel.frame.size
        let newX = mouseLocation.x - panelSize.width / 2
        let newY = mouseLocation.y - panelSize.height / 2

        panel.setFrameOrigin(NSPoint(x: newX, y: newY))
        panel.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)

        // Start monitoring for clicks outside
        startClickOutsideMonitor()
    }

    func hidePanel() {
        floatingPanel?.orderOut(nil)
        stopClickOutsideMonitor()
    }

    func startClickOutsideMonitor() {
        stopClickOutsideMonitor() // Remove any existing monitor

        // Local monitor for clicks within our app (including panel buttons)
        let localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            // Let the click pass through first, then hide
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self?.hidePanel()
            }
            return event
        }

        // Global monitor for clicks in other apps
        let globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.hidePanel()
        }

        if let local = localMonitor { eventMonitors.append(local) }
        if let global = globalMonitor { eventMonitors.append(global) }
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
    }

    func togglePanel(at mouseLocation: NSPoint) {
        guard let panel = floatingPanel else {
            return
        }

        if panel.isVisible {
            hidePanel()
        } else {
            // Force the panel to be ordered out first to reset state
            panel.orderOut(nil)
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
      if #available(macOS 13, *) {
          NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
      } else {
          NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
      }
      NSApp.activate(ignoringOtherApps: true)
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
        // Update floating panel content
        if let panel = floatingPanel {
            let hostingView = NSHostingView(rootView: ContentView().environmentObject(spaceModel))
            hostingView.wantsLayer = true
            hostingView.layer?.cornerRadius = 6
            hostingView.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95).cgColor
            panel.contentView = hostingView
        }

        // Update status bar
        for subView in statusBarItem?.button?.subviews ?? [] {
            subView.removeFromSuperview()
        }
        statusBarItem?.button?.addSubview(createStatusItemView())
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
        statusBarItem?.menu = createMenu()

        // Create floating panel
        createFloatingPanel()

        // Set up triple-click monitor
        setupTripleClickMonitor()

        refreshButtonStyle()
        registerObservers()
    }
}
