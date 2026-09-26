//
//  AppSettings.swift
//  MacMediaKeyForwarder
//
//  The user-facing preferences. Backed by the same UserDefaults keys the app
//  has always written, so existing settings carry over unchanged. Both the
//  status-bar menu and the Settings window read and write through this
//  object; the app delegate observes it to apply changes.
//

import Cocoa
import Combine

final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    // Raw values are persisted under the keys the original Objective-C version
    // used; see MediaKeysPrioritize / PauseState for the value contract.
    private static let priorityKey = "user_priority_option"
    private static let pauseKey = "user_pause_option"
    private static let hideFromMenuBarKey = "user_hide_from_menu_bar_option"
    private static let forwardVolumeToMusicKey = "user_forward_volume_to_music_option"
    private static let launchPlayerHiddenKey = "user_launch_hidden_option"

    private let defaults = UserDefaults.standard

    /// Which player receives the media keys when several are running.
    @Published var priority: MediaKeysPrioritize {
        didSet { defaults.set(priority.rawValue, forKey: Self.priorityKey) }
    }

    /// Whether forwarding is on, paused, or paused while no player runs.
    @Published var pauseState: PauseState {
        didSet { defaults.set(pauseState.rawValue, forKey: Self.pauseKey) }
    }

    /// Hides the status item; the app keeps running and shows it again when
    /// reopened from the Finder or Launchpad.
    @Published var hideFromMenuBar: Bool {
        didSet { defaults.set(hideFromMenuBar, forKey: Self.hideFromMenuBarKey) }
    }

    /// Also steps Music's own volume when the volume keys are pressed, so
    /// AirPlay speakers follow. The system volume still changes as usual.
    @Published var forwardVolumeToMusic: Bool {
        didSet { defaults.set(forwardVolumeToMusic, forKey: Self.forwardVolumeToMusicKey) }
    }

    /// Launches a prioritized Apple Music or Spotify hidden when a media key
    /// is pressed while it is not running, instead of bringing its window
    /// forward.
    @Published var launchPlayerHidden: Bool {
        didSet { defaults.set(launchPlayerHidden, forKey: Self.launchPlayerHiddenKey) }
    }

    /// Token for Cider's external application access. Stored trimmed; an empty
    /// value removes the key so CiderController sends no header.
    @Published var ciderApiToken: String {
        didSet {
            let trimmed = ciderApiToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                defaults.removeObject(forKey: CiderController.apiTokenKey)
            } else {
                defaults.set(trimmed, forKey: CiderController.apiTokenKey)
            }
        }
    }

    /// Launch-at-login lives in the system's login item registry rather than
    /// UserDefaults, so it is read live and written through LaunchAtLogin.
    var launchAtLogin: Bool {
        get { LaunchAtLogin.isEnabled }
        set {
            objectWillChange.send()
            if newValue {
                LaunchAtLogin.enable()
            } else {
                LaunchAtLogin.disable()
            }
        }
    }

    /// Re-reads state the system may have changed behind our back (login
    /// items can be toggled from System Settings).
    func refreshExternalState() {
        objectWillChange.send()
    }

    private init() {
        let priorityValue = (defaults.object(forKey: Self.priorityKey) as? NSNumber)?.intValue ?? 0
        priority = MediaKeysPrioritize(rawValue: priorityValue) ?? .none
        let pauseValue = (defaults.object(forKey: Self.pauseKey) as? NSNumber)?.intValue ?? 0
        pauseState = PauseState(rawValue: pauseValue) ?? .none
        hideFromMenuBar = defaults.bool(forKey: Self.hideFromMenuBarKey)
        forwardVolumeToMusic = defaults.bool(forKey: Self.forwardVolumeToMusicKey)
        launchPlayerHidden = defaults.bool(forKey: Self.launchPlayerHiddenKey)
        ciderApiToken = defaults.string(forKey: CiderController.apiTokenKey) ?? ""
    }
}
