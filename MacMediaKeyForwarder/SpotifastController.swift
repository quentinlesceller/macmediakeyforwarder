//
//  SpotifastController.swift
//  MacMediaKeyForwarder
//
//  Controls the Spotifast Spotify client (https://spotifast.rocks) through its
//  local remote-control channel. Spotifast is a Rust app and ships no
//  AppleScript scripting dictionary, so it cannot be driven over Scripting
//  Bridge like Music and Spotify; instead the running instance listens on a
//  Unix domain socket that also serves as its single-instance guard. Its own
//  `spotifast` command-line subcommands are clients of the same channel.
//
//  On macOS the socket is `$TMPDIR/spotifast/instance.sock`, private to the
//  user. The wire protocol is line based: a client sends "spotifast:<verb>\n"
//  and the instance replies with one line ("spotifast:ok" on success) before
//  closing the connection. See src/single_instance.rs in the Spotifast source
//  and crates/fastframe-instance in crmne/fastframe for the authoritative
//  details.
//
//  Spotifast 0.12.0 replaced the loopback TCP port (127.0.0.1:47113), the
//  "fastpotify:" prefix and the me.paolino.fastpotify bundle identifier used
//  by earlier versions (#50).
//

import Cocoa

final class SpotifastController {

    private static let bundleIdentifier = "rocks.spotifast.Spotifast"

    private static let prefix = "spotifast:"

    // How long a command may wait on Spotifast before it is dropped.
    private static let timeout = timeval(tv_sec: 1, tv_usec: 0)

    // Serial, so presses reach Spotifast in the order they were made.
    private let queue = DispatchQueue(label: "SpotifastController")

    private var socketPath: String {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("spotifast")
            .appendingPathComponent("instance.sock")
            .path
    }

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

    // Fire-and-forget on a background queue: media keys must never block the
    // event tap, and there is no meaningful recovery if Spotifast is
    // unreachable. A connect fails at once when nothing is listening, so a
    // press made while Spotifast is starting up is dropped, not replayed.
    private func send(_ verb: String) {
        let path = socketPath
        queue.async {
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { return }
            defer { close(fd) }

            var noSigPipe: Int32 = 1
            var timeout = Self.timeout
            let timeoutSize = socklen_t(MemoryLayout<timeval>.size)
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
            setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, timeoutSize)
            setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, timeoutSize)

            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            let pathBytes = Array(path.utf8)
            guard pathBytes.count < MemoryLayout.size(ofValue: address.sun_path) else { return }
            withUnsafeMutableBytes(of: &address.sun_path) { buffer in
                buffer.copyBytes(from: pathBytes)
            }
            let connected = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard connected == 0 else { return }

            let request = Array("\(Self.prefix)\(verb)\n".utf8)
            guard write(fd, request, request.count) == request.count else { return }

            // Wait for the one-line reply so Spotifast has taken the command
            // before the connection closes.
            var reply = [UInt8](repeating: 0, count: 64)
            _ = read(fd, &reply, reply.count)
        }
    }
}
