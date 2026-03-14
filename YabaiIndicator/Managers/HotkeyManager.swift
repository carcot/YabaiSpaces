//
//  HotkeyManager.swift
//  YabaiIndicator
//
//  Centralized hotkey management for panel
//

import AppKit
import Carbon

/// Unified composable hotkey using CGEventTap for all keys and trigger types
class ComposableHotkey {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let binding: HotkeyBinding
    private let handler: () -> Void

    // Tap trigger state
    private var pressStartTime: DispatchTime?
    private var tapTimer: DispatchWorkItem?
    private var isTyping = false
    private var isPressed = false
    private var hasFired = false  // Track if action already fired for this press

    init(binding: HotkeyBinding, handler: @escaping () -> Void) {
        self.binding = binding
        self.handler = handler
        setupEventTap()
    }

    private func setupEventTap() {
        // Listen to keyDown, keyUp, and flagsChanged events
        let keyDownMask = (1 << CGEventType.keyDown.rawValue)
        let keyUpMask = (1 << CGEventType.keyUp.rawValue)
        let flagsChangedMask = (1 << CGEventType.flagsChanged.rawValue)
        let eventMask = keyDownMask | keyUpMask | flagsChangedMask

        let userData = UnsafeMutableRawPointer(Unmanaged.passRetained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if let refcon = refcon {
                    let hotkey = Unmanaged<ComposableHotkey>.fromOpaque(refcon).takeUnretainedValue()
                    return hotkey.handleEvent(proxy: proxy, type: type, event: event)
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: userData
        ) else {
            NSLog("Failed to create event tap for hotkey \(binding.id)")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        let triggerDesc: String
        switch binding.trigger {
        case .immediate: triggerDesc = "immediate"
        case .tap(let t): triggerDesc = "tap(\(t)s)"
        case .release: triggerDesc = "release"
        }
        NSLog("Registered composable hotkey \(binding.id): keyCode=\(binding.keyCode), modifiers=\(binding.modifiers), trigger=\(triggerDesc)")
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let eventKeyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let eventFlags = event.flags

        // Check if modifiers match (for non-modifier keys, we check the actual modifier flags)
        let modifiersMatch = checkModifiers(eventFlags: eventFlags)

        if binding.isModifierKey {
            return handleModifierKeyEvent(type: type, event: event)
        } else {
            // For regular keys, only process if modifiers match and key code matches
            if eventKeyCode == Int64(binding.keyCode) && modifiersMatch {
                return handleRegularKeyEvent(type: type, event: event)
            }
        }

        // For tap trigger with detectTyping: check if another key was pressed while we're pressed
        if binding.detectTyping && isPressed && type == .keyDown {
            let isModifierKey = (eventKeyCode >= 56 && eventKeyCode <= 63)
            if !isModifierKey && eventKeyCode != Int64(binding.keyCode) {
                isTyping = true
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleRegularKeyEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch binding.trigger {
        case .immediate:
            if type == .keyDown && !hasFired {
                hasFired = true
                handler()
            } else if type == .keyUp {
                hasFired = false
            }

        case .tap(let threshold):
            if type == .keyDown && !isPressed {
                isPressed = true
                isTyping = false
                pressStartTime = DispatchTime.now()
                hasFired = false

                // Schedule timeout to mark as "held too long"
                let workItem = DispatchWorkItem { [weak self] in
                    self?.hasFired = true  // Mark as fired so we don't fire on release
                }
                tapTimer = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + threshold, execute: workItem)

            } else if type == .keyUp && isPressed {
                isPressed = false
                tapTimer?.cancel()
                tapTimer = nil

                // Fire only if quick tap (not typing, not held too long, haven't fired yet)
                if !isTyping && !hasFired {
                    if let start = pressStartTime {
                        let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
                        let elapsedSeconds = Double(elapsed) / 1_000_000_000
                        if elapsedSeconds < threshold {
                            handler()
                            hasFired = true
                        }
                    }
                }
                pressStartTime = nil
            }

        case .release:
            if type == .keyUp {
                handler()
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleModifierKeyEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        guard type == .flagsChanged else {
            // For tap trigger with detectTyping on modifier keys
            if binding.detectTyping && isPressed && type == .keyDown {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let isModifier = (keyCode >= 56 && keyCode <= 63)
                if !isModifier {
                    isTyping = true
                }
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Int64(binding.keyCode) else {
            return Unmanaged.passUnretained(event)
        }

        let isPressed = checkModifierPressed(event.flags)

        switch binding.trigger {
        case .immediate:
            if isPressed && !self.isPressed && !hasFired {
                hasFired = true
                handler()
            } else if !isPressed {
                self.isPressed = false
                hasFired = false
            }

        case .tap(let threshold):
            if isPressed && !self.isPressed {
                // Press started
                self.isPressed = true
                isTyping = false
                pressStartTime = DispatchTime.now()
                hasFired = false

                let workItem = DispatchWorkItem { [weak self] in
                    self?.hasFired = true
                }
                tapTimer = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + threshold, execute: workItem)

            } else if !isPressed && self.isPressed {
                // Released
                self.isPressed = false
                tapTimer?.cancel()
                tapTimer = nil

                if !isTyping && !hasFired {
                    if let start = pressStartTime {
                        let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
                        let elapsedSeconds = Double(elapsed) / 1_000_000_000
                        if elapsedSeconds < threshold {
                            handler()
                            hasFired = true
                        }
                    }
                }
                pressStartTime = nil
            }

        case .release:
            if !isPressed && self.isPressed {
                self.isPressed = false
                handler()
            } else if isPressed {
                self.isPressed = true
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func checkModifiers(eventFlags: CGEventFlags) -> Bool {
        let carbonModifiers = binding.modifiers

        // Check cmdKey
        let wantCmd = (carbonModifiers & UInt32(cmdKey)) != 0
        let haveCmd = eventFlags.contains(.maskCommand)
        if wantCmd != haveCmd { return false }

        // Check optionKey
        let wantOption = (carbonModifiers & UInt32(optionKey)) != 0
        let haveOption = eventFlags.contains(.maskAlternate)
        if wantOption != haveOption { return false }

        // Check controlKey
        let wantControl = (carbonModifiers & UInt32(controlKey)) != 0
        let haveControl = eventFlags.contains(.maskControl)
        if wantControl != haveControl { return false }

        // Check shiftKey
        let wantShift = (carbonModifiers & UInt32(shiftKey)) != 0
        let haveShift = eventFlags.contains(.maskShift)
        if wantShift != haveShift { return false }

        return true
    }

    private func checkModifierPressed(_ flags: CGEventFlags) -> Bool {
        switch binding.keyCode {
        case 56, 60: // Shift keys
            return flags.contains(.maskShift)
        case 58, 61: // Option/Alt keys
            return flags.contains(.maskAlternate)
        case 59, 62: // Control keys
            return flags.contains(.maskControl)
        case 55, 63: // Command keys
            return flags.contains(.maskCommand)
        default:
            return false
        }
    }

    deinit {
        tapTimer?.cancel()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
    }
}

/// Centralized manager for panel hotkeys
class HotkeyManager {
    static let shared = HotkeyManager()
    private var bindings: [HotkeyBinding] = []
    private var hotkeys: [UInt32: ComposableHotkey] = [:]
    private weak var delegate: PanelHotkeyDelegate?

    private init() {}

    func setDelegate(_ delegate: PanelHotkeyDelegate) {
        self.delegate = delegate
    }

    /// Register a hotkey binding. Returns true if successful.
    func register(_ binding: HotkeyBinding) -> Bool {
        bindings.append(binding)

        let hotkey = ComposableHotkey(binding: binding) { [weak self] in
            self?.execute(binding.action, modifiers: binding.modifiersAfterShow)
        }
        hotkeys[binding.id] = hotkey
        return true
    }

    /// Execute a panel hotkey action
    func execute(_ action: PanelHotkeyAction, modifiers: PanelModifiers = .none) {
        guard let delegate = delegate else { return }

        switch action {
        case .toggle(.atMouse(let point)):
            let position = point == .zero ? NSEvent.mouseLocation : point
            if let panel = delegate.floatingPanel, panel.isVisible {
                delegate.hidePanel()
            } else {
                delegate.showPanel(at: position, modifiers: modifiers)
            }
        case .toggle(.centered):
            if let panel = delegate.floatingPanel, panel.isVisible {
                delegate.hidePanel()
            } else {
                delegate.showPanelCentered(modifiers: modifiers)
            }
        case .show(.atMouse(let point)):
            let position = point == .zero ? NSEvent.mouseLocation : point
            delegate.showPanel(at: position, modifiers: modifiers)
        case .show(.centered):
            delegate.showPanelCentered(modifiers: modifiers)
        case .hide:
            delegate.hidePanel()
        }
    }

    /// Unregister a hotkey by ID
    func unregister(id: UInt32) {
        bindings.removeAll { $0.id == id }
        hotkeys.removeValue(forKey: id)
    }

    /// Unregister all hotkeys
    func unregisterAll() {
        bindings.removeAll()
        hotkeys.removeAll()
    }
}
