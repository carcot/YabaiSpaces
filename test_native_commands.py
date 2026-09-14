from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time
import unittest


ROOT = Path(__file__).resolve().parent


class NativeCommandTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build = tempfile.TemporaryDirectory(prefix="ys-native-tests-", dir="/tmp")
        cls.addClassCleanup(cls.build.cleanup)
        root = Path(cls.build.name)
        harness = root / "NativeChecks.swift"
        harness.write_text('''import Foundation
import Darwin
@main struct NativeChecks {
    static func main() {
        exit(PanelCommandClient.run(arguments: Array(CommandLine.arguments.dropFirst(3)),
            socketPath: CommandLine.arguments[1], timeout: Double(CommandLine.arguments[2])!) ?? 73)
    }
}
''')
        cls.binary = root / "native-checks"
        subprocess.run(["xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(root / "cache"),
                        str(ROOT / "YabaiIndicator/Models/PanelHotkey.swift"),
                        str(ROOT / "YabaiIndicator/PanelCommandClient.swift"), str(harness),
                        "-o", str(cls.binary)], check=True, timeout=120)

    def run_client(self, path, arguments, timeout=0.2):
        return subprocess.run([str(self.binary), str(path), str(timeout), *arguments],
                              capture_output=True, text=True, timeout=5)

    def test_no_arguments_preserves_gui_startup(self):
        self.assertEqual(self.run_client("/missing", []).returncode, 73)
        self.assertEqual(self.run_client("/missing", ["-psn_0_1"]).returncode, 73)

    def test_help_without_server(self):
        result = self.run_client("/missing", ["--help"])
        self.assertEqual(result.returncode, 0)
        self.assertIn("panel", result.stdout)

    def test_invalid_arguments_do_not_launch_gui(self):
        for arguments in [["panel"], ["panel", "confirm"], ["panel", "show", "extra"], ["--invalid"]]:
            with self.subTest(arguments=arguments):
                self.assertEqual(self.run_client("/missing", arguments).returncode, 2)

    def test_missing_server(self):
        result = self.run_client("/missing-ys-test.socket", ["panel", "show"])
        self.assertEqual(result.returncode, 1)
        self.assertIn("Start the app first", result.stderr)

    def test_non_socket_and_symlink_rejected(self):
        with tempfile.TemporaryDirectory(prefix="ys-path-", dir="/tmp") as directory:
            root = Path(directory)
            ordinary = root / "ordinary"
            ordinary.write_text("not a socket")
            self.assertEqual(self.run_client(ordinary, ["panel", "show"]).returncode, 1)
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
                server.bind(str(root / "real"))
                (root / "link").symlink_to(root / "real")
                result = self.run_client(root / "link", ["panel", "show"])
                self.assertEqual(result.returncode, 1)
                self.assertIn("Refusing", result.stderr)

    def exchange(self, chunks, status, action="show", delay=0, unit="panel"):
        with tempfile.TemporaryDirectory(prefix="ys-native-", dir="/tmp") as directory:
            path = Path(directory) / "socket"
            requests = []
            errors = []
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
                server.bind(str(path))
                server.listen(1)
                server.settimeout(3)

                def serve():
                    try:
                        with server.accept()[0] as connection:
                            connection.settimeout(2)
                            request = bytearray()
                            while not request.endswith(b"\n"):
                                chunk = connection.recv(256)
                                if not chunk:
                                    break
                                request.extend(chunk)
                            requests.append(bytes(request))
                            time.sleep(delay)
                            for chunk in chunks:
                                connection.sendall(chunk)
                                time.sleep(0.01)
                    except BrokenPipeError:
                        pass
                    except Exception as error:
                        errors.append(error)

                worker = threading.Thread(target=serve, daemon=True)
                worker.start()
                try:
                    result = self.run_client(path, [unit, action])
                finally:
                    worker.join(timeout=4)
                self.assertFalse(worker.is_alive())
                self.assertEqual(errors, [])
                self.assertEqual(requests, [f"{unit} {action}\n".encode()])
                self.assertEqual(result.returncode, status, result.stderr)
                return result

    def test_all_commands(self):
        for action in ["show", "hide", "toggle", "activate-selected", "activate-selected-or-show"]:
            with self.subTest(action=action):
                self.exchange([b"ok queued\n"], 0, action)

    def test_fragmented_response(self):
        self.exchange([b"ok ", b"queued", b"\n"], 0)

    def test_switch_commands(self):
        for unit in ["app", "window"]:
            for action in ["next-in-space", "previous-in-space", "next-across-spaces", "previous-across-spaces"]:
                with self.subTest(unit=unit, action=action):
                    self.exchange([b"ok queued\n"], 0, action, unit=unit)
        for arguments in [["app", "show"], ["window", "next"], ["panel", "next-in-space"]]:
            self.assertEqual(self.run_client("/missing", arguments).returncode, 2)

    def test_rejected_response(self):
        self.exchange([b"error invalid-command\n"], 1)

    def test_old_server_and_disconnect(self):
        self.exchange([], 1)

    def test_oversized_response(self):
        self.exchange([b"x" * 129], 1)

    def test_timeout(self):
        result = self.exchange([], 1, delay=0.5)
        self.assertIn("Timed out", result.stderr)


if __name__ == "__main__":
    unittest.main()
