//
//  ImageGenerator.swift
//  YabaiIndicator
//
//  Created by Max Zhao on 29/12/2021.
//
import Foundation
import Cocoa
import SwiftUI

private func drawText(symbol: NSString, color: NSColor, size: CGSize, fontSize: CGFloat) {

    let attrs:[NSAttributedString.Key : Any] = [.font: NSFont.systemFont(ofSize: fontSize), .foregroundColor: color]
    let boundingBox = symbol.size(withAttributes: attrs)
    let x:CGFloat = size.width / 2 - boundingBox.width / 2
    let y:CGFloat = size.height / 2 - boundingBox.height / 2

    symbol.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}

func generateImage(symbol: NSString, active: Bool, visible: Bool, scale: CGFloat = 1.0) -> NSImage {
    let size = CGSize(width: 28 * scale, height: 20 * scale)
    let cornerRadius: CGFloat = 6 * scale
    let fontSize: CGFloat = 13 * scale
    
    let canvas = NSRect(origin: CGPoint.zero, size: size)
    
    let image = NSImage(size: size)
    let strokeColor = NSColor.black
    
    if active || visible{
        let imageFill = NSImage(size: size)
        let imageStroke = NSImage(size: size)

        imageFill.lockFocus()
        strokeColor.setFill()
        NSBezierPath(roundedRect: canvas, xRadius: cornerRadius, yRadius: cornerRadius).fill()
        imageFill.unlockFocus()
        imageStroke.lockFocus()
        drawText(symbol: symbol, color: strokeColor, size: size, fontSize: fontSize)
        imageStroke.unlockFocus()
        
        image.lockFocus()
        imageFill.draw(in: canvas, from: NSZeroRect, operation: .sourceOut, fraction: active ? 1.0 : 0.8)
        imageStroke.draw(in: canvas, from: NSZeroRect, operation: .destinationOut, fraction: active ? 1.0 : 0.8)
        image.unlockFocus()
    } else {
        image.lockFocus()
        strokeColor.setStroke()
        let path = NSBezierPath(roundedRect: canvas.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
        path.stroke()
        drawText(symbol: symbol, color: strokeColor, size: size, fontSize: fontSize)
        image.unlockFocus()
    }
    image.isTemplate = true
    return image
}

func drawWindows(in content: NSRect, windows: [Window], display: Display) {
    let displaySize = display.frame.size
    let displayOrigin = display.frame.origin
    let contentSize = content.size
    let contentOrigin = content.origin

    // Uniform scale - content aspect ratio now matches display aspect ratio
    let scale = contentSize.width / displaySize.width

    // plot single windows
    for window in windows.reversed() {
        let fixedOrigin = NSPoint(x: window.frame.origin.x - displayOrigin.x, y: displaySize.height - (window.frame.origin.y - displayOrigin.y + window.frame.height))
        let windowRect = NSRect(
            x: contentOrigin.x + fixedOrigin.x * scale,
            y: contentOrigin.y + fixedOrigin.y * scale,
            width: window.frame.width * scale,
            height: window.frame.height * scale
        )
        let windowPath = NSBezierPath(rect: windowRect)
        windowPath.fill()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        windowPath.lineWidth = 1.5
        windowPath.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }
}

func generateImage(active: Bool, visible: Bool, windows: [Window], display: Display, scale: CGFloat = 1.0) -> NSImage {
    // Calculate size proportional to display aspect ratio
    let baseHeight: CGFloat = 20 * scale
    let aspect = display.frame.width / display.frame.height
    let size = CGSize(width: baseHeight * aspect, height: baseHeight)

    let canvas = NSRect(origin: CGPoint.zero, size: size)
    let bounds = NSBezierPath(rect: canvas.insetBy(dx: 4 * scale, dy: 4 * scale))
    let cornerRadius: CGFloat = 6 * scale


    let image = NSImage(size: size)
    let strokeColor = NSColor.black

    if active || visible{
        let imageFill = NSImage(size: size)
        let imageStroke = NSImage(size: size)

        imageFill.lockFocus()
        strokeColor.setFill()
        NSBezierPath(roundedRect: canvas, xRadius: cornerRadius, yRadius: cornerRadius).fill()
        imageFill.unlockFocus()

        imageStroke.lockFocus()
        drawWindows(in: canvas, windows: windows, display: display)
        imageStroke.unlockFocus()

        image.lockFocus()
        imageFill.draw(in: canvas, from: NSZeroRect, operation: .sourceOut, fraction: active ? 1.0 : 0.8)

        bounds.setClip()
        imageStroke.draw(in: canvas, from: NSZeroRect, operation: .destinationOut, fraction: active ? 1.0 : 0.8)
        image.unlockFocus()
    } else {
        image.lockFocus()
        strokeColor.setStroke()
        let path = NSBezierPath(roundedRect: canvas.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)
        path.stroke()

        bounds.setClip()
        drawWindows(in: canvas, windows: windows, display: display)
        image.unlockFocus()
    }
    image.isTemplate = true
    return image
}

// MARK: - Hybrid Preview Style (Desktop + Window Outlines)

/// Draw window outlines only (no fill) for hybrid preview style
private func drawWindowOutlines(in content: NSRect, windows: [Window], display: Display) {
    let displaySize = display.frame.size
    let displayOrigin = display.frame.origin
    let contentSize = content.size
    let contentOrigin = content.origin

    // Uniform scale - content aspect ratio matches display aspect ratio
    let scale = contentSize.width / displaySize.width

    // Draw each window as an outline only
    for window in windows.reversed() {
        let fixedOrigin = NSPoint(x: window.frame.origin.x - displayOrigin.x, y: displaySize.height - (window.frame.origin.y - displayOrigin.y + window.frame.height))
        let windowRect = NSRect(
            x: contentOrigin.x + fixedOrigin.x * scale,
            y: contentOrigin.y + fixedOrigin.y * scale,
            width: window.frame.width * scale,
            height: window.frame.height * scale
        )
        let windowPath = NSBezierPath(rect: windowRect)

        // Draw outline with contrasting color
        NSColor.white.setStroke()
        windowPath.lineWidth = 1.0
        windowPath.stroke()
    }
}

/// Generate a hybrid preview image with desktop background and window outlines
/// Used for spaces without cached thumbnails
/// No border - borders are handled by SwiftUI overlay for cleaner styling
func generateHybridPreviewImage(active: Bool, visible: Bool, windows: [Window], display: Display, scale: CGFloat = 1.0) -> NSImage {
    // Calculate size proportional to display aspect ratio
    let baseHeight: CGFloat = 20 * scale
    let aspect = display.frame.width / display.frame.height
    let size = CGSize(width: baseHeight * aspect, height: baseHeight)

    let canvas = NSRect(origin: CGPoint.zero, size: size)

    let image = NSImage(size: size)

    image.lockFocus()

    // Try to capture desktop wallpaper as background
    let desktopCaptured = gPrivateWindowCapture.captureDesktop(display: display, targetSize: size)

    if active || visible {
        // Draw desktop wallpaper if available, otherwise use fallback color
        if let desktop = desktopCaptured {
            desktop.draw(in: canvas)
        } else {
            NSColor(red: 0.3, green: 0.35, blue: 0.45, alpha: 1.0).setFill()
            NSBezierPath(rect: canvas).fill()
        }

        // Draw window outlines
        drawWindowOutlines(in: canvas, windows: windows, display: display)
    } else {
        // Draw desktop wallpaper if available, otherwise use fallback color
        if let desktop = desktopCaptured {
            desktop.draw(in: canvas)
        } else {
            NSColor(red: 0.5, green: 0.5, blue: 0.55, alpha: 1.0).setFill()
            NSBezierPath(rect: canvas).fill()
        }

        // Draw window outlines
        drawWindowOutlines(in: canvas, windows: windows, display: display)
    }

    image.unlockFocus()
    image.isTemplate = false  // Not a template - has actual colors
    return image
}
