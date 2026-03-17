//
//  ThumbnailCache.swift
//  YabaiIndicator
//
//  In-memory LRU cache for screen thumbnails.
//

import Foundation
import Cocoa

// Notification posted when a thumbnail is cached
extension Notification.Name {
    static let thumbnailDidCache = Notification.Name("thumbnailDidCache")
}

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
            // Move to end of access order (most recently used)
            accessOrder.removeAll { $0 == spaceId }
            accessOrder.append(spaceId)
            return image
        }
        return nil
    }

    /// Set thumbnail for a space, evicting oldest if necessary
    func set(spaceId: UInt64, image: NSImage) {
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

        // Post notification so views can reload
        NotificationCenter.default.post(
            name: .thumbnailDidCache,
            object: nil,
            userInfo: ["spaceId": spaceId]
        )
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
