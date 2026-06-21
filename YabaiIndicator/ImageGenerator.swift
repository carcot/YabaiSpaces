//
//  ImageGenerator.swift
//  YabaiIndicator
//
//  Created by Max Zhao on 29/12/2021.
//
import Foundation
import Cocoa
import SwiftUI
import ImageIO
import UniformTypeIdentifiers

// MARK: - CGImage to PNG conversion

private func cgImageToPNG(_ cgImage: CGImage) -> Data {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data, kUTTypePNG, 1, nil) else {
        return Data()
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    CGImageDestinationFinalize(destination)
    return data as Data
}

// MARK: - CGImage-based rendering (leak-free)

private func createCGContext(size: CGSize) -> CGContext {
    return CGContext(
        data: nil,
        width: Int(size.width),
        height: Int(size.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
    )!
}

// Cache that stores CGImage directly, avoiding NSImage wrapping
// Each cache entry holds a single CGImage that's explicitly managed
struct CachedCGImage {
    let cgImage: CGImage
    let size: CGSize
    let isTemplate: Bool

    init(cgImage: CGImage, size: CGSize, isTemplate: Bool = false) {
        self.cgImage = cgImage
        self.size = size
        self.isTemplate = isTemplate
    }
}

private func drawRoundedRect(context: CGContext, rect: CGRect, radius: CGFloat, color: CGColor) {
    context.setFillColor(color)
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
    context.fillPath()
}

private func drawText(context: CGContext, symbol: String, color: CGColor, size: CGSize, fontSize: CGFloat) {
    let attributedString = NSAttributedString(
        string: symbol,
        attributes: [
            .font: NSFont.systemFont(ofSize: fontSize),
            .foregroundColor: NSColor(cgColor: color)!
        ]
    )

    let boundingBox = attributedString.size()
    let x = (size.width - boundingBox.width) / 2
    let y = (size.height - boundingBox.height) / 2

    let ctLine = CTLineCreateWithAttributedString(attributedString)
    context.textPosition = CGPointMake(x, size.height - y - boundingBox.height)
    CTLineDraw(ctLine, context)
}

// MARK: - Numeric style

func generateImage(symbol: NSString, active: Bool, visible: Bool, scale: CGFloat = 1.0) -> NSImage {
    let key = NumericImageKey(symbol: String(symbol), active: active, visible: visible, scale: scale)
    if let cached = gButtonImageCache.getNumeric(key: key) {
        return cached
    }
    let (data, size) = generateImageImplCG(symbol: symbol, active: active, visible: visible, scale: scale)
    gButtonImageCache.setNumeric(key: key, data: data, size: size, isTemplate: true)
    return NSImage(data: data)!
}

private func generateImageImplCG(symbol: NSString, active: Bool, visible: Bool, scale: CGFloat = 1.0) -> (Data, CGSize) {
    return autoreleasepool {
        let size = CGSize(width: 28 * scale, height: 20 * scale)
        let cornerRadius: CGFloat = 6 * scale
        let fontSize: CGFloat = 13 * scale

        let context = createCGContext(size: size)
        let rect = CGRect(origin: .zero, size: size)
        let blackColor = NSColor.black.cgColor

        context.clear(rect)

        if active || visible {
            // Create background
            drawRoundedRect(context: context, rect: rect, radius: cornerRadius, color: blackColor)

            // Create inverse text mask by drawing text with destinationOut blend mode
            // This creates the cutout effect without intermediate CGImage
            context.saveGState()
            context.setBlendMode(.destinationOut)
            context.setAlpha(active ? 1.0 : 0.8)
            drawText(context: context, symbol: String(symbol), color: blackColor, size: size, fontSize: fontSize)
            context.restoreGState()
        } else {
            // Outline only
            context.setStrokeColor(blackColor)
            let insetRect = rect.insetBy(dx: 0.5, dy: 0.5)
            let path = CGPath(roundedRect: insetRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            context.addPath(path)
            context.strokePath()

            drawText(context: context, symbol: String(symbol), color: blackColor, size: size, fontSize: fontSize)
        }

        // Convert CGImage to PNG data immediately
        if let cgImage = context.makeImage() {
            let pngData = cgImageToPNG(cgImage)
            if !pngData.isEmpty {
                return (pngData, size)
            }
        }

        // Fallback - create empty PNG
        let fallbackContext = createCGContext(size: size)
        fallbackContext.clear(rect)
        if let cgImage = fallbackContext.makeImage() {
            return (cgImageToPNG(cgImage), size)
        }

        return (Data(), size)
    }
}

// MARK: - Windows style

func drawWindows(in content: NSRect, windows: [Window], display: Display) {
    let displaySize = display.frame.size
    let displayOrigin = display.frame.origin
    let contentSize = content.size
    let contentOrigin = content.origin
    let scale = contentSize.width / displaySize.width

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
    let windowsHash = windows.map { "\($0.id)\($0.frame.origin.x)\($0.frame.origin.y)\($0.frame.width)\($0.frame.height)" }.joined().hashValue

    let key = HybridImageKey(
        active: active,
        visible: visible,
        windowsHash: windowsHash,
        displayWidth: display.frame.width,
        displayHeight: display.frame.height,
        scale: scale
    )
    if let cached = gButtonImageCache.getHybrid(key: key) {
        return cached
    }
    let (data, size) = generateImageImplCG(active: active, visible: visible, windows: windows, display: display, scale: scale)
    gButtonImageCache.setHybrid(key: key, data: data, size: size, isTemplate: true)
    return NSImage(data: data)!
}

private func generateImageImplCG(active: Bool, visible: Bool, windows: [Window], display: Display, scale: CGFloat = 1.0) -> (Data, CGSize) {
    return autoreleasepool {
        let baseHeight: CGFloat = 20 * scale
        let aspect = display.frame.width / display.frame.height
        let size = CGSize(width: baseHeight * aspect, height: baseHeight)

        let context = createCGContext(size: size)
        let rect = CGRect(origin: .zero, size: size)
        let insetRect = rect.insetBy(dx: 4 * scale, dy: 4 * scale)
        let cornerRadius: CGFloat = 6 * scale
        let blackColor = NSColor.black.cgColor

        context.clear(rect)

        if active || visible {
            drawRoundedRect(context: context, rect: rect, radius: cornerRadius, color: blackColor)
            context.saveGState()
            context.clip(to: insetRect)
            drawWindowsCG(context: context, windows: windows, display: display, targetSize: size)
            context.restoreGState()
        } else {
            context.setStrokeColor(blackColor)
            let strokeRect = rect.insetBy(dx: 0.5, dy: 0.5)
            let path = CGPath(roundedRect: strokeRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            context.addPath(path)
            context.strokePath()

            context.saveGState()
            context.clip(to: insetRect)
            drawWindowsCG(context: context, windows: windows, display: display, targetSize: size)
            context.restoreGState()
        }

        // Convert CGImage to PNG data immediately
        if let cgImage = context.makeImage() {
            let pngData = cgImageToPNG(cgImage)
            if !pngData.isEmpty {
                return (pngData, size)
            }
        }

        // Fallback
        let fallbackContext = createCGContext(size: size)
        fallbackContext.clear(rect)
        if let cgImage = fallbackContext.makeImage() {
            return (cgImageToPNG(cgImage), size)
        }

        return (Data(), size)
    }
}

private func drawWindowsCG(context: CGContext, windows: [Window], display: Display, targetSize: CGSize) {
    let displaySize = display.frame.size
    let displayOrigin = display.frame.origin
    let scale = targetSize.width / displaySize.width

    for window in windows.reversed() {
        let fixedOrigin = CGPoint(
            x: window.frame.origin.x - displayOrigin.x,
            y: displaySize.height - (window.frame.origin.y - displayOrigin.y + window.frame.height)
        )
        let windowRect = CGRect(
            x: fixedOrigin.x * scale,
            y: fixedOrigin.y * scale,
            width: window.frame.width * scale,
            height: window.frame.height * scale
        )

        context.setFillColor(NSColor.black.cgColor)
        context.fill(windowRect)

        context.saveGState()
        context.setBlendMode(.destinationOut)
        context.setStrokeColor(NSColor.black.cgColor)
        context.stroke(windowRect.insetBy(dx: 0.75, dy: 0.75))
        context.restoreGState()
    }
}

// MARK: - Hybrid Preview Style (Desktop + Window Outlines)

private func drawWindowOutlines(context: CGContext, windows: [Window], display: Display, targetSize: CGSize) {
    let displaySize = display.frame.size
    let displayOrigin = display.frame.origin
    let scale = targetSize.width / displaySize.width

    for window in windows.reversed() {
        let fixedOrigin = CGPoint(
            x: window.frame.origin.x - displayOrigin.x,
            y: displaySize.height - (window.frame.origin.y - displayOrigin.y + window.frame.height)
        )
        let windowRect = CGRect(
            x: fixedOrigin.x * scale,
            y: fixedOrigin.y * scale,
            width: window.frame.width * scale,
            height: window.frame.height * scale
        )

        context.setStrokeColor(NSColor.white.cgColor)
        context.stroke(windowRect)
    }
}

func generateHybridPreviewImage(active: Bool, visible: Bool, windows: [Window], display: Display, scale: CGFloat = 1.0) -> NSImage {
    let windowsHash = windows.map { "\($0.id)\($0.frame.origin.x)\($0.frame.origin.y)\($0.frame.width)\($0.frame.height)" }.joined().hashValue

    let key = HybridImageKey(
        active: active,
        visible: visible,
        windowsHash: windowsHash,
        displayWidth: display.frame.width,
        displayHeight: display.frame.height,
        scale: scale
    )
    if let cached = gButtonImageCache.getHybrid(key: key) {
        return cached
    }

    return autoreleasepool {
        let baseHeight: CGFloat = 20 * scale
        let aspect = display.frame.width / display.frame.height
        let size = CGSize(width: baseHeight * aspect, height: baseHeight)
        let rect = CGRect(origin: .zero, size: size)

        let context = createCGContext(size: size)

        // Use solid color background (wallpaper removed to prevent CGImage leaks)
        // Window outlines provide sufficient visual feedback
        context.setFillColor(NSColor(red: 0.3, green: 0.35, blue: 0.45, alpha: 1.0).cgColor)
        context.fill(rect)

        // Draw window outlines
        drawWindowOutlines(context: context, windows: windows, display: display, targetSize: size)

        if let cgImage = context.makeImage() {
            let pngData = cgImageToPNG(cgImage)
            if !pngData.isEmpty {
                gButtonImageCache.setHybrid(key: key, data: pngData, size: size, isTemplate: false)
                return NSImage(data: pngData)!
            }
        }

        return NSImage(size: size)
    }
}
