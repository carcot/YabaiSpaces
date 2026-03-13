//
//  ThreeFingerTap.h
//  YabaiIndicator
//
//  Three-finger tap detection using CGEventTap
//

#ifndef ThreeFingerTap_h
#define ThreeFingerTap_h

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// Callback type for when a three-finger tap is detected
typedef void (^ThreeFingerTapCallback)(CGPoint location);

// Start monitoring for three-finger taps
void startThreeFingerTapMonitor(ThreeFingerTapCallback callback);

// Stop monitoring
void stopThreeFingerTapMonitor(void);

#endif /* ThreeFingerTap_h */
