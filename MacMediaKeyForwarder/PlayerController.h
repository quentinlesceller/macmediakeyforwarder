//
//  PlayerController.h
//  MacMediaKeyForwarder
//
//  Created by [Your Name] on [Date].
//  Copyright © 2023 [Your Name]. All rights reserved.
//
//  This protocol defines a standardized interface for controlling various music player applications.
//  It abstracts the specific details of each player, allowing them to be managed uniformly.
//

#import <Foundation/Foundation.h>
#import "PlaybackControlStrategy.h" // Defines how commands are sent (e.g., ScriptingBridge)

NS_ASSUME_NONNULL_BEGIN

// Defines the common set of operations that any player controller should implement.
@protocol PlayerController <NSObject>

// The strategy object used to send commands to the player application.
// This allows for different control mechanisms (e.g., ScriptingBridge, AppleScript, keyboard events).
@property (nonatomic, strong) id<PlaybackControlStrategy> strategy;

// A user-friendly name for the player application (e.g., "Spotify", "iTunes", "Music").
// This is primarily used for display purposes or for identifying controllers.
@property (nonatomic, readonly) NSString *playerName;

// The unique bundle identifier of the player application (e.g., "com.spotify.client", "com.apple.iTunes", "com.apple.music").
// This is crucial for targeting the correct application, especially with ScriptingBridge.
@property (nonatomic, readonly) NSString *bundleIdentifier;

// Designated initializer for a player controller.
// @param strategy The playback control strategy to be used by this controller.
// @return An initialized instance of a class conforming to PlayerController.
- (instancetype)initWithStrategy:(id<PlaybackControlStrategy>)strategy;

// Toggles the playback state of the music player (play if paused, pause if playing).
- (void)playPause;

// Skips to the next track in the current playlist or queue.
- (void)nextTrack;

// Skips to the previous track in the current playlist or queue.
- (void)previousTrack;

// Checks if the player application is currently playing audio.
// @return YES if the player is playing, NO otherwise.
- (BOOL)isPlaying;

// Checks if the player application is currently running (launched).
// @return YES if the application process is active, NO otherwise.
- (BOOL)isRunning;

// Future methods could include:
// - (void)setVolume:(float)volume; // Sets the player's volume (0.0 to 1.0)
// - (float)getVolume; // Gets the player's current volume
// - (NSString *)currentTrackName; // Gets the name of the currently playing track
// - (NSString *)currentArtistName; // Gets the artist of the currently playing track
// - (NSString *)currentAlbumName; // Gets the album of the currently playing track

@end

NS_ASSUME_NONNULL_END
