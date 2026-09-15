//
//  SpotifastController.swift
//  MacMediaKeyForwarder
//
//  Controls the Spotifast Spotify client (https://spotifast.rocks) through its
//  local remote-control socket. Spotifast is a Rust/egui app and ships no
//  AppleScript scripting dictionary, so it cannot be driven over Scripting
//  Bridge like iTunes/Music and Spotify; instead the running instance listens
//  on an exclusive loopback TCP socket (127.0.0.1:47113) that also serves as
//  its single-instance guard.
//
//  The wire protocol is line based: a client sends "fastpotify:<verb>\n" and
//  the instance replies with one line ("fastpotify:ok" on success) before
//  closing the connection. See single_instance.rs in the Spotifast source for
//  the authoritative list of verbs.
//

import Cocoa
import Network

final class SpotifastController {

    // Spotifast was previously named Fastpotify; the bundle identifier kept
    // the old name.
    private static let bundleIdentifier = "me.paolino.fastpotify"

    // Loopback port the running instance listens on. Registered to nothing;
    // chosen high and out of the ephemeral range by Spotifast itself.
    private static let port: NWEndpoint.Port = 47113

    private static let prefix = "fastpotify:"

    private let queue = DispatchQueue(label: "SpotifastController")

    // Keeps in-flight connections alive until they finish; NWConnection does
    // not retain itself, and media keys must never block waiting on I/O.
    private var connections: [ObjectIdentifier: NWConnection] = [:]

    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == Self.bundleIdentifier }
    }

    func playPause() {
        send("playpause")
    }

    func nextTrack() {
        send("next")
    }

    func previousTrack() {
        send("previous")
    }

    // Fire-and-forget: media keys must never block the event tap, and there is
    // no meaningful recovery if Spotifast is unreachable.
    private func send(_ verb: String) {
        let connection = NWConnection(host: "127.0.0.1", port: Self.port, using: .tcp)
        let id = ObjectIdentifier(connection)
        queue.async { self.connections[id] = connection }

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                let data = "\(Self.prefix)\(verb)\n".data(using: .utf8)!
                connection.send(content: data, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            case .waiting:
                // Nothing is listening (Spotifast is still starting up, or the
                // port is gone). NWConnection would otherwise sit here retrying
                // and replay this stale command once the port appears.
                connection.cancel()
            case .failed, .cancelled:
                self?.queue.async { self?.connections.removeValue(forKey: id) }
            default:
                break
            }
        }
        connection.start(queue: queue)
    }
}
