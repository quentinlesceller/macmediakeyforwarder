//
//  AppDelegate.swift
//  MacMediaKeyForwarder
//
//  Swift port of the original Objective-C AppDelegate by Milan Toth.
//
//  Intercepts the system-defined media key events with a CGEventTap and
//  forwards them to iTunes/Music and/or Spotify over Scripting Bridge, with a
//  status-bar menu to control prioritization, pausing and launch-at-login.
//

import Cocoa
import CoreServices
import ScriptingBridge

// MARK: - State

// Raw values are persisted in UserDefaults and must stay in sync with the
// values written by the original Objective-C version so existing preferences
// keep working after the migration.

enum MediaKeysPrioritize: Int {
    // Normal behavior (no priority; send events to iTunes and Spotify if both are open).
    case none = 0
    // If both apps are open, prioritize iTunes over Spotify.
    case iTunes = 1
    // If both apps are open, prioritize Spotify over iTunes.
    case spotify = 2
}

enum PauseState: Int {
    case none = 0
    // Forwarding paused.
    case pause = 1
    // Pause automatically when neither iTunes nor Spotify is running.
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

    // MARK: UserDefaults keys

    private static let priorityOptionKey = "user_priority_option"
    private static let pauseOptionKey = "user_pause_option"
    private static let hideFromMenuBarOptionKey = "user_hide_from_menu_bar_option"

    // MARK: State

    private var pauseState: PauseState = .none
    private var keyHoldStatus: KeyHoldState = .none
    private var mediaKeysPriority: MediaKeysPrioritize = .none

    // MARK: UI / system

    private var statusItem: NSStatusItem!
    private var eventPort: CFMachPort?
    private var eventPortSource: CFRunLoopSource?
    private var priorityOptionItems: [NSMenuItem] = []
    private var pauseOptionItems: [NSMenuItem] = []
    private var startupItem: NSMenuItem!
    private var hideFromMenuBarItem: NSMenuItem!

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

        if pauseState == .pause {
            return Unmanaged.passUnretained(event)
        }

        if pauseState == .automatic {
            if !spotifyRunning && !musicRunning {
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
            case .none:
                switch keyCode {
                case NX_KEYTYPE_PLAY:
                    if spotifyRunning { spotify?.playpause?() }
                    if musicRunning { iTunes?.playpause?() }
                case NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST:
                    if spotifyRunning { spotify?.nextTrack?() }
                    if musicRunning { iTunes?.nextTrack?() }
                case NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND:
                    if spotifyRunning { spotify?.previousTrack?() }
                    if musicRunning { iTunes?.backTrack?() }
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
        // Initial state.
        pauseState = .none
        keyHoldStatus = .none
        mediaKeysPriority = .none

        let defaults = UserDefaults.standard
        if let option = defaults.object(forKey: Self.priorityOptionKey) as? NSNumber {
            mediaKeysPriority = MediaKeysPrioritize(rawValue: option.intValue) ?? .none
        }
        if let option = defaults.object(forKey: Self.pauseOptionKey) as? NSNumber {
            pauseState = PauseState(rawValue: option.intValue) ?? .none
        }

        // Version string.
        let info = Bundle.main.infoDictionary ?? [:]
        let shortVersion = info["CFBundleShortVersionString"] as? String ?? ""
        let buildVersion = info["CFBundleVersion"] as? String ?? ""
        let versionString = "Version \(shortVersion) (build \(buildVersion))"

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: versionString, action: nil, keyEquivalent: "")
        menu.addItem(NSMenuItem.separator()) // A thin grey line.

        pauseOptionItems.append(menu.addItem(withTitle: NSLocalizedString("Pause", comment: "Pause"),
                                             action: #selector(manualPause),
                                             keyEquivalent: ""))
        pauseOptionItems.append(menu.addItem(withTitle: NSLocalizedString("Pause if no player is running", comment: "Pause if no player is running"),
                                             action: #selector(autoPause),
                                             keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator()) // A thin grey line.

        priorityOptionItems.append(menu.addItem(withTitle: NSLocalizedString("Send events to both players", comment: "Send events to both players"),
                                                action: #selector(prioritizeNone),
                                                keyEquivalent: ""))
        priorityOptionItems.append(menu.addItem(withTitle: NSLocalizedString("Prioritize iTunes", comment: "Prioritize iTunes"),
                                                action: #selector(prioritizeITunes),
                                                keyEquivalent: ""))
        priorityOptionItems.append(menu.addItem(withTitle: NSLocalizedString("Prioritize Spotify", comment: "Prioritize Spotify"),
                                                action: #selector(prioritizeSpotify),
                                                keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator()) // A thin grey line.

        startupItem = menu.addItem(withTitle: NSLocalizedString("Open at login", comment: "Open at login"),
                                   action: #selector(toggleStartupItem),
                                   keyEquivalent: "")
        hideFromMenuBarItem = menu.addItem(withTitle: NSLocalizedString("Hide from menu bar", comment: "Hide from menu bar"),
                                           action: #selector(hideFromMenuBar),
                                           keyEquivalent: "")
        menu.addItem(NSMenuItem.separator()) // A thin grey line.

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
        statusItem.isVisible = !shouldHideFromMenuBar

        updateStartupItemState()
        updatePauseState()
        updateOptionState()

        let mask = CGEventMask(1) << CGEventMask(kSystemDefinedEventTypeRawValue)
        eventPort = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                      place: .headInsertEventTap,
                                      options: .defaultTap,
                                      eventsOfInterest: mask,
                                      callback: tapEventCallback,
                                      userInfo: Unmanaged.passUnretained(self).toOpaque())

        if let eventPort = eventPort {
            eventPortSource = CFMachPortCreateRunLoopSource(kCFAllocatorSystemDefault, eventPort, 0)
            startEventSession()
        } else {
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Cannot start event listening. Please add Mac Media Key Forwarder to the \"Security & Privacy\" pane in System Preferences. Check \"Accessibility\" and \"Automation\" under the \"Privacy\" tab."
            alert.addButton(withTitle: "Ok")
            alert.runModal()
            exit(0)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if shouldHideFromMenuBar {
            setHideFromMenuBar(false)
            statusItem.isVisible = true
        }
        return true
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

    // MARK: App prioritization

    @objc private func prioritizeNone() {
        mediaKeysPriority = .none
        UserDefaults.standard.set(mediaKeysPriority.rawValue, forKey: Self.priorityOptionKey)
        updateOptionState()
    }

    @objc private func prioritizeITunes() {
        mediaKeysPriority = .iTunes
        UserDefaults.standard.set(mediaKeysPriority.rawValue, forKey: Self.priorityOptionKey)
        updateOptionState()
    }

    @objc private func prioritizeSpotify() {
        mediaKeysPriority = .spotify
        UserDefaults.standard.set(mediaKeysPriority.rawValue, forKey: Self.priorityOptionKey)
        updateOptionState()
    }

    @objc private func manualPause() {
        if pauseState != .pause {
            pauseState = .pause
            stopEventSession()
        } else {
            pauseState = .none
            startEventSession()
        }
        UserDefaults.standard.set(pauseState.rawValue, forKey: Self.pauseOptionKey)
        updatePauseState()
    }

    @objc private func autoPause() {
        if pauseState != .automatic {
            pauseState = .automatic
        } else {
            pauseState = .none
        }
        UserDefaults.standard.set(pauseState.rawValue, forKey: Self.pauseOptionKey)
        updatePauseState()

        startEventSession()
    }

    // MARK: Startup item

    @objc private func toggleStartupItem() {
        if LaunchAtLogin.isLoginItem {
            LaunchAtLogin.removeAppFromLoginItems()
        } else {
            LaunchAtLogin.addAppAsLoginItem()
        }
        updateStartupItemState()
    }

    @objc private func hideFromMenuBar() {
        setHideFromMenuBar(true)

        if !LaunchAtLogin.isLoginItem {
            LaunchAtLogin.addAppAsLoginItem()
        }

        statusItem.isVisible = false
    }

    private func setHideFromMenuBar(_ hidden: Bool) {
        UserDefaults.standard.set(hidden, forKey: Self.hideFromMenuBarOptionKey)
    }

    private var shouldHideFromMenuBar: Bool {
        UserDefaults.standard.bool(forKey: Self.hideFromMenuBarOptionKey)
    }

    // MARK: - UI refresh

    private func updateOptionState() {
        // Re-read the persisted choice, defaulting to "None".
        if let option = UserDefaults.standard.object(forKey: Self.priorityOptionKey) as? NSNumber {
            mediaKeysPriority = MediaKeysPrioritize(rawValue: option.intValue) ?? .none
        }

        // Tick the selected priority item.
        for (index, item) in priorityOptionItems.enumerated() {
            item.state = (index == mediaKeysPriority.rawValue) ? .on : .off
        }
    }

    private func updatePauseState() {
        pauseOptionItems[0].state = (pauseState == .pause) ? .on : .off
        pauseOptionItems[1].state = (pauseState == .automatic) ? .on : .off
    }

    private func updateStartupItemState() {
        startupItem.state = LaunchAtLogin.isLoginItem ? .on : .off
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateStartupItemState()
    }
}
