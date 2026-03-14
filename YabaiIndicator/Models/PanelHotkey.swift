//
//  PanelHotkey.swift
//  YabaiIndicator
//
//  Composable types for panel hotkey system
//

import AppKit

/// Positioning behavior for showing the panel
enum PanelPositioning: Equatable {
    case atMouse(NSPoint)           // Position at specific point (usually cursor)
    case centered                   // Center on active screen
}

/// Actions that can be performed on the panel
enum PanelHotkeyAction: Equatable {
    case toggle(PanelPositioning)
    case show(PanelPositioning)
    case hide
}

/// Additional behaviors to apply after showing panel
struct PanelModifiers: Equatable {
    let moveMouseToCenter: Bool

    static let none = PanelModifiers(moveMouseToCenter: false)
    static let moveMouseToCenter = PanelModifiers(moveMouseToCenter: true)
}

/// When the hotkey action should fire
enum KeyTrigger: Equatable {
    case immediate                           // Fire immediately on key press
    case tap(threshold: TimeInterval)        // Fire only on quick press-release within threshold
    case release                             // Fire on key up
}

/// A binding between a physical key combination and a panel action
struct HotkeyBinding {
    let id: UInt32
    let keyCode: UInt32
    let modifiers: UInt32
    let action: PanelHotkeyAction
    let modifiersAfterShow: PanelModifiers
    let trigger: KeyTrigger
    let detectTyping: Bool               // For tap: ignore if other keys pressed while held
    let isModifierKey: Bool

    init(id: UInt32, keyCode: UInt32, modifiers: UInt32, action: PanelHotkeyAction, modifiersAfterShow: PanelModifiers = .none, trigger: KeyTrigger = .immediate, detectTyping: Bool = true) {
        self.id = id
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.action = action
        self.modifiersAfterShow = modifiersAfterShow
        self.trigger = trigger
        self.detectTyping = detectTyping
        // Detect modifier keys (56-63 are modifiers on macOS: Shift, Control, Option, Command)
        self.isModifierKey = (keyCode >= 56 && keyCode <= 63)
    }
}

/// Protocol for objects that can execute panel hotkey actions
protocol PanelHotkeyDelegate: AnyObject {
    var floatingPanel: NSPanel? { get }
    func showPanel(at position: NSPoint, modifiers: PanelModifiers)
    func showPanelCentered(modifiers: PanelModifiers)
    func hidePanel()
}
