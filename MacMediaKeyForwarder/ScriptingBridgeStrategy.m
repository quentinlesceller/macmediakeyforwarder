//
//  ScriptingBridgeStrategy.m
//  MacMediaKeyForwarder
//
//  Created by [Your Name] on [Date].
//  Copyright © 2023 [Your Name]. All rights reserved.
//
//  Implementation of the ScriptingBridgeStrategy class.
//  This strategy uses ScriptingBridge to control media applications.
//

#import "ScriptingBridgeStrategy.h"
#import "Spotify.h" // For SpotifyApplication class and SpotifyEPlSPlaying enum
#import "iTunes.h"  // For iTunesApplication class and iTunesEPlSPlaying enum
                    // Note: iTunes.h is typically used for Music.app as well if generated from its sdef.

@implementation ScriptingBridgeStrategy

// Returns an SBApplication instance for the given bundle identifier.
// SBApplication will attempt to launch the application if it's not already running
// when a command is sent to it, or when certain properties are accessed.
// The PlayerController using this strategy should ideally check `isAppRunning`
// before attempting to send commands if launching the app is not desired.
- (nullable SBApplication *)applicationInstanceWithBundleIdentifier:(NSString *)bundleIdentifier {
    // `applicationWithBundleIdentifier:` might return an existing instance or create a new proxy.
    // It does not itself launch the application. Launching typically happens upon sending the first message.
    return [SBApplication applicationWithBundleIdentifier:bundleIdentifier];
}

// Sends the 'playpause' command to the application instance.
// Most ScriptingBridge-controllable music apps (Spotify, iTunes, Music) respond to 'playpause'.
- (void)sendPlayPauseCommandToApp:(nullable SBApplication *)applicationInstance {
    if (!applicationInstance) {
        NSLog(@"ScriptingBridgeStrategy: applicationInstance is nil for playPause.");
        return;
    }
    // Check if the application instance can respond to the 'playpause' selector.
    if ([applicationInstance respondsToSelector:@selector(playpause)]) {
        // Type casting to id is a common way to call methods on SBApplication instances
        // if you don't have the specific generated header or want to be more generic.
        // However, since we often have specific instances (like SpotifyApplication),
        // direct calls are also possible and type-safer if the instance type is known.
        // Here, performSelector is used for dynamic dispatch.
        [(id)applicationInstance playpause];
    } else {
        NSLog(@"ScriptingBridgeStrategy: %@ does not respond to playpause.", applicationInstance.bundleIdentifier);
    }
}

// Sends the 'nextTrack' command.
- (void)sendNextTrackCommandToApp:(nullable SBApplication *)applicationInstance {
    if (!applicationInstance) {
        NSLog(@"ScriptingBridgeStrategy: applicationInstance is nil for nextTrack.");
        return;
    }
    if ([applicationInstance respondsToSelector:@selector(nextTrack)]) {
        [(id)applicationInstance nextTrack];
    } else {
        NSLog(@"ScriptingBridgeStrategy: %@ does not respond to nextTrack.", applicationInstance.bundleIdentifier);
    }
}

// Sends the 'previousTrack' or 'backTrack' command.
// Spotify uses 'previousTrack', while iTunes/Music.app uses 'backTrack'.
- (void)sendPreviousTrackCommandToApp:(nullable SBApplication *)applicationInstance {
    if (!applicationInstance) {
        NSLog(@"ScriptingBridgeStrategy: applicationInstance is nil for previousTrack/backTrack.");
        return;
    }
    // Check the class of the application instance to use the correct selector.
    if ([applicationInstance isKindOfClass:[iTunesApplication class]]) {
        iTunesApplication *iTunesApp = (iTunesApplication *)applicationInstance;
        if ([iTunesApp respondsToSelector:@selector(backTrack)]) {
            [iTunesApp backTrack];
        } else {
            NSLog(@"ScriptingBridgeStrategy: iTunes/Music instance does not respond to backTrack.");
        }
    } else if ([applicationInstance isKindOfClass:[SpotifyApplication class]]) {
        SpotifyApplication *spotifyApp = (SpotifyApplication *)applicationInstance;
        if ([spotifyApp respondsToSelector:@selector(previousTrack)]) {
            [spotifyApp previousTrack];
        } else {
            NSLog(@"ScriptingBridgeStrategy: Spotify instance does not respond to previousTrack.");
        }
    } else {
        // Fallback or generic attempt if type is unknown but conforms to SBApplication
        // This is less likely to succeed without knowing the correct selector.
        if ([applicationInstance respondsToSelector:@selector(previousTrack)]) { // Try Spotify's version
            [(id)applicationInstance previousTrack];
        } else if ([applicationInstance respondsToSelector:@selector(backTrack)]) { // Try iTunes' version
            [(id)applicationInstance backTrack];
        } else {
             NSLog(@"ScriptingBridgeStrategy: Unknown application type or does not respond to previousTrack/backTrack: %@", applicationInstance.bundleIdentifier);
        }
    }
}

// Checks if the application with the given bundle identifier is running.
// This creates a temporary SBApplication instance just to check its 'isRunning' property.
- (BOOL)isAppRunning:(NSString *)bundleIdentifier {
    if (!bundleIdentifier) return NO;
    // Getting the SBApplication instance here does not launch the app.
    SBApplication *app = [SBApplication applicationWithBundleIdentifier:bundleIdentifier];
    // The 'isRunning' property reflects the current state of the application.
    return app && [app isRunning];
}

// Checks if the application instance is currently playing.
// This requires app-specific knowledge of how playback state is exposed via ScriptingBridge.
- (BOOL)isAppPlaying:(nullable SBApplication *)applicationInstance {
    // If no instance is provided or if it's not running, it can't be playing.
    if (!applicationInstance || ![applicationInstance isRunning]) {
        return NO;
    }

    // Spotify: Check 'playerState' property.
    if ([applicationInstance isKindOfClass:[SpotifyApplication class]]) {
        SpotifyApplication *spotify = (SpotifyApplication *)applicationInstance;
        // Ensure the object responds to 'playerState' to avoid runtime errors if the sdef is different.
        if ([spotify respondsToSelector:@selector(playerState)]) {
            return spotify.playerState == SpotifyEPlSPlaying; // Compare with the 'Playing' enum state.
        }
    }
    // iTunes/Music.app: Check 'playerState' property.
    else if ([applicationInstance isKindOfClass:[iTunesApplication class]]) {
        iTunesApplication *iTunes = (iTunesApplication *)applicationInstance;
        // Ensure the object responds to 'playerState'.
        if ([iTunes respondsToSelector:@selector(playerState)]) {
            return iTunes.playerState == iTunesEPlSPlaying; // Compare with the 'Playing' enum state.
        }
    }

    NSLog(@"ScriptingBridgeStrategy: Could not determine playback state for %@.", applicationInstance.bundleIdentifier);
    return NO; // Default to NO if state cannot be determined.
}

@end
