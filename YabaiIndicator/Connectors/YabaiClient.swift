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

        defer {
            for ptr in cargs { free(ptr) }
            if let r = cresp { free(r) }
        }

        let ret = send_message(Int32(args.count), &cargs, &cresp)

        var response = ""
        if let r = cresp {
            response = String(cString: r)
        }
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
            let windows = r.compactMap { dict -> Window? in
                // Safely extract each field with defensive programming
                guard let id = dict["id"] as? UInt64,
                      let pid = dict["pid"] as? UInt64,
                      let app = dict["app"] as? String,
                      let title = dict["title"] as? String,
                      let display = dict["display"] as? Int,
                      let space = dict["space"] as? Int,
                      let frame = dict["frame"] as? [String: Double],
                      let x = frame["x"],
                      let y = frame["y"],
                      let w = frame["w"],
                      let h = frame["h"] else {
                    return nil // Skip malformed entries
                }
                
                return Window(id: id, pid: pid, app: app, title: title,
                             frame: NSRect(x: x, y: y, width: w, height: h),
                             displayIndex: display, spaceIndex: space)
            }
            return windows
        }
        return []
    }
}

let gYabaiClient = YabaiClient()
