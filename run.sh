#!/bin/bash
# Kill any existing instance
killall -9 YabaiIndicator 2>/dev/null
sleep 1

# Verify it's dead
if pgrep -x YabaiIndicator > /dev/null; then
    echo "Warning: YabaiIndicator still running, killing again..."
    killall -9 YabaiIndicator 2>/dev/null
    sleep 1
fi

# Build
xcodebuild -project YabaiIndicator.xcodeproj -scheme YabaiIndicator -configuration Debug build

# Launch directly (more reliable than 'open')
/Users/carlcotner/Library/Developer/Xcode/DerivedData/YabaiIndicator-dwzhypgpamdanzgksdnpyxudlnbu/Build/Products/Debug/YabaiIndicator.app/Contents/MacOS/YabaiIndicator &
echo "YabaiIndicator launched (PID: $!)"
