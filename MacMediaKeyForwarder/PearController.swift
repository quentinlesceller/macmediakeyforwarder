//
//  PearController.swift
//  MacMediaKeyForwarder
//
//  Controls Pear Desktop (https://github.com/pear-devs/pear-desktop) through
//  its "API Server" plugin. Like Cider, Pear is an Electron app with no
//  AppleScript dictionary, so it cannot be driven over Scripting Bridge;
//  instead the plugin exposes an HTTP server on localhost (default port 26538,
//  POST /api/v1/{toggle-play,next,previous}).
//
//  The plugin must be enabled in Pear under Plugins > API Server. Its default
//  auth strategy ("Auth at first") requires a one-time handshake: POST
//  /auth/{clientId} pops a confirmation dialog in Pear and returns a JWT that
//  every later request carries as a bearer token. The token is cached in
//  UserDefaults; a 401 drops it so the next key press re-runs the handshake.
//

import Cocoa

final class PearController {

    private static let accessTokenKey = "user_pear_access_token"
    private static let clientId = "MacMediaKeyForwarder"
    private static let baseURL = "http://127.0.0.1:26538"

    private let session: URLSession
    private let authSession: URLSession

    // Set while the handshake runs so repeated key presses don't stack up
    // approval dialogs in Pear. Only touched on the main queue: key presses
    // arrive there and authSession delivers its completion there.
    private var isAuthenticating = false

    init() {
        // Keep timeouts short: the target is loopback, so anything slower than
        // this means Pear is not there and the request should die quietly.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        session = URLSession(configuration: configuration)

        // The handshake stays open while Pear shows its approval dialog, so it
        // needs its own session: timeoutIntervalForResource caps every task on
        // a session regardless of the per-request timeout.
        let authConfiguration = URLSessionConfiguration.ephemeral
        authConfiguration.timeoutIntervalForRequest = 60
        authConfiguration.timeoutIntervalForResource = 60
        authSession = URLSession(configuration: authConfiguration, delegate: nil, delegateQueue: .main)
    }

    // Pear ships under the bundle identifier it inherited from its upstream
    // project. Only used to detect whether Pear is running; the transport
    // commands go over HTTP, which cannot accidentally launch the app the way
    // an Apple Event can.
    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.github.th-ch.youtube-music" }
    }

    func playPause() {
        post("toggle-play")
    }

    func nextTrack() {
        post("next")
    }

    func previousTrack() {
        post("previous")
    }

    // Fire-and-forget: media keys must never block the event tap, and there is
    // no meaningful recovery if Pear is unreachable.
    private func post(_ command: String) {
        guard let token = accessToken else {
            // Presses made while the dialog is up are dropped; the one that
            // started the handshake is sent once it succeeds.
            guard !isAuthenticating else { return }
            isAuthenticating = true
            requestAccessToken { [weak self] token in
                self?.isAuthenticating = false
                guard token != nil else { return }
                self?.post(command)
            }
            return
        }
        guard let url = URL(string: "\(Self.baseURL)/api/v1/\(command)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        session.dataTask(with: request) { [weak self] _, response, _ in
            // The token is rejected once the user revokes the client or Pear
            // rotates its secret (it regenerates on every launch of a fresh
            // config). Forget it so the next key press asks again.
            if (response as? HTTPURLResponse)?.statusCode == 401 {
                self?.accessToken = nil
            }
        }.resume()
    }

    private func requestAccessToken(completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "\(Self.baseURL)/auth/\(Self.clientId)") else {
            completion(nil)
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        authSession.dataTask(with: request) { [weak self] data, _, _ in
            guard let data = data,
                  let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = payload["accessToken"] as? String else {
                completion(nil)
                return
            }
            self?.accessToken = token
            completion(token)
        }.resume()
    }

    private var accessToken: String? {
        get {
            let token = UserDefaults.standard.string(forKey: Self.accessTokenKey)
            return (token?.isEmpty ?? true) ? nil : token
        }
        set {
            if let newValue = newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: Self.accessTokenKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.accessTokenKey)
            }
        }
    }
}
