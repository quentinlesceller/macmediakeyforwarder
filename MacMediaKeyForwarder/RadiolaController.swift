//
//  RadiolaController.swift
//  MacMediaKeyForwarder
//
//  Controls the Radiola internet radio player
//  (https://github.com/SokoloffA/radiola). Radiola ships no AppleScript
//  dictionary and no local RPC channel, but it has a configurable global
//  "toggle play and pause" shortcut (Settings > Controls), so play/pause is
//  sent by posting that shortcut. The user never presses it; it is only the
//  channel between the two apps.
//
//  Radiola plays streams, so it has no next or previous track to send.
//

import Cocoa

final class RadiolaController {

    static let bundleIdentifier = "com.github.SokoloffA.Radiola"

    // Control-Option-Command-P. Must match the shortcut recorded in Radiola
    // under "Global shortcut to toggle play and pause".
    static let toggleShortcutDescription = "⌃⌥⌘P"
    private static let toggleShortcutVirtualKeyCode: CGKeyCode = 0x23 // kVK_ANSI_P
    private static let toggleShortcutModifierFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).isEmpty
    }

    func playPause() {
        let eventSource = CGEventSource(stateID: .hidSystemState)
        for isKeyDown in [true, false] {
            guard let keyEvent = CGEvent(keyboardEventSource: eventSource,
                                         virtualKey: Self.toggleShortcutVirtualKeyCode,
                                         keyDown: isKeyDown) else {
                NSLog("RadiolaController: could not create the toggle shortcut key event")
                return
            }
            keyEvent.flags = Self.toggleShortcutModifierFlags
            keyEvent.post(tap: .cghidEventTap)
        }
    }
}
