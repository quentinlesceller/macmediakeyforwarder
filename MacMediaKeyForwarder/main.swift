//
//  main.swift
//  MacMediaKeyForwarder
//
//  Created by Milan Toth on 2016. 12. 19.
//  Copyright © 2016. Milan Toth. All rights reserved.
//
//  The app delegate is instantiated and wired up by MainMenu.xib (its File's
//  Owner is NSApplication and the `delegate` outlet points at an AppDelegate),
//  so we hand control straight to NSApplicationMain like the original main.m.
//

import Cocoa

exit(NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv))
