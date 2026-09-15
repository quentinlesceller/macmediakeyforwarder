//
//  AppDelegate.swift
//  MacMediaKeyForwarder
//
//  Swift port of the original Objective-C AppDelegate by Milan Toth.
//
//  Intercepts the system-defined media key events with a CGEventTap and
//  forwards them to iTunes/Music and/or Spotify over Scripting Bridge and to
//  Cider and Spotifast over their local RPC channels. A status-bar menu
//  offers the quick controls (pause, prioritized player) and a Settings
//  window holds everything else.
//

import ApplicationServices
import Cocoa
import Combine
import CoreServices
import ScriptingBridge
import SwiftUI

// MARK: - State

// Raw values are persisted in UserDefaults and must stay in sync with the
// values written by the original Objective-C version so existing preferences
// keep working after the migration.

enum MediaKeysPrioritize: Int {
    // Normal behavior (no priority; send events to every player that is open).
    case none = 0
    // If several apps are open, prioritize iTunes.
    case iTunes = 1
    // If several apps are open, prioritize Spotify.
    case spotify = 2
    // If several apps are open, prioritize Cider.
    case cider = 3
    // If several apps are open, prioritize Spotifast.
    case spotifast = 4
}

enum PauseState: Int {
    case none = 0
    // Forwarding paused.
    case pause = 1
    // Pause automatically when no supported player is running.
    case automatic = 2
}

enum KeyHoldState: Int {
    case none
    case waiting
    case holding
}

// MARK: - Media key constants

// Media key codes from <IOKit/hidsystem/ev_keymap.h>.
private let NX_KEYTYPE_PLAY = 16
private let NX_KEYTYPE_NEXT = 17
private let NX_KEYTYPE_PREVIOUS = 18
private let NX_KEYTYPE_FAST = 19
private let NX_KEYTYPE_REWIND = 20

// NX_SYSDEFINED system-defined event type. It has no named CGEventType case,
// so we compare against the raw value (14) directly.
private let kSystemDefinedEventTypeRawValue: UInt32 = 14

// MARK: - Event tap callback

// CGEventTapCallBack must be a C function pointer and therefore cannot capture
// context; the AppDelegate instance is threaded through `refcon`.
private func tapEventCallback(proxy: CGEventTapProxy,
                              type: CGEventType,
                              event: CGEvent,
                              refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }
    let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
    return delegate.handle(type: type, event: event)
}

@objc(AppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // MARK: State

    private let settings = AppSettings.shared
    private var subscriptions: Set<AnyCancellable> = []
    private var keyHoldStatus: KeyHoldState = .none
    private var pauseState: PauseState { settings.pauseState }
    private var mediaKeysPriority: MediaKeysPrioritize { settings.priority }
    private let ciderController = CiderController()
    private let spotifastController = SpotifastController()

    // MARK: UI / system

    private var statusItem: NSStatusItem!
    private var eventPort: CFMachPort?
    private var eventPortSource: CFRunLoopSource?
    private var accessibilityPollTimer: Timer?
    private var priorityOptionItems: [NSMenuItem] = []
    private var pauseItem: NSMenuItem!
    private var settingsWindow: NSWindow?

    // The bundle identifier for the local "iTunes" player (Music on 10.15+).
    private var iTunesBundleIdentifier: String {
        if #available(macOS 10.15, *) {
            return "com.apple.music"
        } else {
            return "com.apple.iTunes"
        }
    }

    // MARK: - Event handling

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout {
            if let eventPort = eventPort {
                CGEvent.tapEnable(tap: eventPort, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .tapDisabledByUserInput {
            return Unmanaged.passUnretained(event)
        }

        if type.rawValue != kSystemDefinedEventTypeRawValue {
            return Unmanaged.passUnretained(event)
        }

        guard let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }

        if nsEvent.subtype.rawValue != 8 {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = Int((nsEvent.data1 & 0xFFFF0000) >> 16)

        if keyCode != NX_KEYTYPE_PLAY &&
            keyCode != NX_KEYTYPE_FAST &&
            keyCode != NX_KEYTYPE_REWIND &&
            keyCode != NX_KEYTYPE_PREVIOUS &&
            keyCode != NX_KEYTYPE_NEXT {
            return Unmanaged.passUnretained(event)
        }

        let musicApp = SBApplication(bundleIdentifier: iTunesBundleIdentifier)
        let spotifyApp = SBApplication(bundleIdentifier: "com.spotify.client")
        // SBApplication is declared to conform to both protocols, so these are
        // plain upcasts that forward the transport commands at runtime.
        let iTunes: iTunesApplication? = musicApp
        let spotify: SpotifyApplication? = spotifyApp

        let musicRunning = musicApp?.isRunning ?? false
        let spotifyRunning = spotifyApp?.isRunning ?? false
        let ciderRunning = ciderController.isRunning
        let spotifastRunning = spotifastController.isRunning

        if pauseState == .pause {
            return Unmanaged.passUnretained(event)
        }

        if pauseState == .automatic {
            if !spotifyRunning && !musicRunning && !ciderRunning && !spotifastRunning {
                return Unmanaged.passUnretained(event)
            }
        }

        let keyFlags = nsEvent.data1 & 0x0000FFFF
        let keyIsPressed = ((keyFlags & 0xFF00) >> 8) == 0xA

        if keyIsPressed {
            switch mediaKeysPriority {
            case .iTunes:
                switch keyCode {
                case NX_KEYTYPE_PLAY:
                    iTunes?.playpause?()
                default:
                    if keyHoldStatus == .none {
                        keyHoldStatus = .waiting
                    } else if keyHoldStatus == .waiting {
                        keyHoldStatus = .holding
                        switch keyCode {
                        case NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST:
                            iTunes?.fastForward?()
                        case NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND:
                            iTunes?.rewind?()
                        default:
                            break
                        }
                    }
                }
            case .spotify:
                switch keyCode {
                case NX_KEYTYPE_PLAY:
                    spotify?.playpause?()
                case NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST:
                    spotify?.nextTrack?()
                case NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND:
                    spotify?.previousTrack?()
                default:
                    break
                }
            case .cider:
                switch keyCode {
                case NX_KEYTYPE_PLAY:
                    ciderController.playPause()
                case NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST:
                    ciderController.nextTrack()
                case NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND:
                    ciderController.previousTrack()
                default:
                    break
                }
            case .spotifast:
                switch keyCode {
                case NX_KEYTYPE_PLAY:
                    spotifastController.playPause()
                case NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST:
                    spotifastController.nextTrack()
                case NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND:
                    spotifastController.previousTrack()
                default:
                    break
                }
            case .none:
                switch keyCode {
                case NX_KEYTYPE_PLAY:
                    if spotifyRunning { spotify?.playpause?() }
                    if musicRunning { iTunes?.playpause?() }
                    if ciderRunning { ciderController.playPause() }
                    if spotifastRunning { spotifastController.playPause() }
                case NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST:
                    if spotifyRunning { spotify?.nextTrack?() }
                    if musicRunning { iTunes?.nextTrack?() }
                    if ciderRunning { ciderController.nextTrack() }
                    if spotifastRunning { spotifastController.nextTrack() }
                case NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND:
                    if spotifyRunning { spotify?.previousTrack?() }
                    if musicRunning { iTunes?.backTrack?() }
                    if ciderRunning { ciderController.previousTrack() }
                    if spotifastRunning { spotifastController.previousTrack() }
                default:
                    break
                }
            }
        } else {
            switch keyHoldStatus {
            case .waiting:
                if mediaKeysPriority == .iTunes {
                    switch keyCode {
                    case NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST:
                        iTunes?.nextTrack?()
                    case NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND:
                        iTunes?.backTrack?()
                    default:
                        break
                    }
                }
            case .holding:
                // Stop fast forwarding / rewinding.
                if mediaKeysPriority == .iTunes {
                    iTunes?.resume?()
                }
            case .none:
                break
            }
            keyHoldStatus = .none
        }

        // Stop propagation.
        return nil
    }

    // MARK: - Application lifecycle

    func applicationDidBecomeActive(_ notification: Notification) {
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        keyHoldStatus = .none

        // Version string.
        let info = Bundle.main.infoDictionary ?? [:]
        let shortVersion = info["CFBundleShortVersionString"] as? String ?? ""
        let versionString = "Version \(shortVersion)"

        let menu = NSMenu()
        menu.addItem(withTitle: versionString, action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator()) // A thin grey line.

        pauseItem = menu.addItem(withTitle: NSLocalizedString("Pause", comment: "Pause"),
                                 action: #selector(togglePause),
                                 keyEquivalent: "")

        menu.addItem(NSMenuItem.separator()) // A thin grey line.

        priorityOptionItems.append(menu.addItem(withTitle: NSLocalizedString("Send events to all players", comment: "Send events to all players"),
                                                action: #selector(prioritizeNone),
                                                keyEquivalent: ""))
        priorityOptionItems.append(menu.addItem(withTitle: NSLocalizedString("Prioritize iTunes", comment: "Prioritize iTunes"),
                                                action: #selector(prioritizeITunes),
                                                keyEquivalent: ""))
        priorityOptionItems.append(menu.addItem(withTitle: NSLocalizedString("Prioritize Spotify", comment: "Prioritize Spotify"),
                                                action: #selector(prioritizeSpotify),
                                                keyEquivalent: ""))
        priorityOptionItems.append(menu.addItem(withTitle: NSLocalizedString("Prioritize Cider", comment: "Prioritize Cider"),
                                                action: #selector(prioritizeCider),
                                                keyEquivalent: ""))
        priorityOptionItems.append(menu.addItem(withTitle: NSLocalizedString("Prioritize Spotifast", comment: "Prioritize Spotifast"),
                                                action: #selector(prioritizeSpotifast),
                                                keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator()) // A thin grey line.

        menu.addItem(withTitle: NSLocalizedString("Settings…", comment: "Settings…"),
                     action: #selector(openSettings),
                     keyEquivalent: ",")

        menu.addItem(NSMenuItem.separator()) // A thin grey line.

        menu.addItem(withTitle: NSLocalizedString("Donate if you like the app", comment: "Donate if you like the app"),
                     action: #selector(support),
                     keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("Check for updates", comment: "Check for updates"),
                     action: #selector(checkForUpdates),
                     keyEquivalent: "")
        menu.addItem(withTitle: NSLocalizedString("Quit", comment: "Quit"),
                     action: #selector(quit),
                     keyEquivalent: "")

        let image = NSImage(named: "icon")
        image?.isTemplate = true

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.toolTip = "Mac Media Key Forwarder"
        statusItem.button?.image = image
        statusItem.menu = menu
        statusItem.behavior = .removalAllowed

        observeSettings()

        if !startEventTap() {
            // Accessibility has not been granted yet. Ask for it the modern way
            // (a system prompt with an "Open System Settings" button) and start
            // forwarding automatically once it is granted, with no relaunch.
            requestAccessibilityPermission()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if settings.hideFromMenuBar {
            settings.hideFromMenuBar = false
        }
        return true
    }

    // MARK: - Settings observation

    /// Applies every preference as it changes, from the menu or the Settings
    /// window alike. @Published emits before the property is written, so the
    /// sinks are delivered on the next main-queue turn and read the new value.
    private func observeSettings() {
        settings.$pauseState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.applyPauseState(state) }
            .store(in: &subscriptions)

        settings.$priority
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateOptionState() }
            .store(in: &subscriptions)

        settings.$hideFromMenuBar
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hidden in self?.applyHideFromMenuBar(hidden) }
            .store(in: &subscriptions)
    }

    private func applyPauseState(_ state: PauseState) {
        if state == .pause {
            stopEventSession()
        } else {
            startEventSession()
        }
        pauseItem.state = (state == .pause) ? .on : .off
    }

    private func applyHideFromMenuBar(_ hidden: Bool) {
        // Hiding the icon leaves no way to reach the app unless it comes back at
        // login, so turn that on as before.
        if hidden && !LaunchAtLogin.isEnabled {
            settings.launchAtLogin = true
        }
        statusItem.isVisible = !hidden
    }

    // MARK: - Event tap & permissions

    /// Creates the media-key event tap and starts the session. Returns false if
    /// the tap could not be created, which normally means Accessibility access
    /// has not been granted yet.
    @discardableResult
    private func startEventTap() -> Bool {
        let mask = CGEventMask(1) << CGEventMask(kSystemDefinedEventTypeRawValue)
        eventPort = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                      place: .headInsertEventTap,
                                      options: .defaultTap,
                                      eventsOfInterest: mask,
                                      callback: tapEventCallback,
                                      userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let eventPort = eventPort else { return false }
        eventPortSource = CFMachPortCreateRunLoopSource(kCFAllocatorSystemDefault, eventPort, 0)
        startEventSession()
        return true
    }

    /// Triggers the standard macOS Accessibility prompt (which offers an "Open
    /// System Settings" button) and then polls until the permission is granted,
    /// starting the event tap as soon as it succeeds. No relaunch required.
    private func requestAccessibilityPermission() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)

        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if self.startEventTap() {
                timer.invalidate()
                self.accessibilityPollTimer = nil
            }
        }
    }

    // MARK: - Event session

    private func startEventSession() {
        guard let eventPortSource = eventPortSource else { return }
        // Add the tap source to the AppKit main run loop. We must NOT call
        // CFRunLoopRun() here: NSApplicationMain already runs the main loop, so a
        // nested run loop would block applicationDidFinishLaunching and freeze the
        // UI on macOS Tahoe (#26/#29/#30). The already-running loop services the source.
        if pauseState != .pause && !CFRunLoopContainsSource(CFRunLoopGetCurrent(), eventPortSource, .commonModes) {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), eventPortSource, .commonModes)
        }
    }

    private func stopEventSession() {
        guard let eventPortSource = eventPortSource else { return }
        // Only remove the source; do NOT call CFRunLoopStop(), which would stop the
        // AppKit main run loop and effectively kill the app.
        if CFRunLoopContainsSource(CFRunLoopGetCurrent(), eventPortSource, .commonModes) {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), eventPortSource, .commonModes)
        }
    }

    // MARK: - Menu actions

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func support() {
        if let url = URL(string: "https://paypal.me/milgra") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func checkForUpdates() {
        if let url = URL(string: "https://github.com/quentinlesceller/macmediakeyforwarder/releases") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func togglePause() {
        settings.pauseState = (settings.pauseState == .pause) ? .none : .pause
    }

    // MARK: App prioritization

    @objc private func prioritizeNone() {
        settings.priority = .none
    }

    @objc private func prioritizeITunes() {
        settings.priority = .iTunes
    }

    @objc private func prioritizeSpotify() {
        settings.priority = .spotify
    }

    @objc private func prioritizeCider() {
        settings.priority = .cider
    }

    @objc private func prioritizeSpotifast() {
        settings.priority = .spotifast
    }

    // MARK: Settings window

    @objc private func openSettings() {
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(settings: settings))
            let window = NSWindow(contentViewController: controller)
            window.title = NSLocalizedString("Settings", comment: "Settings")
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        // The app is a background (LSUIElement) app, so bring the window forward.
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - UI refresh

    private func updateOptionState() {
        // Tick the selected priority item.
        for (index, item) in priorityOptionItems.enumerated() {
            item.state = (index == mediaKeysPriority.rawValue) ? .on : .off
        }
    }
}
