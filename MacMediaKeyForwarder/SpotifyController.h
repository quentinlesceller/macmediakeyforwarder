//
//  SpotifyController.h
//  MacMediaKeyForwarder
//
//  Created by [Your Name] on [Date].
//  Copyright © 2023 [Your Name]. All rights reserved.
//
//  This class implements the PlayerController protocol to control the Spotify application.
//  It uses a PlaybackControlStrategy to send commands to Spotify.
//

#import <Foundation/Foundation.h>
#import "PlayerController.h"      // Conforms to the PlayerController protocol
#import "Spotify.h"             // For the SpotifyApplication ScriptingBridge type

NS_ASSUME_NONNULL_BEGIN

// Manages interaction with the Spotify application.
@interface SpotifyController : NSObject <PlayerController>

// The strategy used to send commands to Spotify (e.g., ScriptingBridge).
// This property is synthesized from the PlayerController protocol.
@property (nonatomic, strong) id<PlaybackControlStrategy> strategy;

// The name of the player, "Spotify".
// This property is synthesized from the PlayerController protocol.
@property (nonatomic, readonly) NSString *playerName;

// The bundle identifier for Spotify, "com.spotify.client".
// This property is synthesized from the PlayerController protocol.
@property (nonatomic, readonly) NSString *bundleIdentifier;

// The ScriptingBridge object for the Spotify application.
// This is initialized by the strategy and provides a typed interface for controlling Spotify.
// It is nullable because the application might not be running or accessible.
@property (nonatomic, strong, nullable) SpotifyApplication *spotifyApp;

// Initializes a new SpotifyController with a specific playback strategy.
// @param strategy The strategy for controlling playback.
// @return An initialized SpotifyController instance.
- (instancetype)initWithStrategy:(id<PlaybackControlStrategy>)strategy;

// Note: Methods like playPause, nextTrack, previousTrack, isPlaying, isRunning
// are declared in the PlayerController protocol and implemented in SpotifyController.m.

@end

NS_ASSUME_NONNULL_END
