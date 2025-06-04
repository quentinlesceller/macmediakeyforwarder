//
//  PlaybackControlStrategy.h
//  MacMediaKeyForwarder
//
//  Created by [Your Name] on [Date].
//  Copyright © 2023 [Your Name]. All rights reserved.
//
//  This protocol defines an interface for different strategies to control media playback.
//  Implementations of this protocol can use various mechanisms such as ScriptingBridge,
//  AppleScript execution, or simulated keyboard events to interact with player applications.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SBApplication; // Forward declaration for ScriptingBridge application objects.

// Defines the set of operations that a playback control strategy must implement.
// Each method typically targets a specific application instance, often obtained via its bundle identifier.
@protocol PlaybackControlStrategy <NSObject>

// Retrieves or creates an application instance representation for the given bundle identifier.
// For ScriptingBridge-based strategies, this typically returns an `SBApplication` instance.
// For other strategies (e.g., keyboard simulation), this might return nil or a custom object,
// as direct application instances might not be required or used in the same way.
// @param bundleIdentifier The bundle identifier of the target application.
// @return An object representing the application instance (e.g., `SBApplication`), or nil if not applicable.
- (nullable SBApplication *)applicationInstanceWithBundleIdentifier:(NSString *)bundleIdentifier;

// Sends a play/pause command to the specified application instance.
// @param applicationInstance The application instance to control (e.g., obtained from `applicationInstanceWithBundleIdentifier:`).
//                            This parameter may be nullable or unused by strategies not requiring a direct app object (e.g. global key events).
- (void)sendPlayPauseCommandToApp:(nullable SBApplication *)applicationInstance;

// Sends a next track command to the specified application instance.
// @param applicationInstance The application instance to control.
- (void)sendNextTrackCommandToApp:(nullable SBApplication *)applicationInstance;

// Sends a previous track command to the specified application instance.
// @param applicationInstance The application instance to control.
- (void)sendPreviousTrackCommandToApp:(nullable SBApplication *)applicationInstance;

// Additional command methods could be added here, for example:
// - (void)sendFastForwardCommandToApp:(nullable SBApplication *)applicationInstance;
// - (void)sendRewindCommandToApp:(nullable SBApplication *)applicationInstance;
// - (void)sendStopCommandToApp:(nullable SBApplication *)applicationInstance;
// - (void)sendSetVolumeCommandToApp:(nullable SBApplication *)applicationInstance volume:(float)volume;


// Checks if the application with the given bundle identifier is currently running.
// This method might not always require a direct `SBApplication` instance and can use system APIs.
// @param bundleIdentifier The bundle identifier of the application to check.
// @return YES if the application is running, NO otherwise.
- (BOOL)isAppRunning:(NSString *)bundleIdentifier;

// Checks if the specified application instance is currently playing audio.
// The implementation will be specific to the application and the control strategy.
// For example, ScriptingBridge strategies will query `playerState`.
// Keyboard simulation strategies might find this difficult to implement reliably.
// @param applicationInstance The application instance to query.
// @return YES if the application is playing, NO otherwise. This might be a best-guess for some strategies.
- (BOOL)isAppPlaying:(nullable SBApplication *)applicationInstance;

@end

NS_ASSUME_NONNULL_END
