import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class SafeRunTests(unittest.TestCase):
    def check_run(self, mode, arguments, expected_status, expected_calls):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            executable = root / "fake-command"
            executable.write_text('''#!/bin/bash
name="${0##*/}"
printf '%s\\n' "$name" >> "$CALLS"
case "$name" in
    pgrep)
        if [ "$MODE" = running ]; then exit 0; fi
        if [ "$MODE" = race ] && [ -f "$BUILT" ]; then exit 0; fi
        exit 1 ;;
    xcodebuild)
        if [ "$MODE" = build_failure ]; then exit 7; fi
        while [ "$#" -gt 0 ]; do
            if [ "$1" = -derivedDataPath ]; then
                shift
                mkdir -p "$1/Build/Products/Debug/YabaiIndicator.app"
                break
            fi
            shift
        done
        touch "$BUILT" ;;
    codesign) if [ "$MODE" = sign_failure ]; then exit 8; fi ;;
    open) exit 0 ;;
esac
''')
            executable.chmod(0o700)
            for name in ["pgrep", "xcodebuild", "codesign", "open"]:
                (root / name).symlink_to(executable)
            environment = dict(os.environ, PATH=f"{root}:/usr/bin:/bin", TMPDIR=str(root),
                               MODE=mode, CALLS=str(root / "calls"), BUILT=str(root / "built"))
            result = subprocess.run(["/bin/bash", str(Path(__file__).with_name("run.sh")), *arguments],
                                    env=environment, capture_output=True, text=True)
            self.assertEqual(result.returncode, expected_status, result.stdout + result.stderr)
            calls = (root / "calls").read_text().splitlines() if (root / "calls").exists() else []
            self.assertEqual(calls, expected_calls)

    def test_default_never_launches_or_queries_running_app(self):
        self.check_run("running", [], 0, ["xcodebuild", "codesign"])

    def test_build_failure_never_launches(self):
        self.check_run("build_failure", ["--launch"], 7, ["pgrep", "xcodebuild"])

    def test_signature_failure_never_launches(self):
        self.check_run("sign_failure", ["--launch"], 8, ["pgrep", "xcodebuild", "codesign"])

    def test_running_app_is_not_killed(self):
        self.check_run("running", ["--launch"], 1, ["pgrep"])

    def test_app_starting_during_build_prevents_second_launch(self):
        self.check_run("race", ["--launch"], 1, ["pgrep", "xcodebuild", "codesign", "pgrep"])

    def test_explicit_launch_after_success(self):
        self.check_run("success", ["--launch"], 0, ["pgrep", "xcodebuild", "codesign", "pgrep", "open"])

    def test_invalid_argument_has_no_side_effects(self):
        self.check_run("success", ["--invalid"], 2, [])


if __name__ == "__main__":
    unittest.main()
