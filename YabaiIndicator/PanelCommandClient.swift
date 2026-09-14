import Foundation
import Darwin

enum PanelCommandClient {
    private struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func run(arguments: [String], socketPath: String = "/tmp/yabai-indicator.socket", timeout: TimeInterval = 3) -> Int32? {
        if arguments.isEmpty { return nil }
        if arguments.count == 1 && arguments[0].hasPrefix("-psn_") { return nil }
        let usage = "Usage: YabaiSpaces panel {show|hide|toggle|activate-selected|activate-selected-or-show}\n       YabaiSpaces {app|window} {next-in-space|previous-in-space|next-across-spaces|previous-across-spaces}\n"
        if arguments == ["--help"] || arguments == ["-h"] {
            FileHandle.standardOutput.write(Data(usage.utf8))
            return 0
        }
        let message = arguments.joined(separator: " ")
        guard arguments.count == 2,
              PanelCommand(rawValue: message) != nil || SwitchCommand(rawValue: message) != nil else {
            FileHandle.standardError.write(Data(usage.utf8))
            return 2
        }
        do {
            try sendMessage(message, socketPath: socketPath, timeout: timeout)
            FileHandle.standardOutput.write(Data("Command queued\n".utf8))
            return 0
        } catch {
            FileHandle.standardError.write(Data("YS command failed: \(error.localizedDescription)\n".utf8))
            return 1
        }
    }

    private static func systemFailure(_ operation: String) -> Failure {
        Failure(message: "\(operation): \(String(cString: strerror(errno)))")
    }

    static func send(_ command: PanelCommand, socketPath: String, timeout: TimeInterval) throws {
        try sendMessage(command.rawValue, socketPath: socketPath, timeout: timeout)
    }

    private static func sendMessage(_ message: String, socketPath: String, timeout: TimeInterval) throws {
        let deadline = ProcessInfo.processInfo.systemUptime + timeout
        var metadata = stat()
        guard lstat(socketPath, &metadata) == 0 else {
            throw Failure(message: "YabaiSpaces is not reachable. Start the app first.")
        }
        guard metadata.st_mode & mode_t(S_IFMT) == mode_t(S_IFSOCK), metadata.st_uid == getuid() else {
            throw Failure(message: "Refusing a socket not owned by this user")
        }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let pathBytes = Array(socketPath.utf8) + [0]
        guard !socketPath.utf8.contains(0), pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else {
            throw Failure(message: "Invalid socket path")
        }
        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            destination.copyBytes(from: pathBytes)
        }
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { throw systemFailure("socket") }
        defer { close(descriptor) }
        var noSignal: Int32 = 1
        guard setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout.size(ofValue: noSignal))) == 0 else {
            throw systemFailure("socket options")
        }
        let flags = fcntl(descriptor, F_GETFL)
        guard flags >= 0, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
            throw systemFailure("nonblocking socket")
        }
        let connected = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        if connected != 0 {
            guard errno == EINPROGRESS else { throw systemFailure("connect") }
            try wait(descriptor, events: Int16(POLLOUT), deadline: deadline)
            var socketError: Int32 = 0
            var errorSize = socklen_t(MemoryLayout.size(ofValue: socketError))
            guard getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &socketError, &errorSize) == 0 else {
                throw systemFailure("connect status")
            }
            guard socketError == 0 else {
                throw Failure(message: "connect: \(String(cString: strerror(socketError)))")
            }
        }
        var peerUser: uid_t = 0
        var peerGroup: gid_t = 0
        guard getpeereid(descriptor, &peerUser, &peerGroup) == 0, peerUser == getuid() else {
            throw Failure(message: "Refusing a server not owned by this user")
        }
        let request = Array((message + "\n").utf8)
        var offset = 0
        while offset < request.count {
            try wait(descriptor, events: Int16(POLLOUT), deadline: deadline)
            let sent = request.withUnsafeBytes { buffer in
                Darwin.send(descriptor, buffer.baseAddress!.advanced(by: offset), request.count - offset, 0)
            }
            if sent < 0 && (errno == EINTR || errno == EAGAIN) { continue }
            guard sent > 0 else { throw systemFailure("send") }
            offset += sent
        }
        var response: [UInt8] = []
        while !response.contains(10) {
            try wait(descriptor, events: Int16(POLLIN), deadline: deadline)
            var buffer = [UInt8](repeating: 0, count: 129 - response.count)
            let received = recv(descriptor, &buffer, buffer.count, 0)
            if received < 0 && (errno == EINTR || errno == EAGAIN) { continue }
            guard received > 0 else {
                throw Failure(message: "No acknowledgment; the running YabaiSpaces may not support panel commands")
            }
            response.append(contentsOf: buffer.prefix(received))
            guard response.count <= 128 else { throw Failure(message: "Invalid oversized response") }
        }
        guard response == Array("ok queued\n".utf8) else {
            throw Failure(message: "YabaiSpaces rejected the command")
        }
    }

    private static func wait(_ descriptor: Int32, events: Int16, deadline: TimeInterval) throws {
        while true {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            guard remaining > 0 else { throw Failure(message: "Timed out waiting for YabaiSpaces") }
            var event = pollfd(fd: descriptor, events: events, revents: 0)
            let milliseconds = Int32(min(remaining * 1000, Double(Int32.max)).rounded(.up))
            let result = poll(&event, 1, milliseconds)
            if result < 0 && errno == EINTR { continue }
            guard result >= 0 else { throw systemFailure("poll") }
            if result == 0 { throw Failure(message: "Timed out waiting for YabaiSpaces") }
            if event.revents & Int16(POLLNVAL) != 0 { throw Failure(message: "Invalid socket") }
            return
        }
    }
}
