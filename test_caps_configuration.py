import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent


class CapsConfigurationTests(unittest.TestCase):
    def test_toml_validation_reload_and_window_selection(self):
        harness = r'''
import Foundation
func verified(_ result: Bool) { precondition(result) }
@main struct Checks {
    static func main() throws {
        let defaults = try CapsConfiguration.parse(Data(CapsConfiguration.defaultText.utf8))
        precondition(defaults == CapsBinding.defaults)
        let text = """
        # User-editable configuration
        [caps]
        c = { app = "Brave Browser", space = 6 }
        m = { app = 'Messages' } # Literal strings and comments
        w = { app = "Word", match = "contains", space = 2 }
        q = { disabled = true }
        """
        let bindings = try CapsConfiguration.parse(Data(text.utf8))
        precondition(bindings.count == 3)
        let command = JumpCommand(rawValue: "jump c", bindings: bindings)!
        precondition(command.matches(application: "Brave Browser", space: 6))
        precondition(!command.matches(application: "Brave Browser", space: 7))
        precondition(!command.matches(application: "Brave Browser Beta", space: 6))
        let word = JumpCommand(rawValue: "jump w", bindings: bindings)!
        precondition(word.matches(application: "Microsoft Word", space: 2))
        precondition(!word.matches(application: "Microsoft Word", space: 3))
        let messages = JumpCommand(rawValue: "jump m", bindings: bindings)!
        precondition(messages.matches(application: "Messages", space: 99))
        precondition(!messages.matches(application: "Messages Helper", space: 99))
        precondition(JumpCommand(rawValue: "jump q", bindings: bindings)?.application == nil)
        precondition(JumpCommand(rawValue: "jump s", bindings: bindings)?.application == nil)
        for (key, destination) in [("1", 1), ("0", 10), ("-", 11), ("=", 12)] {
            precondition(JumpCommand(rawValue: "jump \(key)", bindings: bindings)?.destinationSpace == destination)
        }
        precondition(JumpCommand(rawValue: "jump .", bindings: bindings) == nil)
        let unicode = try CapsConfiguration.parse(Data("[caps]\nm = { app = \"é # \\u0041 \\\"text\\\"\" }".utf8))
        precondition(unicode["m"]?.app == "é # A \"text\"")
        for invalid in ["", "[cap]\nm = { app = 'Messages' }", "[caps]\nM = { app = 'Messages' }",
                        "[caps]\nmm = { app = 'Messages' }", "[caps]\n1 = { app = 'Messages' }",
                        "[caps]\nm = { app = '' }", "[caps]\nm = { app = '   ' }",
                        "[caps]\nm = { app = 42 }", "[caps]\nm = { app = 'Messages', space = 0 }",
                        "[caps]\nm = { app = 'Messages', space = -1 }",
                        "[caps]\nm = { app = 'Messages', space = '6' }",
                        "[caps]\nm = { app = 'Messages', space = 1.5 }",
                        "[caps]\nm = { app = 'Messages', space = 2147483648 }",
                        "[caps]\nm = { app = 'Messages', spaces = 6 }",
                        "[caps]\nm = { app = 'Messages', match = 'regex' }",
                        "[caps]\nm = { disabled = false }",
                        "[caps]\nm = { disabled = true, app = 'Messages' }",
                        "[caps]\nm = {}", "[caps]\nm = { app = 'Messages'",
                        "[caps]\nm = { app = 'Messages' }\nm = { app = 'Safari' }",
                        "[caps]\nm = { app = 'Messages', app = 'Safari' }",
                        "[caps]\n[unknown]\nvalue = 1"] {
            do {
                _ = try CapsConfiguration.parse(Data(invalid.utf8))
                preconditionFailure("Accepted invalid TOML/schema: \(invalid)")
            } catch {}
        }
        var state = WindowSwitching()
        let windows = [NavigationWindow(id: 1, pid: 10, space: 6, application: "Brave Browser"),
                       NavigationWindow(id: 2, pid: 10, space: 7, focused: true, application: "Brave Browser"),
                       NavigationWindow(id: 3, pid: 10, space: 6, application: "Brave Browser")]
        state.observe([windows[2]], now: 0)
        precondition(state.target(command, windows: windows, now: 1)?.id == 3)
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let url = root.appendingPathComponent("config/settings.toml")
        let store = CapsConfigurationStore(url: url)
        let raw = JumpCommand(rawValue: "jump m")!
        precondition(store.resolve(raw).application == "Messages")
        do { try store.reload(); preconditionFailure("Missing file accepted") } catch {}
        verified(try store.reload(createIfMissing: true) == 20)
        verified(try String(contentsOf: url, encoding: .utf8) == CapsConfiguration.defaultText)
        try Data(text.utf8).write(to: url, options: .atomic)
        verified(try store.reload(createIfMissing: true) == 3)
        let captured = store.resolve(raw)
        try Data("[caps]\nm = { app = 'Safari', space = 2 }\n".utf8).write(to: url, options: .atomic)
        verified(try store.reload() == 1)
        precondition(store.resolve(raw).application == "Safari")
        precondition(store.resolve(raw).applicationSpace == 2)
        precondition(captured.application == "Messages")
        precondition(store.resolve(JumpCommand(rawValue: "jump c")!).application == nil)
        try Data("[caps]\nm = { app = 'bad'\n".utf8).write(to: url)
        do { try store.reload(); preconditionFailure("Invalid replacement accepted") } catch {}
        precondition(store.resolve(raw).application == "Safari")
        try Data(repeating: 32, count: 65_537).write(to: url)
        do { try store.reload(); preconditionFailure("Oversized file accepted") } catch {}
        precondition(store.resolve(raw).application == "Safari")
        try FileManager.default.removeItem(at: url)
        do { try store.reload(); preconditionFailure("Deleted file accepted") } catch {}
        precondition(store.resolve(raw).application == "Safari")
        let target = root.appendingPathComponent("linked.toml")
        try Data("[caps]\n".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target)
        verified(try store.reload() == 0)
        precondition(store.resolve(raw).application == nil)
        verified(try String(contentsOf: target, encoding: .utf8) == "[caps]\n")
        print("TOML parsing, fail-safe reload, snapshot selection and file lifecycle verified")
    }
}
'''
        with tempfile.TemporaryDirectory(prefix="ys-config-tests-", dir="/tmp") as directory:
            root = Path(directory)
            dependency = os.environ.get("YS_TOMLDECODER_SOURCE")
            if dependency:
                checkout = Path(dependency)
            else:
                packages = root / "packages"
                subprocess.run([
                    "xcodebuild", "-project", str(ROOT / "YabaiIndicator.xcodeproj"),
                    "-scheme", "YabaiIndicator", "-resolvePackageDependencies",
                    "-derivedDataPath", str(root / "build"),
                    "-clonedSourcePackagesDirPath", str(packages),
                ], check=True, capture_output=True, timeout=180)
                checkout = packages / "checkouts/TOMLDecoder"
            sources = sorted((checkout / "Sources/TOMLDecoder").rglob("*.swift"))
            self.assertTrue(sources, f"TOMLDecoder sources missing: {checkout}")
            library = root / "libTOMLDecoder.dylib"
            subprocess.run([
                "xcrun", "swiftc", "-swift-version", "6", "-parse-as-library",
                "-module-cache-path", str(root / "cache"), "-emit-library", "-emit-module",
                "-module-name", "TOMLDecoder", "-emit-module-path", str(root / "TOMLDecoder.swiftmodule"),
                "-enable-upcoming-feature", "ExistentialAny",
                "-enable-upcoming-feature", "InternalImportsByDefault",
                "-enable-upcoming-feature", "MemberImportVisibility",
                *map(str, sources), "-Xlinker", "-install_name", "-Xlinker", str(library), "-o", str(library),
            ], check=True, timeout=180)
            checks = root / "Checks.swift"
            checks.write_text(harness)
            binary = root / "checks"
            subprocess.run([
                "xcrun", "swiftc", "-parse-as-library", "-module-cache-path", str(root / "cache"),
                "-I", str(root), "-L", str(root), "-lTOMLDecoder",
                str(ROOT / "YabaiIndicator/Models/PanelHotkey.swift"),
                str(ROOT / "YabaiIndicator/WindowSwitching.swift"),
                str(ROOT / "YabaiIndicator/CapsConfiguration.swift"), str(checks), "-o", str(binary),
            ], check=True, timeout=120)
            subprocess.run([str(binary), str(root)], check=True, timeout=10)


if __name__ == "__main__":
    unittest.main()
