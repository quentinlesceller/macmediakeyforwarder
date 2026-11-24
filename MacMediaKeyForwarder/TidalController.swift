//
//  TidalController.swift
//  MacMediaKeyForwarder
//
//  Presses TIDAL's Playback menu items, found by shortcut because TIDAL translates their titles.
//

import Cocoa

final class TidalController {

    static let bundleIdentifier = "com.tidal.desktop"

    private static let nextShortcut = MenuItemShortcut(character: NSRightArrowFunctionKey, modifiers: [])
    private static let previousShortcut = MenuItemShortcut(character: NSLeftArrowFunctionKey, modifiers: [])

    private let menuBar = MenuBarPresser(bundleIdentifier: TidalController.bundleIdentifier)

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).isEmpty
    }

    // Play/Pause has no shortcut, so it is found as the first item of the Playback menu.
    func playPause() {
        menuBar.press { menus in Self.playbackMenu(in: menus)?.items.first }
    }

    func nextTrack() {
        menuBar.press { menus in Self.playbackMenu(in: menus)?.item(withShortcut: Self.nextShortcut) }
    }

    func previousTrack() {
        menuBar.press { menus in Self.playbackMenu(in: menus)?.item(withShortcut: Self.previousShortcut) }
    }

    private static func playbackMenu(in menus: [AccessibilityMenu]) -> AccessibilityMenu? {
        menus.first { $0.item(withShortcut: nextShortcut) != nil && $0.item(withShortcut: previousShortcut) != nil }
    }
}
