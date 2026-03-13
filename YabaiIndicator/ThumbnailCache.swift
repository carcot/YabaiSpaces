//
//  ThumbnailCache.swift
//  YabaiIndicator
//
//  In-memory LRU cache for screen thumbnails.
//

import Foundation
import Cocoa

class ThumbnailCache {
    private var cache: [String: NSImage] = [:]
    private var accessOrder: [String] = []
    private let maxCacheSize: Int

    init(maxCacheSize: Int = 20) {
        self.maxCacheSize = maxCacheSize
    }

    /// Get cached thumbnail for a space
    func get(spaceUUID: String) -> NSImage? {
        if let image = cache[spaceUUID] {
            NSLog("Cache HIT for uuid: '\(spaceUUID.prefix(8))'")
            // Move to end of access order (most recently used)
            accessOrder.removeAll { $0 == spaceUUID }
            accessOrder.append(spaceUUID)
            return image
        }
        NSLog("Cache MISS for uuid: '\(spaceUUID.prefix(8))'")
        return nil
    }

    /// Set thumbnail for a space, evicting oldest if necessary
    func set(spaceUUID: String, image: NSImage) {
        NSLog("Cache SET for uuid: '\(spaceUUID.prefix(8))', cache size before: \(cache.count)")
        // Remove existing entry if present
        if cache[spaceUUID] != nil {
            accessOrder.removeAll { $0 == spaceUUID }
        }

        // Add new entry
        cache[spaceUUID] = image
        accessOrder.append(spaceUUID)

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
    func invalidate(spaceUUID: String) {
        cache.removeValue(forKey: spaceUUID)
        accessOrder.removeAll { $0 == spaceUUID }
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
