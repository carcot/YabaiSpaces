//
//  NativeClient.swift
//  YabaiIndicator
//
//  Created by Max Zhao on 03/01/2022.
//

import Foundation
import ColorSync


// MARK: - Error Types

enum NativeError: Error, LocalizedError {
    case displayQueryFailed(String)
    case spaceQueryFailed(String)
    case apiUnavailable(String)
    
    var errorDescription: String? {
        switch self {
        case .displayQueryFailed(let message):
            return "Failed to query displays: \(message)"
        case .spaceQueryFailed(let message):
            return "Failed to query spaces: \(message)"
        case .apiUnavailable(let message):
            return "macOS API unavailable: \(message)"
        }
    }
}

class NativeClient {
    let gConnection = SLSMainConnectionID()
    
    /**
    Return a list of spaces without using Yabai
     */
    func querySpaces() -> [Space] {
        do {
            let activeDisplayUUID = SLSCopyActiveMenuBarDisplayIdentifier(gConnection).takeRetainedValue() as String

            let displays = SLSCopyManagedDisplaySpaces(gConnection).takeRetainedValue() as [AnyObject]

            var spaceIncr = 0
            var totalSpaces = 0
            var spaces:[Space] = []
            for (dindex, display) in displays.enumerated() {
                let displaySpaces = display["Spaces"] as? [NSDictionary] ?? []
                let current = display["Current Space"] as? NSDictionary
                let currentId64 = current?["id64"] as? UInt64 ?? 0
                let displayUUID = display["Display Identifier"] as? String ?? ""
                let activeDisplay = activeDisplayUUID == displayUUID

                for nsSpace:NSDictionary in displaySpaces {
                    let spaceId = nsSpace["id64"] as? UInt64 ?? 0
                    let spaceUUID = nsSpace["uuid"] as? String ?? ""

                    let visible = spaceId == currentId64
                    let active = visible && activeDisplay
                    let spaceType = nsSpace["type"] as? Int ?? 0

                    var spaceIndex = 0
                    totalSpaces += 1
                    if spaceType == 0 {
                        spaceIncr += 1
                        spaceIndex = spaceIncr
                    }

                    spaces.append(Space(spaceid: spaceId, uuid: spaceUUID, visible: visible, active: active, display: dindex + 1, index: spaceIndex, yabaiIndex: totalSpaces, type: SpaceType(rawValue: spaceType) ?? SpaceType.standard))
                }
            }
            
            if spaces.isEmpty {
                NSLog("[YabaiSpaces] Warning: No spaces found - may indicate SkyLight API failure")
            }
            
            return spaces
        } catch {
            NSLog("[YabaiSpaces] SkyLight API error in querySpaces: \(error.localizedDescription)")
            return [] // Graceful degradation
        }
    }
    
    func queryDisplays() -> [Display] {
        do {
            let rawUuids = SLSCopyManagedDisplays(gConnection).takeRetainedValue() as? [CFString];
            
            var displays:[Display] = []
            if let uuids = rawUuids {
                for (i, displayUuid) in uuids.enumerated() {
                    let cfuuid = CFUUIDCreateFromString(nil, displayUuid)
                    let did = CGDisplayGetDisplayIDFromUUID(cfuuid)
                    let bounds = CGDisplayBounds(did)
                    displays.append(Display(id: UInt64(did), uuid: displayUuid as String, index: i, frame: bounds))
                }
            }
            
            if displays.isEmpty {
                NSLog("[YabaiSpaces] Warning: No displays found - may indicate CGDisplay API failure")
            }
            
            return displays
        } catch {
            NSLog("[YabaiSpaces] CGDisplay API error in queryDisplays: \(error.localizedDescription)")
            return [] // Graceful degradation
        }
    }
}

let gNativeClient = NativeClient()
