//
//  KeyboardSimulationStrategy.m
//  MacMediaKeyForwarder
//
//  Created by [Your Name] on [Date].
//  Copyright © 2023 [Your Name]. All rights reserved.
//
//  Implementation of the KeyboardSimulationStrategy class.
//  This strategy simulates media key presses to control applications.
//  WARNING: This implementation is currently a conceptual placeholder.
//  Properly simulating key events, especially targeting specific applications
//  not in the foreground, is complex and requires careful handling of process IDs,
//  event taps, and potentially accessibility permissions.
//

#import "KeyboardSimulationStrategy.h"
#import <ApplicationServices/ApplicationServices.h> // For CoreGraphics event services (CGEventPost, etc.)
#import <Cocoa/Cocoa.h> // For NSRunningApplication
#import <HIToolbox/Events.h> // For key codes like NX_KEYTYPE_PLAY

@implementation KeyboardSimulationStrategy

// For a pure keyboard simulation strategy, an SBApplication instance is not directly used.
// Commands are sent as system-wide key events or targeted to a process.
// Thus, this method returns nil.
- (nullable SBApplication *)applicationInstanceWithBundleIdentifier:(NSString *)bundleIdentifier {
    // Not applicable for this strategy as it doesn't rely on ScriptingBridge objects.
    NSLog(@"KeyboardSimulationStrategy: SBApplication instance requested for %@, but this strategy does not use them. Returning nil.", bundleIdentifier);
    return nil;
}

// Simulates a Play/Pause media key press.
// The `applicationInstance` parameter is marked __unused as it's not directly used
// in this strategy's current conceptual form. A more advanced implementation might use
// the bundle ID from the PlayerController that holds this strategy to find the target process.
- (void)sendPlayPauseCommandToApp:(nullable __unused SBApplication *)applicationInstance {
    NSLog(@"KeyboardSimulationStrategy: Simulating Play/Pause Key Event (Conceptual).");
    // [self simulateMediaKey:NX_KEYTYPE_PLAY forBundleIdentifier:targetBundleIdentifier];
    // `targetBundleIdentifier` would be a property of this strategy instance, or passed in.
    // For a simple global simulation (like pressing the actual keyboard key):
    [self postSystemWideMediaKey:NX_KEYTYPE_PLAY];
}

// Simulates a Next Track media key press.
- (void)sendNextTrackCommandToApp:(nullable __unused SBApplication *)applicationInstance {
    NSLog(@"KeyboardSimulationStrategy: Simulating Next Track Key Event (Conceptual).");
    // [self simulateMediaKey:NX_KEYTYPE_NEXT forBundleIdentifier:targetBundleIdentifier];
    [self postSystemWideMediaKey:NX_KEYTYPE_NEXT];
}

// Simulates a Previous Track media key press.
- (void)sendPreviousTrackCommandToApp:(nullable __unused SBApplication *)applicationInstance {
    NSLog(@"KeyboardSimulationStrategy: Simulating Previous Track Key Event (Conceptual).");
    // [self simulateMediaKey:NX_KEYTYPE_PREVIOUS forBundleIdentifier:targetBundleIdentifier];
    [self postSystemWideMediaKey:NX_KEYTYPE_PREVIOUS];
}


// Helper function to post a system-wide media key event.
// This is like pressing the actual key on the keyboard and affects the active/appropriate application.
// This requires the application to have Accessibility permissions.
- (void)postSystemWideMediaKey:(int)keyCode {
    // Create a new keyboard event source.
    CGEventSourceRef source = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    if (!source) {
        NSLog(@"KeyboardSimulationStrategy: Failed to create event source.");
        return;
    }

    // Simulate key down event.
    CGEventRef keyDownEvent = CGEventCreateKeyboardEvent(source, (CGKeyCode)keyCode, true);
    if (!keyDownEvent) {
        NSLog(@"KeyboardSimulationStrategy: Failed to create key down event for key code %d.", keyCode);
        CFRelease(source);
        return;
    }
    // Simulate key up event.
    CGEventRef keyUpEvent = CGEventCreateKeyboardEvent(source, (CGKeyCode)keyCode, false);
    if (!keyUpEvent) {
        NSLog(@"KeyboardSimulationStrategy: Failed to create key up event for key code %d.", keyCode);
        CFRelease(keyDownEvent);
        CFRelease(source);
        return;
    }

    // Post the events to the system event stream.
    // kCGHIDEventTap is a common tap point for system-wide hardware-like events.
    CGEventPost(kCGHIDEventTap, keyDownEvent);
    CGEventPost(kCGHIDEventTap, keyUpEvent);

    // Release the events and source.
    CFRelease(keyUpEvent);
    CFRelease(keyDownEvent);
    CFRelease(source);

    NSLog(@"KeyboardSimulationStrategy: Posted system-wide media key: %d", keyCode);
}


// --- Advanced: Targeting a specific application by PID ---
// The following is a more detailed conceptual helper for sending key events to a specific application.
// This is more complex and may have limitations (e.g., app must be ready to handle keys,
// might not work for backgrounded apps without specific support or focus stealing).

/*
- (void)simulateMediaKey:(int)keyCode forBundleIdentifier:(NSString *)bundleIdentifier {
    if (!bundleIdentifier) {
        NSLog(@"KeyboardSimulationStrategy: No bundle identifier provided for media key simulation.");
        // Fallback to system-wide key press or do nothing.
        [self postSystemWideMediaKey:keyCode];
        return;
    }

    // 1. Get the Process ID (PID) of the target application.
    NSArray<NSRunningApplication *> *runningApps = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier];
    NSRunningApplication *targetApp = runningApps.firstObject;

    if (!targetApp) {
        NSLog(@"KeyboardSimulationStrategy: Application with bundle ID %@ is not running.", bundleIdentifier);
        return; // Or potentially try to launch it, though that's beyond simple key simulation.
    }
    pid_t targetPID = targetApp.processIdentifier;

    // 2. Create key events
    // Using NULL for the event source uses the default source.
    CGEventRef keyDownEvent = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)keyCode, true); // true for key down
    CGEventRef keyUpEvent = CGEventCreateKeyboardEvent(NULL, (CGKeyCode)keyCode, false); // false for key up

    if (!keyDownEvent || !keyUpEvent) {
        NSLog(@"KeyboardSimulationStrategy: Failed to create keyboard events for PID %d.", targetPID);
        if (keyDownEvent) CFRelease(keyDownEvent);
        if (keyUpEvent) CFRelease(keyUpEvent);
        return;
    }

    // 3. Post the events directly to the application's event queue.
    // This is often more reliable than system-wide posts for targeting specific apps,
    // but the app must be able to process these events.
    // CGEventPostToPid(targetPID, keyDownEvent);
    // CGEventPostToPid(targetPID, keyUpEvent);
    // For media keys which are system-defined events, posting to kCGSessionEventTap might be more appropriate
    // even when "targeting" an app by ensuring it's frontmost or by other means.
    // The use of CGEventPostToPid for system media keys (like NX_KEYTYPE_PLAY) can be unreliable
    // as these are often handled at a higher level or by specific system daemons.
    // A more common approach for media keys is to ensure the target app is frontmost, then post system-wide.
    // Or, use Accessibility API to target UI elements if direct key event posting is not working.

    // For this example, we'll stick to the system-wide post as it's simpler for media keys,
    // assuming the OS/target app routes it correctly.
    // If this strategy were to be fully developed, extensive testing of CGEventPostToPid vs.
    // bringing app to front + CGEventPost(kCGHIDEventTap, ...) would be needed.
    CGEventPost(kCGHIDEventTap, keyDownEvent);
    CGEventPost(kCGHIDEventTap, keyUpEvent);


    // 4. Release the events
    CFRelease(keyDownEvent);
    CFRelease(keyUpEvent);

    NSLog(@"KeyboardSimulationStrategy: Simulated media key %d for app %@ (PID: %d)", keyCode, bundleIdentifier, targetPID);
}
*/


// Checks if an application with the given bundle identifier is running.
// This uses NSRunningApplication for a reliable check.
- (BOOL)isAppRunning:(NSString *)bundleIdentifier {
    if (!bundleIdentifier || [bundleIdentifier isEqualToString:@""]) {
        NSLog(@"KeyboardSimulationStrategy: Cannot check if app is running, bundleIdentifier is nil or empty.");
        return NO;
    }
    // `runningApplicationsWithBundleIdentifier:` returns an array of running applications
    // that match the given bundle identifier. If the array is not empty, the app is running.
    NSArray<NSRunningApplication *> *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdentifier];
    BOOL isRunning = apps.count > 0;
    // NSLog(@"KeyboardSimulationStrategy: Application %@ isRunning: %@", bundleIdentifier, isRunning ? @"YES" : @"NO");
    return isRunning;
}

// Determining playback state purely via keyboard simulation is generally not possible.
// Media keys are commands; they don't typically return state.
// This method would require other means (like UI scripting, reading files, etc.),
// which are beyond simple keyboard simulation.
// Returning NO as a safe default.
- (BOOL)isAppPlaying:(nullable __unused SBApplication *)applicationInstance {
    NSLog(@"KeyboardSimulationStrategy: Checking playback state is not reliably possible with this strategy. Returning NO.");
    // To make this meaningful, one might:
    // 1. Assume state based on last command (e.g., if play was sent, assume playing). (Highly unreliable)
    // 2. Use Accessibility API to inspect UI elements (e.g., a play/pause button state). (Complex, app-specific)
    // 3. For some apps, there might be status files or logs, but this is rare and not generic.
    return NO; // Placeholder: Cannot determine playback state with this strategy alone.
}

@end
