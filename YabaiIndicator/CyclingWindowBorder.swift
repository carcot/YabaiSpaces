import AppKit

final class CyclingWindowBorder {
    private static let maximumThickness: CGFloat = 3
    private var panel: NSPanel?
    private let borderLayer = CAShapeLayer()
    private var timer: Timer?
    private var windowID: UInt64?
    private var deadline: TimeInterval = 0
    var isBlocked: () -> Bool = { false }

    static func thickness(deadline: TimeInterval, now: TimeInterval) -> CGFloat {
        maximumThickness * CGFloat(min(1, max(0, (deadline - now) / WindowSwitching.timeout)))
    }

    func update(windowID: UInt64?, deadline: TimeInterval?) {
        guard let windowID, let deadline, deadline > ProcessInfo.processInfo.systemUptime else {
            clear()
            return
        }
        self.windowID = windowID
        self.deadline = deadline
        timer?.invalidate()
        let timer = Timer(timeInterval: min(0.05, deadline - ProcessInfo.processInfo.systemUptime),
                          repeats: true) { [weak self] _ in self?.refresh() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        refresh()
    }

    func hide() { panel?.orderOut(nil) }

    func clear() {
        hide()
        timer?.invalidate()
        timer = nil
        windowID = nil
        deadline = 0
    }

    private func refresh() {
        let thickness = Self.thickness(deadline: deadline, now: ProcessInfo.processInfo.systemUptime)
        guard thickness > 0, let windowID else {
            clear()
            return
        }
        guard !isBlocked() else { hide(); return }
        guard let records = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(windowID))
                as? [[String: Any]],
              let record = records.first,
              record[kCGWindowIsOnscreen as String] as? Bool == true,
              let bounds = record[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: bounds),
              frame.width > 0, frame.height > 0,
              let primary = NSScreen.screens.first else {
            clear()
            return
        }
        if panel == nil {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.ignoresMouseEvents = true
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            panel.sharingType = .none
            panel.animationBehavior = .none
            let view = NSView()
            view.wantsLayer = true
            borderLayer.fillColor = nil
            borderLayer.strokeColor = NSColor.systemOrange.cgColor
            view.layer?.addSublayer(borderLayer)
            panel.contentView = view
            self.panel = panel
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let padding = Self.maximumThickness
        panel?.setFrame(CGRect(x: frame.minX - padding, y: primary.frame.maxY - frame.maxY - padding,
                              width: frame.width + padding * 2, height: frame.height + padding * 2),
                        display: true, animate: false)
        if let bounds = panel?.contentView?.bounds {
            borderLayer.frame = bounds
            borderLayer.lineWidth = thickness
            let inset = padding - thickness / 2
            borderLayer.path = CGPath(roundedRect: bounds.insetBy(dx: inset, dy: inset),
                                      cornerWidth: 6 + thickness / 2, cornerHeight: 6 + thickness / 2,
                                      transform: nil)
        }
        CATransaction.commit()
        panel?.orderFrontRegardless()
    }

    deinit { timer?.invalidate() }
}
