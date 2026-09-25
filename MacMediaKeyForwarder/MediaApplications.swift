//
//  MediaApplications.swift
//  MacMediaKeyForwarder
//
//  Minimal Scripting Bridge interfaces for the players we control.
//
//  These mirror the subset of the generated Music and Spotify scripting
//  headers that the app actually uses. Declaring the commands as `@objc
//  optional` lets Scripting Bridge forward them to the target application at
//  runtime; if a given app does not implement a command the optional call
//  simply no-ops.
//

import ScriptingBridge

// The Music transport commands used by the forwarder.
@objc protocol MusicApplication {
    @objc optional func playpause()
    @objc optional func nextTrack()
    @objc optional func backTrack()
    @objc optional func fastForward()
    @objc optional func rewind()
    @objc optional func resume()
}

// The Spotify transport commands used by the forwarder.
@objc protocol SpotifyApplication {
    @objc optional func playpause()
    @objc optional func nextTrack()
    @objc optional func previousTrack()
}

// Scripting Bridge dynamically forwards these selectors, so an empty
// conformance is all that is required. `isRunning` is provided by SBApplication.
extension SBApplication: MusicApplication, SpotifyApplication {}
