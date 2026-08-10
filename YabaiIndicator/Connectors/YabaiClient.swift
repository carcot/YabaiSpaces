//
//  YabaiClient.swift
//  YabaiIndicator
//
//  Created by Max Zhao on 01/01/2022.
//

import SwiftUI

struct YabaiResponse {
    let error:Int
    let response:Any
}


// MARK: - Error Types

enum YabaiError: Error, LocalizedError {
    case connectionFailed(String)
    case invalidResponse(String)
    case yabaiNotRunning
    case jsonParseError(String)
    case queryFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Cannot connect to Yabai: \(message)"
        case .invalidResponse(let message):
            return "Invalid response from Yabai: \(message)"
        case .yabaiNotRunning:
            return "Yabai is not running. Start Yabai to enable window management features."
        case .jsonParseError(let message):
            return "Failed to parse Yabai response: \(message)"
        case .queryFailed(let message):
            return "Query failed: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .connectionFailed, .yabaiNotRunning:
            return "Start Yabai with: yabai --start-service"
        case .invalidResponse, .jsonParseError:
            return "Check Yabai version compatibility"
        case .queryFailed:
            return "Retry the operation or check Yabai logs"
        }
    }
}

class YabaiClient {
    
    func _yabaiSocketCall(_ args: [String]) -> (Int, String) {
        var cresp:UnsafeMutablePointer<CChar>? = nil
        var cargs = args.map { strdup($0) }

        let ret = send_message(Int32(args.count), &cargs, &cresp)

        for ptr in cargs { free(ptr) }
        var response = ""
        if let r = cresp {
            response = String(cString: r)
        }
        free(cresp)
        
        // Detect specific Yabai connection errors
        if response.contains("failed to connect to socket") {
            NSLog("[YabaiSpaces] Yabai socket not found - Yabai may not be running")
        } else if response.contains("failed to open socket") {
            NSLog("[YabaiSpaces] Cannot open Yabai socket - check permissions")
        }
        
        return (Int(ret), response)
    }
    
    @discardableResult
    func yabaiSocketCall(_ args: String...) throws -> YabaiResponse {
        let (e, m) = _yabaiSocketCall(args)
        var resp: Any = []
        
        // Check for connection errors
        if e != EXIT_SUCCESS {
            if m.contains("failed to connect") || m.contains("failed to open socket") {
                throw YabaiError.yabaiNotRunning
            }
            throw YabaiError.connectionFailed(m)
        }
        
        if m.count > 0 {
            if let data = m.data(using: .utf8) {
                do {
                    resp = try JSONSerialization.jsonObject(with: data, options: [])
                } catch {
                    NSLog("[YabaiSpaces] JSON parse error: \(error.localizedDescription)")
                    throw YabaiError.jsonParseError("JSON parsing failed: \(error.localizedDescription)")
                }
            }
        }
        let r = YabaiResponse(error: e, response: resp)
        return r
    }
    
    func focusSpace(index: Int) throws {
        try yabaiSocketCall(
            "-m", "space", "--focus", "\(index)")
    }

    func focusWindow(id: UInt64) throws {
        try yabaiSocketCall(
            "-m", "window", "--focus", "\(id)")
    }

    func queryWindows() throws -> [Window] {
        do {
            let response = try yabaiSocketCall("-m", "query", "--windows")
            
            guard let r = response.response as? [[String: Any]] else {
                NSLog("[YabaiSpaces] Invalid response format - expected array of dictionaries")
                throw YabaiError.invalidResponse("Expected array of window dictionaries")
            }
            
            let windows = r.compactMap { (dict: [String: Any]) -> Window? in
                // Safe extraction with nil coalescing and logging
                guard let id = dict["id"] as? UInt64 else {
                    NSLog("[YabaiSpaces] Missing or invalid 'id' field in window data: \(dict)")
                    return nil
                }
                guard let pid = dict["pid"] as? UInt64 else {
                    NSLog("[YabaiSpaces] Missing or invalid 'pid' field for window id \(id)")
                    return nil
                }
                guard let app = dict["app"] as? String else {
                    NSLog("[YabaiSpaces] Missing 'app' field for window id \(id)")
                    return nil
                }
                let title = dict["title"] as? String ?? ""
                guard let frameDict = dict["frame"] as? [String: Double] else {
                    NSLog("[YabaiSpaces] Missing or invalid 'frame' for window \(app)#\(id)")
                    return nil
                }
                let x = frameDict["x"] ?? 0
                let y = frameDict["y"] ?? 0
                let w = frameDict["w"] ?? 0
                let h = frameDict["h"] ?? 0
                guard w > 0 && h > 0 else {
                    NSLog("[YabaiSpaces] Invalid frame dimensions for window \(app)#\(id): \(w)x\(h)")
                    return nil
                }
                let displayIndex = dict["display"] as? Int ?? 0
                let spaceIndex = dict["space"] as? Int ?? 0
                
                return Window(
                    id: id,
                    pid: pid,
                    app: app,
                    title: title,
                    frame: NSRect(x: x, y: y, width: w, height: h),
                    displayIndex: displayIndex,
                    spaceIndex: spaceIndex
                )
            }
            
            if windows.isEmpty && r.count > 0 {
                NSLog("[YabaiSpaces] All windows filtered out due to invalid data")
            }
            
            return windows
        } catch let error as YabaiError {
            throw error
        } catch {
            NSLog("[YabaiSpaces] Unexpected error in queryWindows: \(error.localizedDescription)")
            throw YabaiError.queryFailed(error.localizedDescription)
        }
    }
}

let gYabaiClient = YabaiClient()
