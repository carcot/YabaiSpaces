//
//  PanelHotkey.swift
//  YabaiIndicator
//
//  Composable types for panel hotkey system
//

import AppKit

enum WindowHandlingCommand: String, CaseIterable {
    case moveLeft = "window move-left"
    case moveRight = "window move-right"
    case moveUp = "window move-up"
    case moveDown = "window move-down"
    case wider = "window wider"
    case narrower = "window narrower"
    case taller = "window taller"
    case shorter = "window shorter"
    case toggleFloat = "window toggle-float"
    case toggleSplit = "window toggle-split"
    case tile = "space tile"
    case untile = "space untile"
    case enable = "handling on"
    case disable = "handling off"
}

enum PrefixCommand: String, CaseIterable {
    case start = "prefix start"
    case cancel = "prefix cancel"
}

enum ConfigurationCommand: String {
    case reload = "config reload"
}

struct FocusEventCommand: Equatable {
    enum Kind: String { case focused = "window-focused", destroyed = "window-destroyed" }
    let kind: Kind
    let windowID: UInt64

    init?(rawValue: String) {
        let fields = rawValue.split(separator: " ", omittingEmptySubsequences: false)
        guard fields.count == 3, fields[0] == "event", let kind = Kind(rawValue: String(fields[1])),
              !fields[2].isEmpty, fields[2].utf8.allSatisfy({ $0 >= 48 && $0 <= 57 }),
              let identifier = UInt64(fields[2]), identifier > 0, identifier <= UInt64(UInt32.max) else { return nil }
        self.kind = kind
        windowID = identifier
    }
}

struct CapsBinding: Equatable {
    enum Match: String { case exact, contains }
    let app: String
    let space: Int?
    let match: Match

    init(app: String, space: Int? = nil, match: Match = .exact) {
        self.app = app
        self.space = space
        self.match = match
    }

    static let defaults: [String: CapsBinding] = [
        "a": CapsBinding(app: "Word", match: .contains),
        "w": CapsBinding(app: "Word", match: .contains),
        "s": CapsBinding(app: "Safari", match: .contains),
        "d": CapsBinding(app: "Discord", match: .contains),
        "f": CapsBinding(app: "Firefox", match: .contains),
        "g": CapsBinding(app: "GoodNotes", match: .contains),
        "h": CapsBinding(app: "Brave Browser", space: 8),
        "j": CapsBinding(app: "iTerm2", match: .contains),
        "k": CapsBinding(app: "kitty", match: .contains),
        "l": CapsBinding(app: "Logseq", match: .contains),
        "z": CapsBinding(app: "zoom.us", match: .contains),
        "x": CapsBinding(app: "Excel", match: .contains),
        "c": CapsBinding(app: "Brave Browser", space: 6),
        "v": CapsBinding(app: "Code", match: .contains),
        "b": CapsBinding(app: "Brave Browser", space: 7),
        "n": CapsBinding(app: "Signal", match: .contains),
        "m": CapsBinding(app: "Messages", match: .contains),
        "r": CapsBinding(app: "Friendly Streaming", match: .contains),
        "y": CapsBinding(app: "Spotify", match: .contains),
        "p": CapsBinding(app: "PowerPoint", match: .contains)
    ]
}

struct PrefixSession {
    static let timeout: TimeInterval = 2
    private(set) var deadline: TimeInterval = 0

    mutating func start(now: TimeInterval) { deadline = now + Self.timeout }
    mutating func cancel() { deadline = 0 }
    func isActive(now: TimeInterval) -> Bool { deadline > now }

    mutating func select(_ key: String, now: TimeInterval) -> JumpCommand? {
        guard isActive(now: now), let command = JumpCommand(rawValue: "jump \(key)") else { return nil }
        cancel()
        return command
    }
}

struct JumpCommand: Equatable {
    let key: String
    let binding: CapsBinding?

    init?(rawValue: String, bindings: [String: CapsBinding] = CapsBinding.defaults) {
        guard rawValue.hasPrefix("jump ") else { return nil }
        let key = String(rawValue.dropFirst(5))
        guard key.count == 1, "abcdefghijklmnopqrstuvwxyz0123456789-=".contains(key) else { return nil }
        self.key = key
        binding = bindings[key]
    }

    var rawValue: String { "jump \(key)" }

    var application: String? { binding?.app }

    var applicationSpace: Int? { binding?.space }

    var destinationSpace: Int? {
        if key == "0" { return 10 }
        if key == "-" { return 11 }
        if key == "=" { return 12 }
        return Int(key)
    }

    func matches(application name: String, space: Int) -> Bool {
        guard let binding, binding.space == nil || binding.space == space else { return false }
        return binding.match == .exact ? name == binding.app : name.contains(binding.app)
    }
}

enum SwitchCommand: String, CaseIterable {
    case nextRecentSpace = "space next-recent"
    case nextWindowInSpace = "window next-in-space"
    case previousWindowInSpace = "window previous-in-space"
    case nextWindowAcrossSpaces = "window next-across-spaces"
    case previousWindowAcrossSpaces = "window previous-across-spaces"
    case nextAppInSpace = "app next-in-space"
    case previousAppInSpace = "app previous-in-space"
    case nextAppAcrossSpaces = "app next-across-spaces"
    case previousAppAcrossSpaces = "app previous-across-spaces"

    var applications: Bool { rawValue.hasPrefix("app ") }
    var acrossSpaces: Bool { rawValue.hasSuffix("across-spaces") }
    var backwards: Bool { rawValue.contains("previous-") }
}

enum PanelCommand: String, CaseIterable {
    case show = "panel show"
    case hide = "panel hide"
    case toggle = "panel toggle"
    case activateSelected = "panel activate-selected"
    case activateSelectedOrShow = "panel activate-selected-or-show"

    enum Operation: Equatable {
        case show, hide, activateSelected, none
    }

    func operation(isVisible: Bool) -> Operation {
        switch self {
        case .show: return isVisible ? .none : .show
        case .hide: return isVisible ? .hide : .none
        case .toggle: return isVisible ? .hide : .show
        case .activateSelected: return isVisible ? .activateSelected : .none
        case .activateSelectedOrShow: return isVisible ? .activateSelected : .show
        }
    }
}

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
    case confirmOrShow(PanelPositioning)
}

/// Additional behaviors to apply after showing panel
enum PanelModifiers: Equatable {
    case none
    case moveCursorToPanel
    case moveCursorToGridCenter
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
    func confirmPanelSelection()
    func handleKeyEvent(_ event: NSEvent) -> Bool
}
