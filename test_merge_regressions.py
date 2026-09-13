from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parent


class MergeRegressionTests(unittest.TestCase):
    def test_display_capture_keeps_desktop_pixels(self):
        source = (ROOT / "YabaiIndicator/PrivateWindowCapture.swift").read_text()
        capture = source.split("func captureSpace(", 1)[1]
        self.assertIn("CGDisplayCreateImage(displayID)", capture)
        self.assertIn("return cgImageToPNG(scaledImage)", capture)
        self.assertNotIn("captureWindow(", capture)

    def test_compatible_hotkeys_keep_tested_behavior(self):
        source = (ROOT / "YabaiIndicator/YabaiAppDelegate.swift").read_text()
        bindings = source.split("let bindings: [HotkeyBinding] = [", 1)[1].split("]", 1)[0]
        self.assertIn("keyCode: 49", bindings)
        self.assertIn("action: .toggle(panelPosition)", bindings)
        self.assertIn("keyCode: 79", bindings)
        self.assertIn("action: .confirmOrShow(panelPosition)", bindings)
        self.assertNotIn("keyCode: 60", bindings)

    def test_socket_response_cleanup_is_not_duplicated(self):
        source = (ROOT / "YabaiIndicator/Connectors/YabaiClient.swift").read_text()
        call = source.split("func _yabaiSocketCall(", 1)[1].split("@discardableResult", 1)[0]
        self.assertEqual(call.count("defer {"), 1)
        self.assertEqual(call.count("for ptr in cargs { free(ptr) }"), 1)
        self.assertIn("throws -> YabaiResponse", source)

    def test_timeout_setup_is_not_duplicated(self):
        source = (ROOT / "YabaiIndicator/SocketClient.c").read_text()
        self.assertEqual(source.count("struct timeval timeout;"), 1)
        self.assertEqual(source.count("SO_RCVTIMEO"), 1)
        self.assertEqual(source.count("SO_SNDTIMEO"), 1)


if __name__ == "__main__":
    unittest.main()
