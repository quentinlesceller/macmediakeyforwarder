//
//  MenuBarPlayerController.swift
//  MacMediaKeyForwarder
//
//  Controls players that offer neither an AppleScript dictionary nor a local
//  control API, but do list their transport commands in the macOS menu bar
//  (TIDAL under Playback, Deezer under Controls). The commands are triggered by
//  pressing those menu items through the Accessibility API, the same way a
//  System Events "click menu item" script would. It works while the player is
//  in the background and needs no extra permission: the app already requires
//  Accessibility access for its event tap.
//
//  Menu items are found by their English titles, in whichever top-level menu
//  holds both a "Next" and a "Previous" item, so a player renaming or moving
//  that menu does not break the lookup. The toggle item is matched by its title
//  too; TIDAL swaps it between "Play" and "Pause" with the playback state.
//

import ApplicationServices
import Cocoa

final class MenuBarPlayerController {

    private enum Command {
        case playPause
        case next
        case previous
    }

    private let bundleIdentifier: String

    // Accessibility calls are synchronous IPC into the player and would stall
    // the event tap if the player hangs, so they run on their own serial queue.
    private let queue: DispatchQueue

    init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
        queue = DispatchQueue(label: "MenuBarPlayerController.\(bundleIdentifier)")
    }

    // Only used to detect whether the player is running; pressing menu items
    // cannot launch the app the way an Apple Event can.
    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    func playPause() {
        perform(.playPause)
    }

    func nextTrack() {
        perform(.next)
    }

    func previousTrack() {
        perform(.previous)
    }

    // Fire-and-forget: media keys must never block the event tap, and there is
    // no meaningful recovery if the menu item cannot be found.
    private func perform(_ command: Command) {
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first?.processIdentifier else { return }
        queue.async {
            let application = AXUIElementCreateApplication(pid)
            // The default messaging timeout is several seconds; a player that
            // takes longer than this to answer should just miss the key press.
            AXUIElementSetMessagingTimeout(application, 1)
            guard let item = Self.menuItem(for: command, in: application) else { return }
            AXUIElementPerformAction(item, kAXPressAction as CFString)
        }
    }

    private static func menuItem(for command: Command, in application: AXUIElement) -> AXUIElement? {
        guard let menuBar = element(application, kAXMenuBarAttribute) else { return nil }
        for menuBarItem in children(menuBar) {
            // A menu bar item has a single AXMenu child holding its items.
            guard let menu = children(menuBarItem).first else { continue }
            let items = children(menu).map { (element: $0, title: normalizedTitle($0)) }
            let next = items.first { isNext($0.title) }
            let previous = items.first { isPrevious($0.title) }
            guard let next = next, let previous = previous else { continue }
            switch command {
            case .next:
                return next.element
            case .previous:
                return previous.element
            case .playPause:
                return items.first { isPlayPause($0.title) }?.element
            }
        }
        return nil
    }

    private static func isNext(_ title: String) -> Bool {
        title == "next" || title.hasPrefix("next ")
    }

    private static func isPrevious(_ title: String) -> Bool {
        title == "previous" || title.hasPrefix("previous ") || title == "prev"
    }

    private static func isPlayPause(_ title: String) -> Bool {
        let titles: Set<String> = ["play", "pause", "resume", "play/pause", "play / pause", "play-pause", "play or pause"]
        return titles.contains(title)
    }

    private static func normalizedTitle(_ element: AXUIElement) -> String {
        guard let title = attribute(element, kAXTitleAttribute) as? String else { return "" }
        return title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }
}
