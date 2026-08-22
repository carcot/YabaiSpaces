import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time
import unittest

import ysctl


class PanelCommandTests(unittest.TestCase):
    def exchange(self, response, expected_error=None, delay=0):
        with tempfile.TemporaryDirectory(prefix="ysctl-", dir="/tmp") as directory:
            path = str(Path(directory) / "socket")
            received = []
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
                server.bind(path)
                server.listen(1)
                server.settimeout(2)

                def serve():
                    with server.accept()[0] as connection:
                        connection.settimeout(2)
                        received.append(connection.recv(256))
                        time.sleep(delay)
                        if response:
                            try:
                                connection.sendall(response)
                            except BrokenPipeError:
                                pass

                worker = threading.Thread(target=serve)
                worker.start()
                try:
                    if expected_error:
                        with self.assertRaises(expected_error):
                            ysctl.send_command("activate-selected-or-show", path, timeout=0.1)
                    else:
                        ysctl.send_command("activate-selected-or-show", path)
                finally:
                    worker.join(timeout=3)
                self.assertFalse(worker.is_alive())
                self.assertEqual(received, [b"panel activate-selected-or-show\n"])

    def test_acknowledged(self):
        self.exchange(b"ok queued\n")

    def test_rejection(self):
        self.exchange(b"error invalid-command\n", RuntimeError)

    def test_old_server_without_reply(self):
        self.exchange(b"", RuntimeError)

    def test_oversized_reply(self):
        self.exchange(b"x" * 129, RuntimeError)

    def test_timeout(self):
        self.exchange(b"", TimeoutError, delay=0.2)

    def test_invalid_command_before_connect(self):
        with self.assertRaises(ValueError):
            ysctl.send_command("show; launch something", "/missing")

    def test_missing_server(self):
        with self.assertRaises(FileNotFoundError):
            ysctl.send_command("show", "/tmp/ys-command-test-missing/socket")

    def test_non_socket_rejected(self):
        with tempfile.NamedTemporaryFile() as target:
            with self.assertRaises(ValueError):
                ysctl.send_command("show", target.name)

    def test_swift_dispatch_and_framing(self):
        root = Path(__file__).parent
        source = (root / "YabaiIndicator/YabaiAppDelegate.swift").read_text()
        reader = source[source.index("    private func readSocketMessage"):source.index("    func socketServer()")]
        reader = reader.replace("private func", "func", 1)
        harness = '''
import AppKit
import Darwin
''' + reader + '''
@main struct Checks {
    static func read(_ bytes: [UInt8], closeWrite: Bool = true) -> String? {
        var descriptors: [Int32] = [0, 0]
        precondition(socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0)
        defer { close(descriptors[0]); close(descriptors[1]) }
        if !bytes.isEmpty {
            _ = bytes.withUnsafeBytes { send(descriptors[0], $0.baseAddress, $0.count, 0) }
        }
        if closeWrite { shutdown(descriptors[0], SHUT_WR) }
        return readSocketMessage(descriptors[1])
    }
    static func main() {
        let cases: [(PanelCommand, PanelCommand.Operation, PanelCommand.Operation)] = [
            (.show, .show, .none), (.hide, .none, .hide),
            (.toggle, .show, .hide), (.activateSelected, .none, .activateSelected),
            (.activateSelectedOrShow, .show, .activateSelected)]
        for (command, closed, opened) in cases {
            precondition(command.operation(isVisible: false) == closed)
            precondition(command.operation(isVisible: true) == opened)
            precondition(PanelCommand(rawValue: command.rawValue) == command)
            precondition(read(Array((command.rawValue + "\\n").utf8)) == command.rawValue)
        }
        precondition(PanelCommand(rawValue: "panel confirm") == nil)
        precondition(read(Array("refresh windows\\n".utf8), closeWrite: false) == "refresh windows")
        precondition(read(Array("panel show".utf8)) == "panel show")
        precondition(read(Array("panel show\\npanel hide\\n".utf8)) == nil)
        precondition(read([255, 10]) == nil)
        precondition(read(Array(repeating: 65, count: 257)) == nil)
        let start = ProcessInfo.processInfo.systemUptime
        precondition(read([], closeWrite: false) == nil)
        precondition(ProcessInfo.processInfo.systemUptime - start < 3)
        print("Swift dispatch and socket framing checks passed")
    }
}
'''
        with tempfile.TemporaryDirectory(prefix="ys-swift-", dir="/tmp") as directory:
            path = Path(directory)
            (path / "Checks.swift").write_text(harness)
            subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(path / "cache"),
                            str(root / "YabaiIndicator/Models/PanelHotkey.swift"), str(path / "Checks.swift"),
                            "-o", str(path / "checks")], check=True, timeout=120)
            subprocess.run([str(path / "checks")], check=True, timeout=10)


if __name__ == "__main__":
    unittest.main()
