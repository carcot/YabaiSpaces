#!/bin/bash
set -e

VERSION="1.1.3"

# Build the app
echo "Building YabaiSpaces..."
xcodebuild -project YabaiIndicator.xcodeproj \
    -scheme YabaiIndicator \
    -configuration Release \
    -derivedDataPath build \
    clean build 2>&1 | grep -E "(BUILD|error|warning)" | tail -10

# Find built app
APP_PATH=$(find build -name "YabaiIndicator.app" -path "*/Release/*" | head -1)
if [ -z "$APP_PATH" ]; then
    echo "ERROR: Could not find built app"
    exit 1
fi
echo "Built app at: $APP_PATH"

# Create DMG
DMG_NAME="YabaiSpaces-${VERSION}-Universal.dmg"
echo "Creating DMG: $DMG_NAME"

# Remove old DMG if exists
rm -f "$DMG_NAME"

# Create temporary DMG
hdiutil create -volname "YabaiSpaces" \
    -srcfolder "$APP_PATH" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

echo "Created $DMG_NAME"
ls -lh "$DMG_NAME"
