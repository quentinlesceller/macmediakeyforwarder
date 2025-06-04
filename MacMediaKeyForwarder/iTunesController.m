//
//  iTunesController.m
//  MacMediaKeyForwarder
//
//  Created by [Your Name] on [Date].
//  Copyright © 2023 [Your Name]. All rights reserved.
//
//  Implementation of the iTunesController class.
//

#import "iTunesController.h"
#import "iTunes.h" // Required for iTunesApplication class and enum constants like iTunesEPlSPlaying

@implementation iTunesController

// Synthesize properties declared in the PlayerController protocol.
@synthesize strategy = _strategy;
@synthesize playerName = _playerName;
@synthesize bundleIdentifier = _bundleIdentifier;
// Synthesize the iTunesApp property specific to this controller.
@synthesize iTunesApp = _iTunesApp;

// Determines the appropriate bundle identifier for iTunes or Music application
// based on the version of macOS.
// On macOS 10.15 Catalina and later, iTunes was replaced by the Music app.
// @return @"com.apple.music" for macOS 10.15+, otherwise @"com.apple.iTunes".
+ (NSString *)iTunesBundleIdentifier {
    if (@available(macOS 10.15, *)) {
        return @"com.apple.music"; // Music app on Catalina and newer
    } else {
        return @"com.apple.iTunes"; // iTunes app on Mojave and older
    }
}

// Initializes the iTunesController.
// Sets the player name, determines the correct bundle identifier based on macOS version,
// and attempts to get the application instance (iTunes/Music) using the provided strategy.
- (instancetype)initWithStrategy:(id<PlaybackControlStrategy>)strategy {
    self = [super init];
    if (self) {
        _strategy = strategy;
        // PlayerName is kept as "iTunes" for consistent internal identification,
        // particularly for prioritization logic in AppDelegate, regardless of
        // whether it's controlling iTunes or Music.app.
        _playerName = @"iTunes";
        _bundleIdentifier = [iTunesController iTunesBundleIdentifier]; // Dynamically get correct bundle ID

        // Obtain the iTunes/Music application instance using the strategy.
        // This typically involves the strategy calling `[SBApplication applicationWithBundleIdentifier:]`.
        // The result is cast to iTunesApplication* for type-specific interactions.
        // This might return nil if the app is not installed or if the strategy doesn't use SBApplication.
        id appInstance = [_strategy applicationInstanceWithBundleIdentifier:_bundleIdentifier];
        if (appInstance && [appInstance isKindOfClass:[SBApplication class]]) {
            // We expect an SBApplication or a subclass like iTunesApplication from ScriptingBridgeStrategy
             _iTunesApp = (iTunesApplication *)appInstance;
        } else {
            _iTunesApp = nil;
            NSLog(@"iTunesController: Failed to get iTunesApplication instance for %@ or strategy returned an unexpected type.", _bundleIdentifier);
        }
    }
    return self;
}

// Sends a play/pause command via the strategy.
// Checks if the application is running before sending the command.
- (void)playPause {
    if ([self isRunning]) {
        [self.strategy sendPlayPauseCommandToApp:self.iTunesApp];
    } else {
        NSLog(@"iTunesController: %@ is not running, playPause command ignored.", self.bundleIdentifier);
    }
}

// Sends a next track command via the strategy.
// Checks if the application is running.
- (void)nextTrack {
    if ([self isRunning]) {
        [self.strategy sendNextTrackCommandToApp:self.iTunesApp];
    } else {
        NSLog(@"iTunesController: %@ is not running, nextTrack command ignored.", self.bundleIdentifier);
    }
}

// Sends a previous track command (often called 'backTrack' in iTunes/Music sdef) via the strategy.
// Checks if the application is running.
- (void)previousTrack {
    if ([self isRunning]) {
        // Note: The strategy's sendPreviousTrackCommandToApp needs to handle
        // the fact that iTunes/Music uses 'backTrack' selector.
        [self.strategy sendPreviousTrackCommandToApp:self.iTunesApp];
    } else {
        NSLog(@"iTunesController: %@ is not running, previousTrack command ignored.", self.bundleIdentifier);
    }
}

// Checks if iTunes/Music is running using the strategy.
- (BOOL)isRunning {
    return [self.strategy isAppRunning:self.bundleIdentifier];
}

// Checks if iTunes/Music is currently playing using the strategy.
// Returns NO if not running. Otherwise, queries the strategy.
- (BOOL)isPlaying {
    if (![self isRunning]) {
        return NO;
    }
    // Delegate to the strategy, passing the specific iTunes SBApplication instance.
    return [self.strategy isAppPlaying:self.iTunesApp];
}

@end
