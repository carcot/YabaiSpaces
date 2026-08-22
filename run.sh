#!/bin/bash
set -euo pipefail

launch=false
case "${1:-}" in
    ""|--build-only) ;;
    --launch) launch=true ;;
    --help)
        printf 'Usage: %s [--build-only|--launch]\nBuilds a signed copy without replacing the running app.\n--launch requires YabaiSpaces to be quit manually first.\n' "$0"
        exit 0
        ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then
    printf 'Expected at most one argument.\n' >&2
    exit 2
fi

project_dir="$(cd "$(dirname "$0")" && pwd)"
if "$launch" && pgrep -x YabaiIndicator >/dev/null; then
    printf 'YabaiSpaces is running. Leave it running, or quit it yourself before using --launch.\n' >&2
    exit 1
fi

build_dir="$(mktemp -d "${TMPDIR:-/tmp}/YabaiSpaces-build.XXXXXX")"
printf 'Isolated build directory: %s\n' "$build_dir"
xcodebuild -project "$project_dir/YabaiIndicator.xcodeproj" \
    -scheme YabaiIndicator -configuration Debug \
    -derivedDataPath "$build_dir" build

app="$build_dir/Build/Products/Debug/YabaiIndicator.app"
test -d "$app"
codesign --verify --deep --strict -R '=anchor apple generic' "$app"
printf 'Verified signed build: %s\n' "$app"

if "$launch"; then
    if pgrep -x YabaiIndicator >/dev/null; then
        printf 'YabaiSpaces started during the build; refusing to launch a second copy.\n' >&2
        exit 1
    fi
    open "$app"
    printf 'Launch requested; verify panel and input behavior before daily use.\n'
else
    printf 'The running app is unchanged. This build has not been installed or launched.\n'
fi
