//
//  ThreeFingerTap.m
//  YabaiIndicator
//
//  Three-finger tap detection using CGEventTap
//

#import "ThreeFingerTap.h"
#import <ApplicationServices/ApplicationServices.h>

static ThreeFingerTapCallback tapCallback = nil;
static CFMachPortRef eventTap = nil;
static CFRunLoopSourceRef runLoopSource = nil;

// CGEventTap callback function
static CGEventRef eventTapCallback(CGEventTapProxy proxy,
                                    CGEventType type,
                                    CGEventRef event,
                                    void *refcon) {
    // Check for "other" mouse down events (button 2, 3, etc.)
    if (type == kCGEventOtherMouseDown) {
        CGMouseButton button = (CGMouseButton)CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);

        // Button 3 often corresponds to three-finger tap on trackpad
        // Button 2 is typically two-finger tap (right click)
        if (button == 3 && tapCallback) {
            CGPoint location = CGEventGetLocation(event);
            dispatch_async(dispatch_get_main_queue(), ^{
                tapCallback(location);
            });
        }
    }

    return event;
}

void startThreeFingerTapMonitor(ThreeFingerTapCallback callback) {
    if (eventTap != nil) {
        return; // Already running
    }

    tapCallback = [callback copy];

    // Create event tap for other mouse events (three-finger tap)
    CGEventMask eventMask = (1 << kCGEventOtherMouseDown);

    eventTap = CGEventTapCreate(kCGSessionEventTap,
                                kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault,
                                eventMask,
                                eventTapCallback,
                                NULL);

    if (eventTap == nil) {
        return;
    }

    // Enable the event tap
    CGEventTapEnable(eventTap, true);

    // Add to run loop
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
}

void stopThreeFingerTapMonitor(void) {
    if (runLoopSource != nil) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CFRelease(runLoopSource);
        runLoopSource = nil;
    }

    if (eventTap != nil) {
        CFRelease(eventTap);
        eventTap = nil;
    }

    tapCallback = nil;
}
