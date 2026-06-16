//
//  LaunchAtLogin.swift
//  MacMediaKeyForwarder
//
//  Launch-at-login backed by SMAppService (macOS 13+). This replaces the old
//  GBLaunchAtLogin / LSSharedFileList implementation, which used APIs that have
//  been deprecated since macOS 10.10/10.11.
//

import Foundation
import ServiceManagement

enum LaunchAtLogin {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func enable() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            NSLog("MacMediaKeyForwarder: failed to enable launch at login: \(error)")
        }
    }

    static func disable() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            NSLog("MacMediaKeyForwarder: failed to disable launch at login: \(error)")
        }
    }
}
