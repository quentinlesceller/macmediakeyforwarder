//
//  LaunchAtLogin.swift
//  MacMediaKeyForwarder
//
//  Swift port of GBLaunchAtLogin (Luka Mirosevic, Goonbee, 2013).
//
//  This intentionally keeps using the (now deprecated) LSSharedFileList API so
//  that the launch-at-login behavior is identical to the original Objective-C
//  version across the whole supported deployment target (macOS 10.14+, which
//  predates SMAppService). Migrating to SMAppService would be a separate,
//  behavior-changing modernization.
//

import Foundation
import CoreServices

enum LaunchAtLogin {

    private static var appURL: URL {
        URL(fileURLWithPath: Bundle.main.bundlePath)
    }

    private static func sessionLoginItems() -> LSSharedFileList? {
        LSSharedFileListCreate(nil, kLSSharedFileListSessionLoginItems.takeRetainedValue(), nil)?.takeRetainedValue()
    }

    private static func snapshot(of loginItems: LSSharedFileList) -> [LSSharedFileListItem] {
        var seed: UInt32 = 0
        guard let items = LSSharedFileListCopySnapshot(loginItems, &seed)?.takeRetainedValue() as? [LSSharedFileListItem] else {
            return []
        }
        return items
    }

    private static func resolvedURL(for item: LSSharedFileListItem) -> URL? {
        var outURL: Unmanaged<CFURL>?
        guard LSSharedFileListItemResolve(item, 0, &outURL, nil) == noErr else { return nil }
        return outURL?.takeRetainedValue() as URL?
    }

    static var isLoginItem: Bool {
        guard let loginItems = sessionLoginItems() else { return false }
        let path = appURL.path
        for item in snapshot(of: loginItems) where resolvedURL(for: item)?.path == path {
            return true
        }
        return false
    }

    static func addAppAsLoginItem() {
        guard let loginItems = sessionLoginItems() else { return }
        // Add for the current user only (session, not global) — matching the original.
        _ = LSSharedFileListInsertItemURL(loginItems,
                                          kLSSharedFileListItemLast.takeRetainedValue(),
                                          nil,
                                          nil,
                                          appURL as CFURL,
                                          nil,
                                          nil)
    }

    static func removeAppFromLoginItems() {
        guard let loginItems = sessionLoginItems() else { return }
        let path = appURL.path
        for item in snapshot(of: loginItems) where resolvedURL(for: item)?.path == path {
            LSSharedFileListItemRemove(loginItems, item)
        }
    }
}
