//
//  PrivateWindowCapture.swift
//  YabaiIndicator
//
//  Screen thumbnail capture using private WindowServer APIs.
//

import Foundation
import Cocoa
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Private API function types
typealias CGWindowListCreateImageFn = @convention(c) (CGRect, CFArray?, UInt32) -> CGImage?
typealias CGWindowListCreateImageFromRectFn = @convention(c) (CGRect, CFArray?, UInt32, CGRect) -> CGImage?

class PrivateWindowCapture {
    private let captureQueue = DispatchQueue(label: "yabai-indicator.capture", qos: .userInitiated)

    // Cached wallpaper PNG data (not CGImage to avoid retention leaks)
    private var cachedWallpaperData: Data?
    private var cachedWallpaperSize: CGSize?
    private var cacheVersion = 0

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
        if let cgWindowListCreateImage = cgWindowListCreateImage {
            let bounds = CGRect(origin: .zero, size: CGDisplayBounds(displayID).size)
            if let image = cgWindowListCreateImage(bounds, nil, 0) {
                return scaleImage(image, to: targetSize)
            }
        }
        return nil
    }

    /// Capture just the desktop wallpaper for a display (no windows)
    /// Returns NSImage for compatibility with existing code
    func captureDesktop(display: Display, targetSize: CGSize) -> NSImage? {
        // Return cached wallpaper if size matches
        if let data = cachedWallpaperData, cachedWallpaperSize == targetSize {
            return NSImage(data: data)
        }

        // Cache miss - load wallpaper from file and convert to PNG
        if let cgImage = loadWallpaperCG(targetSize: targetSize) {
            let pngData = cgImageToPNG(cgImage)
            cachedWallpaperData = pngData
            cachedWallpaperSize = targetSize
            return NSImage(data: pngData)
        }

        return nil
    }

    /// Capture desktop wallpaper and return CGImage directly (avoid NSImage wrapper leak)
    func captureDesktopCG(display: Display, targetSize: CGSize) -> CGImage? {
        // Create CGImage from cached PNG data if size matches
        if let data = cachedWallpaperData, cachedWallpaperSize == targetSize {
            return cgImageFromPNG(data)
        }

        // Cache miss - load wallpaper from file and convert to PNG
        if let cgImage = loadWallpaperCG(targetSize: targetSize) {
            let pngData = cgImageToPNG(cgImage)
            cachedWallpaperData = pngData
            cachedWallpaperSize = targetSize
            return cgImageFromPNG(pngData)  // Return fresh CGImage from PNG, not original
        }

        return nil
    }

    /// Clear caches (call when wallpaper changes or to free memory)
    func clearCaches() {
        cachedWallpaperData = nil
        cachedWallpaperSize = nil
        cacheVersion += 1
    }

    // MARK: - Private helpers

    private func cgImageToPNG(_ cgImage: CGImage) -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return Data()
        }
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }

    private func cgImageFromPNG(_ data: Data) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        return cgImage
    }

    // MARK: - Private cache methods

    private func loadWallpaperCG(targetSize: CGSize) -> CGImage? {
        let workspace = NSWorkspace.shared

        // Try to get wallpaper from any screen
        if let screen = NSScreen.main,
           let wallpaperURL = workspace.desktopImageURL(for: screen) {
            if let imageSource = CGImageSourceCreateWithURL(wallpaperURL as CFURL, nil) {
                // Load the image at full resolution
                guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                    return nil
                }

                // Scale to target size if needed
                if cgImage.width == Int(targetSize.width) && cgImage.height == Int(targetSize.height) {
                    return cgImage
                } else {
                    return scaleImage(cgImage, to: targetSize)
                }
            }
        }

        return nil
    }

    /// Capture all windows for a space and composite them, returning PNG Data
    func captureSpace(windows: [Window], display: Display, targetSize: CGSize) -> Data? {
        return captureQueue.sync {
            let rect = CGRect(origin: .zero, size: targetSize)

            guard let context = CGContext(
                data: nil,
                width: Int(targetSize.width),
                height: Int(targetSize.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
            ) else {
                return nil
            }

            // Draw background color
            context.clear(rect)
            context.setFillColor(NSColor.windowBackgroundColor.cgColor)
            context.fill(rect)

            // Capture and draw desktop wallpaper
            if let displayID = getDisplayID(for: display.index),
               let desktopImage = captureDisplay(displayID: displayID, targetSize: targetSize) {
                context.draw(desktopImage, in: rect)
            }

            // Draw windows
            let scale = targetSize.width / display.frame.width
            let displayWindows = windows.filter { $0.displayIndex == (display.index + 1) }

            for window in displayWindows {
                let scaledFrame = CGRect(
                    x: window.frame.origin.x * scale,
                    y: window.frame.origin.y * scale,
                    width: window.frame.size.width * scale,
                    height: window.frame.size.height * scale
                )

                // Try to capture actual window content
                let cgBounds = CGRect(
                    x: window.frame.origin.x,
                    y: display.frame.height - window.frame.origin.y - window.frame.height,
                    width: window.frame.size.width,
                    height: window.frame.size.height
                )

                if let cgImage = captureWindow(windowID: Int(window.id), bounds: cgBounds, size: scaledFrame.size) {
                    context.draw(cgImage, in: scaledFrame)
                } else {
                    // Fallback: white rectangle with black border
                    context.setFillColor(NSColor.white.cgColor)
                    context.fill(scaledFrame)
                    context.setStrokeColor(NSColor.black.cgColor)
                    context.stroke(scaledFrame)
                }
            }

            if let finalCGImage = context.makeImage() {
                return cgImageToPNG(finalCGImage)
            }

            return nil
        }
    }
}

// MARK: - Global Instance

let gPrivateWindowCapture = PrivateWindowCapture()
