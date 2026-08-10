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
        return (Int(ret), response)
    }
    
    @discardableResult
    func yabaiSocketCall(_ args: String...) -> YabaiResponse {
        let (e, m) = _yabaiSocketCall(args)
        var resp: Any = []
        if m.count > 0 {
            if let data = m.data(using: .utf8) {
                do {
                    resp = try JSONSerialization.jsonObject(with: data, options: [])
                } catch {
                    // JSON parsing error
                }
            }
        }
        let r = YabaiResponse(error: e, response: resp)
        return r
    }
    
    func focusSpace(index: Int) {
        yabaiSocketCall(
            "-m", "space", "--focus", "\(index)")
    }

    func focusWindow(id: UInt64) {
        yabaiSocketCall(
            "-m", "window", "--focus", "\(id)")
    }

    func queryWindows() -> [Window] {
        if let r = yabaiSocketCall("-m", "query", "--windows").response as? [[String: Any]] {
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
            return windows
        }
        NSLog("[YabaiSpaces] Failed to get windows from Yabai or invalid response format")
        return []
    }
}

let gYabaiClient = YabaiClient()
