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

struct ScreenshotRequest {
    let displayID: CGDirectDisplayID
    let targetSize: CGSize
    var excludedWindowIDs: Set<CGWindowID> = []
}

enum ScreenshotFailure: Error, Equatable {
    case invalidRequest
    case captureUnavailable
    case encodingFailed
}

private typealias CreateWindowImage = @convention(c) (CGRect, CFArray?, UInt32) -> Unmanaged<CGImage>?

private final class ScreenshotBackend {
    private var createWindowImage: CreateWindowImage?

    init() {
        if let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_LAZY) {
            defer { dlclose(handle) }
            if let symbol = dlsym(handle, "CGWindowListCreateImageFromArray") {
                createWindowImage = unsafeBitCast(symbol, to: CreateWindowImage.self)
            }
        }
    }

    func capture(_ request: ScreenshotRequest) -> CGImage? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        if request.excludedWindowIDs.isEmpty {
            return CGDisplayCreateImage(request.displayID)
        }
        guard let createWindowImage,
              let records = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]],
              let windows = CFArrayCreateMutable(nil, 0, nil) else { return nil }
        for record in records {
            guard let identifier = (record[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  identifier > 0, !request.excludedWindowIDs.contains(identifier) else { continue }
            CFArrayAppendValue(windows, UnsafeRawPointer(bitPattern: UInt(identifier)))
        }
        guard CFArrayGetCount(windows) > 0 else { return nil }
        return createWindowImage(CGDisplayBounds(request.displayID), windows, 0)?.takeRetainedValue()
    }
}

private enum CaptureImageProcessing {
    static func scale(_ image: CGImage, to size: CGSize) -> CGImage? {
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

    static func png(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination), data.length > 0 else { return nil }
        return data as Data
    }
}

final class ScreenshotCaptureService {
    private let captureQueue = DispatchQueue(label: "yabai-indicator.capture", qos: .userInitiated)
    private let captureImage: (ScreenshotRequest) -> CGImage?
    private let encodePNG: (CGImage) -> Data?

    init() {
        let backend = ScreenshotBackend()
        captureImage = backend.capture
        encodePNG = CaptureImageProcessing.png
    }

    init(captureImage: @escaping (ScreenshotRequest) -> CGImage?, encodePNG: @escaping (CGImage) -> Data?) {
        self.captureImage = captureImage
        self.encodePNG = encodePNG
    }

    private func isActiveDisplay(_ identifier: CGDirectDisplayID) -> Bool {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return false }
        var identifiers = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &identifiers, &count) == .success else { return false }
        return identifiers.prefix(Int(count)).contains(identifier)
    }

    func capture(_ request: ScreenshotRequest) -> Result<Data, ScreenshotFailure> {
        captureQueue.sync {
            autoreleasepool {
                let size = request.targetSize
                guard request.displayID != 0,
                      size.width.isFinite, size.height.isFinite,
                      size.width >= 1, size.height >= 1, size.width <= 8192, size.height <= 8192,
                      size.width * size.height <= 16_777_216,
                      !request.excludedWindowIDs.contains(0), isActiveDisplay(request.displayID) else {
                    return .failure(.invalidRequest)
                }
                guard let image = captureImage(request),
                      let scaled = CaptureImageProcessing.scale(image, to: size) else {
                    return .failure(.captureUnavailable)
                }
                guard let data = encodePNG(scaled), !data.isEmpty else { return .failure(.encodingFailed) }
                return .success(data)
            }
        }
    }
}

private let screenshotCaptureService = ScreenshotCaptureService()

class PrivateWindowCapture {
    private var cachedWallpaperData: Data?
    private var cachedWallpaperSize: CGSize?
    private var cacheVersion = 0

    private func scaleImage(_ image: CGImage, to size: CGSize) -> CGImage? {
        CaptureImageProcessing.scale(image, to: size)
    }

    /// Capture just the desktop wallpaper for a display (no windows)
    /// Returns NSImage for compatibility with existing code
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
    /// Capture desktop wallpaper and return CGImage directly (avoid NSImage wrapper leak)
    /// Capture desktop wallpaper and return CGImage directly (avoid NSImage wrapper leak)
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

        // Clear cache on failure to ensure fresh attempts next time
        clearCaches()
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
        CaptureImageProcessing.png(cgImage) ?? Data()
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
        
        // Try all screens to find the desktop wallpaper
        // This is necessary because NSScreen.main only works for the primary display
        let screens = NSScreen.screens
        
        for screen in screens {
            if let wallpaperURL = workspace.desktopImageURL(for: screen) {
                if let imageSource = CGImageSourceCreateWithURL(wallpaperURL as CFURL, nil) {
                    // Load the image at full resolution
                    guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                        continue
                    }

                    // Scale to target size if needed
                    if cgImage.width == Int(targetSize.width) && cgImage.height == Int(targetSize.height) {
                        return cgImage
                    } else {
                        return scaleImage(cgImage, to: targetSize)
                    }
                }
            }
        }

        return nil
    }

    func captureSpace(display: Display, targetSize: CGSize, excludingWindowIDs: Set<CGWindowID> = []) -> Data? {
        guard let identifier = CGDirectDisplayID(exactly: display.id) else { return nil }
        let request = ScreenshotRequest(displayID: identifier, targetSize: targetSize,
                                        excludedWindowIDs: excludingWindowIDs)
        guard case .success(let data) = screenshotCaptureService.capture(request) else { return nil }
        return data
    }
}

// MARK: - Global Instance

let gPrivateWindowCapture = PrivateWindowCapture()
