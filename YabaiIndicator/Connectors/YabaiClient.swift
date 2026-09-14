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

        // Ensure cleanup happens even if errors occur
        defer {
            for ptr in cargs { free(ptr) }
            if let resp = cresp { free(resp) }
        }

        let ret = send_message(Int32(args.count), &cargs, &cresp)

        var response = ""
        if let r = cresp {
            response = String(cString: r)
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

final class WindowSwitchController {
    private let queue = DispatchQueue(label: "YabaiSpaces.window-switching")
    private var switching = WindowSwitching()
    private let client = YabaiClient()

    private func windows() throws -> [NavigationWindow] {
        let response = try client.yabaiSocketCall("-m", "query", "--windows")
        guard let records = response.response as? [[String: Any]] else {
            throw YabaiError.invalidResponse("Expected navigation window records")
        }
        return records.compactMap(NavigationWindow.init)
    }

    private func currentSpace() throws -> Int {
        let response = try client.yabaiSocketCall("-m", "query", "--spaces", "--space")
        guard let record = response.response as? [String: Any], let index = record["index"] as? Int else {
            throw YabaiError.invalidResponse("Expected current Space index")
        }
        return index
    }

    func observe() {
        queue.async {
            do {
                self.switching.observe(try self.windows(), now: ProcessInfo.processInfo.systemUptime)
            } catch {
                NSLog("[YabaiSpaces] MRU observation failed: \(error.localizedDescription)")
            }
        }
    }

    func execute(_ command: SwitchCommand) {
        queue.async {
            do {
                let windows = try self.windows()
                let space = try self.currentSpace()
                guard let target = self.switching.target(command, windows: windows, currentSpace: space,
                                                        now: ProcessInfo.processInfo.systemUptime) else { return }
                if target.space != space {
                    try self.client.focusSpace(index: target.space)
                    let deadline = ProcessInfo.processInfo.systemUptime + 1
                    while try self.currentSpace() != target.space {
                        guard ProcessInfo.processInfo.systemUptime < deadline else {
                            throw YabaiError.queryFailed("Space transition did not complete")
                        }
                        Thread.sleep(forTimeInterval: 0.02)
                    }
                }
                guard try self.windows().contains(where: { $0.id == target.id && $0.space == target.space }) else {
                    throw YabaiError.queryFailed("Target window closed or moved during switching")
                }
                try self.client.focusWindow(id: target.id)
                let deadline = ProcessInfo.processInfo.systemUptime + 1
                var observed = try self.windows()
                while !observed.contains(where: { $0.id == target.id && $0.focused }) {
                    guard ProcessInfo.processInfo.systemUptime < deadline else {
                        throw YabaiError.queryFailed("Window focus did not complete")
                    }
                    Thread.sleep(forTimeInterval: 0.02)
                    observed = try self.windows()
                }
                self.switching.observe(observed, now: ProcessInfo.processInfo.systemUptime)
                NSLog("[YabaiSpaces] \(command.rawValue): focused window \(target.id) in Space \(target.space)")
            } catch {
                self.switching.cancel()
                NSLog("[YabaiSpaces] \(command.rawValue) failed: \(error.localizedDescription)")
            }
        }
    }
}
