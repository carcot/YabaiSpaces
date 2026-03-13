//
//  PrivateWindowCapture.swift
//  YabaiIndicator
//
//  Screen thumbnail capture using private WindowServer APIs.
//

import Foundation
import Cocoa
import CoreGraphics

// Private API function types
typealias CGWindowListCreateImageFn = @convention(c) (CGRect, CFArray?, UInt32) -> CGImage?
typealias CGWindowListCreateImageFromRectFn = @convention(c) (CGRect, CFArray?, UInt32, CGRect) -> CGImage?

class PrivateWindowCapture {
    private let captureQueue = DispatchQueue(label: "yabai-indicator.capture", qos: .userInitiated)

    // Private API function pointers
    private var cgWindowListCreateImage: CGWindowListCreateImageFn?
    private var cgWindowListCreateImageFromRect: CGWindowListCreateImageFromRectFn?

    init() {
        loadPrivateAPIs()
    }

    private func loadPrivateAPIs() {
        // Try CoreGraphics framework
        if let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY) {
            // Try various possible function names
            let functionNames = [
                "CGWindowListCreateImage",
                "_CGWindowListCreateImage",
                "CGWindowListCreateImageWithOptions",
                "_CGWindowListCreateImageWithOptions"
            ]

            for name in functionNames {
                if let symbol = dlsym(handle, name) {
                    cgWindowListCreateImage = unsafeBitCast(symbol, to: CGWindowListCreateImageFn.self)
                    break
                }
            }

            let rectFunctionNames = [
                "CGWindowListCreateImageFromRect",
                "_CGWindowListCreateImageFromRect"
            ]

            for name in rectFunctionNames {
                if let symbol = dlsym(handle, name) {
                    cgWindowListCreateImageFromRect = unsafeBitCast(symbol, to: CGWindowListCreateImageFromRectFn.self)
                    break
                }
            }

            dlclose(handle)
        }
    }

    /// Capture a single window by ID
    private func captureWindow(windowID: Int, bounds: CGRect, size: CGSize) -> CGImage? {
        let windowArray = [windowID] as CFArray

        // Use window-specific bounds, not full display
        if let cgWindowListCreateImage = cgWindowListCreateImage {
            if let image = cgWindowListCreateImage(bounds, windowArray, 0) {
                return scaleImage(image, to: size)
            }
        }

        // Try the rect-based API
        if let cgWindowListCreateImageFromRect = cgWindowListCreateImageFromRect {
            if let image = cgWindowListCreateImageFromRect(bounds, windowArray, 0, .null) {
                return scaleImage(image, to: size)
            }
        }

        return nil
    }

    /// Get CGDirectDisplayID for a display index
    private func getDisplayID(for index: Int) -> CGDirectDisplayID? {
        var displayCount: UInt32 = 0
        var result = CGGetActiveDisplayList(32, nil, &displayCount)

        guard result == .success, displayCount > 0 else { return nil }

        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        result = CGGetActiveDisplayList(32, &displayIDs, &displayCount)

        guard result == .success, index < Int(displayCount) else { return nil }

        return displayIDs[index]
    }

    private func scaleImage(_ image: CGImage, to size: CGSize) -> CGImage? {
        if image.width == Int(size.width) && image.height == Int(size.height) {
            return image
        }

        let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        )

        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(origin: .zero, size: size))

        return context?.makeImage()
    }

    /// Capture entire display content (desktop background)
    private func captureDisplay(displayID: CGDirectDisplayID, targetSize: CGSize) -> CGImage? {
        // Use CGWindowListCreateImage with nil window array to capture screen
        // windowListOption 0 = include all windows (desktop + windows)
        if let cgWindowListCreateImage = cgWindowListCreateImage {
            let bounds = CGRect(origin: .zero, size: CGDisplayBounds(displayID).size)
            if let image = cgWindowListCreateImage(bounds, nil, 0) {
                return scaleImage(image, to: targetSize)
            }
        }
        return nil
    }

    /// Capture all windows for a space and composite them
    func captureSpace(windows: [Window], display: Display, targetSize: CGSize) -> NSImage? {
        captureQueue.sync {
            let image = NSImage(size: targetSize)
            image.lockFocus()

            // Draw background color as fallback
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: targetSize).fill()

            // Always capture and draw desktop wallpaper as background
            if let displayID = getDisplayID(for: display.index),
               let desktopImage = captureDisplay(displayID: displayID, targetSize: targetSize) {
                let nsImage = NSImage(cgImage: desktopImage, size: targetSize)
                nsImage.draw(in: NSRect(origin: .zero, size: targetSize))
            }

            // Uniform scale - thumbnail now matches display aspect ratio
            let scale = targetSize.width / display.frame.width

            var windowsDrawn = 0
            var windowsCaptured = 0

            // Filter windows for this display
            let displayWindows = windows.filter { $0.displayIndex == (display.index + 1) }

            // Draw windows on top of desktop
            for window in displayWindows {
                let scaledFrame = NSRect(
                    x: window.frame.origin.x * scale,
                    y: window.frame.origin.y * scale,
                    width: window.frame.size.width * scale,
                    height: window.frame.size.height * scale
                )

                // Pass actual window bounds (not scaled) to capture API
                // Flip Y coordinate for CoreGraphics coordinate system
                let cgBounds = CGRect(
                    x: window.frame.origin.x,
                    y: display.frame.height - window.frame.origin.y - window.frame.height,
                    width: window.frame.size.width,
                    height: window.frame.size.height
                )

                // Try to capture actual window content
                if let cgImage = captureWindow(windowID: Int(window.id), bounds: cgBounds, size: scaledFrame.size) {
                    let nsImage = NSImage(cgImage: cgImage, size: scaledFrame.size)
                    nsImage.draw(in: scaledFrame)
                    windowsDrawn += 1
                    windowsCaptured += 1
                } else {
                    // Fallback: draw clean white rectangle with black border (like windows mode)
                    NSColor.white.setFill()
                    NSBezierPath(rect: scaledFrame).fill()
                    NSColor.black.setStroke()
                    NSBezierPath(rect: scaledFrame).stroke()
                    windowsDrawn += 1
                }
            }

            image.unlockFocus()

            // Add border
            let bounded = NSImage(size: targetSize)
            bounded.lockFocus()
            NSColor.black.setStroke()
            NSBezierPath(rect: NSRect(origin: .zero, size: targetSize)).stroke()
            image.draw(in: NSRect(origin: .zero, size: targetSize))
            bounded.unlockFocus()

            return bounded
        }
    }
}

// MARK: - Global Instance

let gPrivateWindowCapture = PrivateWindowCapture()
