//
//  KeyboardSimulationStrategy.h
//  MacMediaKeyForwarder
//
//  Created by [Your Name] on [Date].
//  Copyright © 2023 [Your Name]. All rights reserved.
//
//  This class implements the PlaybackControlStrategy protocol by simulating media key presses.
//  It is intended as an alternative control mechanism if ScriptingBridge is not available
//  or suitable for a particular application. This strategy may require Accessibility permissions.
//  Note: This strategy is currently a placeholder and requires full implementation.
//

#import <Foundation/Foundation.h>
#import "PlaybackControlStrategy.h" // Conforms to this protocol

NS_ASSUME_NONNULL_BEGIN

// Implements playback control by simulating keyboard events for media keys.
// This can be useful for applications that do not support ScriptingBridge but
// do respond to standard media keys.
@interface KeyboardSimulationStrategy : NSObject <PlaybackControlStrategy>

// Methods from the PlaybackControlStrategy protocol are implemented in the .m file.
// Note that some methods, like `isAppPlaying:`, may be difficult to implement reliably
// with only keyboard simulation.

@end

NS_ASSUME_NONNULL_END
