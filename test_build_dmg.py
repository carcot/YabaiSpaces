import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parent


class ReleasePackagingTests(unittest.TestCase):
    def check_package(self, mode, expected_status, expected_calls):
        with tempfile.TemporaryDirectory(prefix="ys-package-tests-") as directory:
            root = Path(directory)
            shutil.copy2(ROOT / "build-dmg.sh", root / "build-dmg.sh")
            executable = root / "fake-command"
            executable.write_text('''#!/bin/bash
name="${0##*/}"
printf '%s\\n' "$name" >> "$CALLS"
case "$name" in
    xcodebuild)
        if [ "$MODE" = build_failure ]; then echo '** BUILD FAILED **'; exit 7; fi
        build_directory=""
        while [ "$#" -gt 0 ]; do
            if [ "$1" = -derivedDataPath ]; then shift; build_directory="$1"; fi
            shift
        done
        [ -n "$build_directory" ] || exit 11
        app="$build_directory/Build/Products/Release/YabaiIndicator.app"
        mkdir -p "$app/Contents/MacOS"
        printf '%s' '<plist version="1.0"><dict><key>CFBundleShortVersionString</key><string>1.9.0</string></dict></plist>' > "$app/Contents/Info.plist"
        touch "$app/Contents/MacOS/YabaiIndicator"
        echo '** BUILD SUCCEEDED **' ;;
    codesign) if [ "$MODE" = sign_failure ]; then exit 8; fi ;;
    lipo)
        [ -f "$1" ] && [ "$2" = -verify_arch ] && [ "$3" = arm64 ] && [ "$4" = x86_64 ] || exit 15
        if [ "$MODE" = arch_failure ]; then exit 9; fi ;;
    hdiutil)
        if [ "$1" = verify ]; then
            [ -f "$2" ] || exit 12
            if [ "$MODE" = verify_failure ]; then exit 10; fi
        else
            image="${@: -1}"
            while [ "$#" -gt 0 ]; do
                if [ "$1" = -srcfolder ]; then
                    shift
                    [ -f "$1/YabaiSpaces.app/Contents/Info.plist" ] || exit 13
                    [ "$(readlink "$1/Applications")" = /Applications ] || exit 14
                fi
                shift
            done
            touch "$image"
        fi ;;
esac
''')
            executable.chmod(0o700)
            for name in ["xcodebuild", "codesign", "lipo", "hdiutil"]:
                (root / name).symlink_to(executable)
            environment = dict(os.environ, PATH=f"{root}:/usr/bin:/bin", TMPDIR=str(root),
                               MODE=mode, CALLS=str(root / "calls"))
            result = subprocess.run(["/bin/bash", str(root / "build-dmg.sh")], cwd=root,
                                    env=environment, capture_output=True, text=True)
            self.assertEqual(result.returncode, expected_status, result.stdout + result.stderr)
            calls = (root / "calls").read_text().splitlines()
            self.assertEqual(calls, expected_calls)
            image = root / "YabaiSpaces-1.9.0-Universal.dmg"
            self.assertEqual(image.exists(), mode in ["success", "verify_failure"])
            self.assertFalse((root / "build").exists())
            self.assertEqual(list(root.glob("YabaiSpaces-dmg.*")), [])

    def test_version_and_application_name_come_from_verified_build(self):
        self.check_package("success", 0, ["xcodebuild", "codesign", "lipo", "hdiutil", "hdiutil"])

    def test_failed_build_never_packages(self):
        self.check_package("build_failure", 7, ["xcodebuild"])

    def test_failed_signature_never_packages(self):
        self.check_package("sign_failure", 8, ["xcodebuild", "codesign"])

    def test_missing_architecture_never_packages(self):
        self.check_package("arch_failure", 9, ["xcodebuild", "codesign", "lipo"])

    def test_failed_image_verification_is_reported(self):
        self.check_package("verify_failure", 10, ["xcodebuild", "codesign", "lipo", "hdiutil", "hdiutil"])


if __name__ == "__main__":
    unittest.main()
