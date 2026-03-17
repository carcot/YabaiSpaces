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

    /// Number of columns in the grid (default 4)
    let columnCount: Int

    /// Number of rows in the grid (default 2)
    let rowCount: Int

    /// Create layout with explicit parameters
    init(scale: CGFloat, columnCount: Int = 4, rowCount: Int = 3) {
        self.scale = scale
        self.columnCount = max(1, min(12, columnCount))  // Clamp to reasonable range
        self.rowCount = max(1, min(6, rowCount))        // Clamp to reasonable range
    }

    /// Create layout reading scale and grid size from UserDefaults
    init(from defaults: UserDefaults = .standard) {
        let storedScale = defaults.float(forKey: "panelScale")
        self.scale = storedScale > 0 ? CGFloat(storedScale) : 1.0
        self.columnCount = max(1, min(12, defaults.integer(forKey: "panelColumns")))
        self.rowCount = max(1, min(6, defaults.integer(forKey: "panelRows")))
    }

    /// Create layout with default scale (1.0) and default grid size (4x3)
    init() {
        self.scale = 1.0
        self.columnCount = 4
        self.rowCount = 3
    }

    /// Save current layout parameters to UserDefaults
    func save(to defaults: UserDefaults = .standard) {
        defaults.set(Float(scale), forKey: "panelScale")
        defaults.set(columnCount, forKey: "panelColumns")
        defaults.set(rowCount, forKey: "panelRows")
    }

    // MARK: - Grid Layout
    var columns: [GridItem] {
        Array(repeating: GridItem(.fixed(columnWidth), spacing: columnSpacing), count: columnCount)
    }

    // MARK: - Dimensions (scaled from base values)
    var columnWidth: CGFloat { 32 * scale }
    var columnSpacing: CGFloat { 2 * scale }
    var buttonHeight: CGFloat { 20 * scale }
    var rowSpacing: CGFloat { 4 * scale }
    var padding: CGFloat { 4 * scale }

    // MARK: - Image Generation
    var baseImageHeight: CGFloat { 20 * scale }

    var imageSize: CGSize {
        CGSize(width: 28 * scale, height: baseImageHeight)
    }

    var imageCornerRadius: CGFloat { 6 * scale }

    var fontSize: CGFloat { 13 * scale }

    // MARK: - Panel Size
    var panelSize: CGSize {
        let contentWidth = CGFloat(columnCount) * columnWidth + CGFloat(columnCount - 1) * columnSpacing
        let contentHeight = buttonHeight * CGFloat(rowCount) + rowSpacing * CGFloat(rowCount - 1)
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
