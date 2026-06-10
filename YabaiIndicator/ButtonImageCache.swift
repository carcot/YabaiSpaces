//
//  ButtonImageCache.swift
//  YabaiIndicator
//
//  LRU cache for generated button images (PNG data)
//

import Foundation
import Cocoa

// MARK: - Cache Keys

struct NumericImageKey: Hashable {
    let symbol: String
    let active: Bool
    let visible: Bool
    let scale: CGFloat
}

struct HybridImageKey: Hashable {
    let active: Bool
    let visible: Bool
    let windowsHash: Int
    let displayWidth: CGFloat
    let displayHeight: CGFloat
    let scale: CGFloat
}

// MARK: - Cache Entry

struct CacheEntry {
    let data: Data
    let size: CGSize
    let isTemplate: Bool
}

// MARK: - Image Cache

class ButtonImageCache {
    private var numericCache: [NumericImageKey: CacheEntry] = [:]
    private var hybridCache: [HybridImageKey: CacheEntry] = [:]
    private var numericAccessOrder: [NumericImageKey] = []
    private var hybridAccessOrder: [HybridImageKey] = []
    private let maxCacheSize: Int

    init(maxCacheSize: Int = 100) {
        self.maxCacheSize = maxCacheSize
    }

    private func updateNumericLRU(key: NumericImageKey) {
        numericAccessOrder.removeAll { $0 == key }
        numericAccessOrder.append(key)
    }

    private func updateHybridLRU(key: HybridImageKey) {
        hybridAccessOrder.removeAll { $0 == key }
        hybridAccessOrder.append(key)
    }

    private func evictNumericIfNeeded() {
        while numericCache.count > maxCacheSize {
            if let oldest = numericAccessOrder.first {
                numericCache.removeValue(forKey: oldest)
                numericAccessOrder.removeFirst()
            }
        }
    }

    private func evictHybridIfNeeded() {
        while hybridCache.count > maxCacheSize {
            if let oldest = hybridAccessOrder.first {
                hybridCache.removeValue(forKey: oldest)
                hybridAccessOrder.removeFirst()
            }
        }
    }

    func getNumeric(key: NumericImageKey) -> NSImage? {
        guard let entry = numericCache[key] else { return nil }
        updateNumericLRU(key: key)
        guard let nsImage = NSImage(data: entry.data) else { return nil }
        nsImage.isTemplate = entry.isTemplate
        return nsImage
    }

    func setNumeric(key: NumericImageKey, data: Data, size: CGSize, isTemplate: Bool) {
        numericCache[key] = CacheEntry(data: data, size: size, isTemplate: isTemplate)
        updateNumericLRU(key: key)
        evictNumericIfNeeded()
    }

    func getHybrid(key: HybridImageKey) -> NSImage? {
        guard let entry = hybridCache[key] else { return nil }
        updateHybridLRU(key: key)
        guard let nsImage = NSImage(data: entry.data) else { return nil }
        nsImage.isTemplate = entry.isTemplate
        return nsImage
    }

    func setHybrid(key: HybridImageKey, data: Data, size: CGSize, isTemplate: Bool) {
        hybridCache[key] = CacheEntry(data: data, size: size, isTemplate: isTemplate)
        updateHybridLRU(key: key)
        evictHybridIfNeeded()
    }

    func clear() {
        numericCache.removeAll()
        hybridCache.removeAll()
        numericAccessOrder.removeAll()
        hybridAccessOrder.removeAll()
        // Also clear wallpaper cache to free leaked CGImage resources
        gPrivateWindowCapture.clearCaches()
    }
}

let gButtonImageCache = ButtonImageCache()
