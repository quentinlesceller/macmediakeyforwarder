//
//  iTunesController.h
//  MacMediaKeyForwarder
//
//  Created by [Your Name] on [Date].
//  Copyright © 2023 [Your Name]. All rights reserved.
//
//  This class implements the PlayerController protocol to control Apple's iTunes or Music application.
//  It uses a PlaybackControlStrategy to send commands and dynamically determines the
//  correct bundle identifier based on the macOS version.
//

#import <Foundation/Foundation.h>
#import "PlayerController.h"      // Conforms to the PlayerController protocol
#import "iTunes.h"              // For the iTunesApplication ScriptingBridge type (used by both iTunes and Music)

NS_ASSUME_NONNULL_BEGIN

// Manages interaction with the iTunes or Music application.
@interface iTunesController : NSObject <PlayerController>

// The strategy used to send commands (e.g., ScriptingBridge).
// This property is synthesized from the PlayerController protocol.
@property (nonatomic, strong) id<PlaybackControlStrategy> strategy;

// The name of the player, typically "iTunes" for consistency within this app's logic,
// even when controlling the "Music" app on newer macOS versions.
// This property is synthesized from the PlayerController protocol.
@property (nonatomic, readonly) NSString *playerName;

// The bundle identifier, dynamically determined: "com.apple.iTunes" for older macOS
// or "com.apple.music" for macOS 10.15 and newer.
// This property is synthesized from the PlayerController protocol.
@property (nonatomic, readonly) NSString *bundleIdentifier;

// The ScriptingBridge object for the iTunes/Music application.
// This is initialized by the strategy and provides a typed interface for control.
// It is nullable because the application might not be running or accessible.
// Note: Even for "Music.app", the ScriptingBridge header is typically named "iTunes.h"
// if generated from its sdef, or a generic "Music.h" might be used if generated separately.
// This template assumes "iTunes.h" covers both for ScriptingBridge interactions.
@property (nonatomic, strong, nullable) iTunesApplication *iTunesApp;

// Initializes a new iTunesController with a specific playback strategy.
// @param strategy The strategy for controlling playback.
// @return An initialized iTunesController instance.
- (instancetype)initWithStrategy:(id<PlaybackControlStrategy>)strategy;

// Helper class method to determine the correct bundle identifier for iTunes or Music app
// based on the operating system version.
// @return The bundle identifier string (e.g., "com.apple.music" or "com.apple.iTunes").
+ (NSString *)iTunesBundleIdentifier;

// Note: Methods like playPause, nextTrack, previousTrack, isPlaying, isRunning
// are declared in the PlayerController protocol and implemented in iTunesController.m.

@end

NS_ASSUME_NONNULL_END
