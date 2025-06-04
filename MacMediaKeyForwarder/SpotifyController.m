//
//  SpotifyController.m
//  MacMediaKeyForwarder
//
//  Created by [Your Name] on [Date].
//  Copyright © 2023 [Your Name]. All rights reserved.
//
//  Implementation of the SpotifyController class.
//

#import "SpotifyController.h"
#import "Spotify.h" // Required for SpotifyApplication class and enum constants like SpotifyEPlSPlaying

@implementation SpotifyController

// Synthesize properties declared in the PlayerController protocol.
// The actual ivars (_strategy, _playerName, _bundleIdentifier) are implicitly created.
@synthesize strategy = _strategy;
@synthesize playerName = _playerName;
@synthesize bundleIdentifier = _bundleIdentifier;
// Synthesize the spotifyApp property specific to this controller.
@synthesize spotifyApp = _spotifyApp;

// Initializes the SpotifyController.
// Sets the player name, bundle identifier, and attempts to get the
// Spotify application instance using the provided strategy.
- (instancetype)initWithStrategy:(id<PlaybackControlStrategy>)strategy {
    self = [super init];
    if (self) {
        _strategy = strategy;
        _playerName = @"Spotify"; // User-facing name
        _bundleIdentifier = @"com.spotify.client"; // Official bundle ID for Spotify

        // Obtain the Spotify application instance using the strategy.
        // This typically involves the strategy calling `[SBApplication applicationWithBundleIdentifier:]`.
        // The result is cast to SpotifyApplication * for type-specific interactions.
        // This might return nil if Spotify is not installed or if the strategy doesn't use SBApplication.
        id appInstance = [_strategy applicationInstanceWithBundleIdentifier:_bundleIdentifier];
        if (appInstance && [appInstance isKindOfClass:[SBApplication class]]) {
            // We expect an SBApplication or a subclass like SpotifyApplication from ScriptingBridgeStrategy
            _spotifyApp = (SpotifyApplication *)appInstance;
        } else {
            // Handle cases where the instance isn't what's expected or is nil.
            // For strategies not returning SBApplication, _spotifyApp might remain nil,
            // and control methods must be implemented accordingly in the strategy.
            _spotifyApp = nil;
            NSLog(@"SpotifyController: Failed to get SpotifyApplication instance or strategy returned an unexpected type.");
        }
    }
    return self;
}

// Sends a play/pause command to Spotify via the strategy.
// Checks if Spotify is running before sending the command.
- (void)playPause {
    if ([self isRunning]) { // Ensure the app is running before trying to control it.
        [self.strategy sendPlayPauseCommandToApp:self.spotifyApp];
    } else {
        NSLog(@"SpotifyController: Spotify is not running, playPause command ignored.");
    }
}

// Sends a next track command to Spotify via the strategy.
// Checks if Spotify is running.
- (void)nextTrack {
    if ([self isRunning]) {
        [self.strategy sendNextTrackCommandToApp:self.spotifyApp];
    } else {
        NSLog(@"SpotifyController: Spotify is not running, nextTrack command ignored.");
    }
}

// Sends a previous track command to Spotify via the strategy.
// Checks if Spotify is running.
- (void)previousTrack {
    if ([self isRunning]) {
        [self.strategy sendPreviousTrackCommandToApp:self.spotifyApp];
    } else {
        NSLog(@"SpotifyController: Spotify is not running, previousTrack command ignored.");
    }
}

// Checks if Spotify is running using the strategy.
// The strategy is responsible for the actual check (e.g., using NSRunningApplication or SBApplication's isRunning).
- (BOOL)isRunning {
    return [self.strategy isAppRunning:self.bundleIdentifier];
}

// Checks if Spotify is currently playing using the strategy.
// Returns NO if Spotify is not running. Otherwise, queries the strategy.
// The strategy's implementation for isAppPlaying will handle Spotify-specific state checks.
- (BOOL)isPlaying {
    if (![self isRunning]) {
        return NO; // Not running implies not playing.
    }
    // Delegate to the strategy, passing the specific Spotify SBApplication instance.
    return [self.strategy isAppPlaying:self.spotifyApp];
}

@end
