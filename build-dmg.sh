#!/bin/bash
set -euo pipefail

# Build the app
echo "Building YabaiSpaces..."
BUILD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/YabaiSpaces-release.XXXXXX")
echo "Build directory: $BUILD_DIR"
xcodebuild -project YabaiIndicator.xcodeproj \
    -scheme YabaiIndicator \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    clean build 2>&1 | tee "$BUILD_DIR/build.log" | grep -E '(\*\* (CLEAN|BUILD)|error:|warning:)' | tail -10

# Find built app
APP_PATH="$BUILD_DIR/Build/Products/Release/YabaiIndicator.app"
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Could not find built app"
    exit 1
fi
echo "Built app at: $APP_PATH"
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Invalid application version: $VERSION"
    exit 1
fi
codesign --verify --deep --strict "$APP_PATH"
lipo "$APP_PATH/Contents/MacOS/YabaiIndicator" -verify_arch arm64 x86_64

# Create DMG
DMG_NAME="YabaiSpaces-${VERSION}-Universal.dmg"
echo "Creating DMG: $DMG_NAME"

DMG_STAGE=$(mktemp -d "${TMPDIR:-/tmp}/YabaiSpaces-dmg.XXXXXX")
trap 'rm -rf "$DMG_STAGE"' EXIT
ditto "$APP_PATH" "$DMG_STAGE/YabaiSpaces.app"
ln -s /Applications "$DMG_STAGE/Applications"

# Create temporary DMG
hdiutil create -volname "YabaiSpaces" \
    -srcfolder "$DMG_STAGE" \
    -ov \
    -format UDZO \
    "$DMG_NAME"
hdiutil verify "$DMG_NAME"

echo "Created $DMG_NAME"
ls -lh "$DMG_NAME"
