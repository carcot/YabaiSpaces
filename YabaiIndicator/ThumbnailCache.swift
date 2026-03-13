//
//  ThumbnailCache.swift
//  YabaiIndicator
//
//  In-memory LRU cache for screen thumbnails.
//

import Foundation
import Cocoa

class ThumbnailCache {
    private var cache: [UInt64: NSImage] = [:]
    private var accessOrder: [UInt64] = []
    private let maxCacheSize: Int

    init(maxCacheSize: Int = 20) {
        self.maxCacheSize = maxCacheSize
    }

    /// Get cached thumbnail for a space
    func get(spaceId: UInt64) -> NSImage? {
        if let image = cache[spaceId] {
            NSLog("Cache HIT for spaceId: \(spaceId)")
            // Move to end of access order (most recently used)
            accessOrder.removeAll { $0 == spaceId }
            accessOrder.append(spaceId)
            return image
        }
        NSLog("Cache MISS for spaceId: \(spaceId)")
        return nil
    }

    /// Set thumbnail for a space, evicting oldest if necessary
    func set(spaceId: UInt64, image: NSImage) {
        NSLog("Cache SET for spaceId: \(spaceId), cache size before: \(cache.count)")
        // Remove existing entry if present
        if cache[spaceId] != nil {
            accessOrder.removeAll { $0 == spaceId }
        }

        // Add new entry
        cache[spaceId] = image
        accessOrder.append(spaceId)

        // Evict oldest entries if over limit
        while cache.count > maxCacheSize {
            if let oldest = accessOrder.first {
                cache.removeValue(forKey: oldest)
                accessOrder.removeFirst()
            }
        }
        NSLog("Cache SET complete, cache size after: \(cache.count)")
    }

    /// Invalidate cache for a specific space
    func invalidate(spaceId: UInt64) {
        cache.removeValue(forKey: spaceId)
        accessOrder.removeAll { $0 == spaceId }
    }

    /// Clear entire cache
    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }

    /// Current cache size
    var size: Int {
        cache.count
    }
}

// MARK: - Global Instance

let gThumbnailCache = ThumbnailCache()
