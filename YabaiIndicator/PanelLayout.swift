//
//  PanelLayout.swift
//  YabaiIndicator
//
//  Single source of truth for panel layout dimensions.
//

import Foundation
import SwiftUI

struct PanelLayout {
    /// Scale factor (1.0 = default, larger = bigger UI)
    let scale: CGFloat

    /// Create layout with explicit scale
    init(scale: CGFloat) {
        self.scale = scale
    }

    /// Create layout reading scale from UserDefaults
    init(from defaults: UserDefaults = .standard) {
        let storedScale = defaults.float(forKey: "panelScale")
        self.scale = storedScale > 0 ? CGFloat(storedScale) : 1.0
    }

    /// Create layout with default scale (1.0)
    init() {
        self.scale = 1.0
    }

    /// Save current scale to UserDefaults
    func save(to defaults: UserDefaults = .standard) {
        defaults.set(Float(scale), forKey: "panelScale")
    }

    // MARK: - Grid Layout
    var columns: [GridItem] {
        [
            GridItem(.fixed(columnWidth), spacing: columnSpacing),
            GridItem(.fixed(columnWidth), spacing: columnSpacing),
            GridItem(.fixed(columnWidth), spacing: columnSpacing),
            GridItem(.fixed(columnWidth), spacing: columnSpacing)
        ]
    }

    var columnCount: Int { 4 }

    // MARK: - Dimensions (scaled from base values)
    var columnWidth: CGFloat { 32 * scale }
    var columnSpacing: CGFloat { 2 * scale }
    var buttonHeight: CGFloat { 20 * scale }
    var rowSpacing: CGFloat { 4 * scale }
    var padding: CGFloat { 4 * scale }

    // MARK: - Image Generation
    var imageSize: CGSize {
        CGSize(width: 28 * scale, height: 20 * scale)
    }

    var imageCornerRadius: CGFloat { 6 * scale }

    var fontSize: CGFloat { 13 * scale }

    // MARK: - Panel Size
    var panelSize: CGSize {
        let contentWidth = CGFloat(columnCount) * columnWidth + CGFloat(columnCount - 1) * columnSpacing
        let contentHeight = buttonHeight * 2 + rowSpacing // Default 2 rows
        return CGSize(
            width: contentWidth + padding * 2,
            height: contentHeight + padding * 2
        )
    }

    // MARK: - Divider
    var dividerHeight: CGFloat { 14 * scale }

    /// Calculate scale from screen height
    /// - Parameter screenHeight: Height of the screen in points
    /// - Returns: Scale factor (0.8 to 1.5 range)
    static func scale(from screenHeight: CGFloat) -> CGFloat {
        // Base scale on 1080p (typical) screen height
        let baseHeight: CGFloat = 1080
        let calculatedScale = screenHeight / baseHeight

        // Clamp to reasonable range
        return max(0.8, min(1.5, calculatedScale))
    }
}
