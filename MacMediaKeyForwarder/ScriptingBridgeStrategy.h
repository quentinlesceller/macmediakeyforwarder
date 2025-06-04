//
//  ScriptingBridgeStrategy.h
//  MacMediaKeyForwarder
//
//  Created by [Your Name] on [Date].
//  Copyright © 2023 [Your Name]. All rights reserved.
//
//  This class implements the PlaybackControlStrategy protocol using Apple's ScriptingBridge framework.
//  It allows interaction with applications that support AppleScript and have a ScriptingBridge interface,
//  such as Spotify, iTunes, and Music.app.
//

#import <Foundation/Foundation.h>
#import "PlaybackControlStrategy.h" // Conforms to this protocol
#import <ScriptingBridge/ScriptingBridge.h> // Uses SBApplication

// Specific application ScriptingBridge headers (like Spotify.h, iTunes.h) are imported in the .m file
// to keep this header clean and reduce coupling, as this strategy aims to be somewhat generic
// in its interface, while the .m handles specific application types.

NS_ASSUME_NONNULL_BEGIN

// Implements playback control by sending AppleScript commands via the ScriptingBridge.
@interface ScriptingBridgeStrategy : NSObject <PlaybackControlStrategy>

// Methods from the PlaybackControlStrategy protocol are implemented in the .m file.
// These include:
// - applicationInstanceWithBundleIdentifier:
// - sendPlayPauseCommandToApp:
// - sendNextTrackCommandToApp:
// - sendPreviousTrackCommandToApp:
// - isAppRunning:
// - isAppPlaying:

@end

NS_ASSUME_NONNULL_END
