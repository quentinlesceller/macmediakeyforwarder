//
//  CiderController.swift
//  MacMediaKeyForwarder
//
//  Controls the Cider Apple Music client (https://cider.sh) through its local
//  REST API. Cider is an Electron app and ships no AppleScript scripting
//  dictionary, so it cannot be driven over Scripting Bridge like iTunes/Music
//  and Spotify; instead it exposes an HTTP RPC server on localhost (default
//  port 10767, POST /api/v1/playback/{playpause,next,previous}).
//
//  If "Manage External Application Access to Cider" is enabled in Cider's
//  Connectivity settings, requests must carry the user's app token in the
//  `apptoken` header; without a token Cider only accepts requests when that
//  protection is disabled.
//

import Cocoa

final class CiderController {

    static let apiTokenKey = "user_cider_api_token"

    private let session: URLSession

    init() {
        // Keep timeouts short: the target is loopback, so anything slower than
        // this means Cider is not there and the request should die quietly.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        session = URLSession(configuration: configuration)
    }

    // Cider's bundle identifier has changed across releases (Cider 2 4.x:
    // sh.cider.genten.mac; earlier Cider 2: sh.cider.genten; Cider Classic:
    // sh.cider.electron; the first 1.x builds: a bare "cider"), so match the
    // sh.cider. prefix rather than an exact list. Only used to detect whether
    // Cider is running; the transport commands go over HTTP, which cannot
    // accidentally launch the app the way an Apple Event can.
    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { application in
            guard let identifier = application.bundleIdentifier else { return false }
            return identifier.hasPrefix("sh.cider.") || identifier == "cider"
        }
    }

    var apiToken: String? {
        get {
            let token = UserDefaults.standard.string(forKey: Self.apiTokenKey)
            return (token?.isEmpty ?? true) ? nil : token
        }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: Self.apiTokenKey)
            } else {
                UserDefaults.standard.set(trimmed, forKey: Self.apiTokenKey)
            }
        }
    }

    func playPause() {
        post("playpause")
    }

    func nextTrack() {
        post("next")
    }

    func previousTrack() {
        post("previous")
    }

    // Fire-and-forget: media keys must never block the event tap, and there is
    // no meaningful recovery if Cider is unreachable or rejects the token.
    private func post(_ command: String) {
        guard let url = URL(string: "http://127.0.0.1:10767/api/v1/playback/\(command)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if let token = apiToken {
            request.setValue(token, forHTTPHeaderField: "apptoken")
        }
        session.dataTask(with: request).resume()
    }
}
