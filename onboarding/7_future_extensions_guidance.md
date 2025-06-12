# 7. Guidance for Future Extensions

This document provides some initial thoughts and suggestions for tackling the two future extensions mentioned:

1.  **Adding support for two new applications via "keyboard simulation."**
2.  **Implementing a new player control approach.**

This is not a definitive guide, but rather a starting point for your own design and implementation.

## 1. Adding New App Support via Keyboard Simulation

The goal here is to control two new (unspecified) applications by sending them keyboard shortcuts, rather than using direct integration like AppleScript (which might be how Spotify/iTunes are currently handled).

### Key Steps and Considerations:

**a. Identify Target Applications and Their Shortcuts:**

*   First, you'll need to know which two applications to support.
*   For each application, determine the exact keyboard shortcuts for:
    *   Play/Pause
    *   Next Track
    *   Previous Track
*   Verify these shortcuts manually in the applications themselves. Note if they are global shortcuts or only work when the app is active.

**b. Representing Supported Applications:**

*   You'll need a way to manage the list of supported applications within MacMediaKeyForwarder. This might involve:
    *   Creating a new class (e.g., `SimulatedPlayer` or `KeyboardControlledApp`) that stores the application's name, bundle identifier, and the key codes/modifier flags for its media shortcuts.
    *   An array or dictionary in `AppDelegate` (or a dedicated manager class) to hold instances of these `SimulatedPlayer` objects.

**c. User Interface for Selecting Active App (If Necessary):**

*   How will MacMediaKeyForwarder know which of the newly supported apps to control?
    *   If the app already has a mechanism to switch between Spotify and iTunes (e.g., via the status menu), you'll need to extend this UI to include the new apps.
    *   Consider an "auto-detect" mode if feasible (e.g., target the frontmost of the supported apps), or a manual selection.

**d. Implementing Keyboard Simulation:**

*   **CoreGraphics Events (`CGEvent`):** This is the most common low-level API for this.
    *   **`CGEventCreateKeyboardEvent(NULL, keyCode, true)`**: Creates a key down event.
    *   **`CGEventCreateKeyboardEvent(NULL, keyCode, false)`**: Creates a key up event.
    *   You'll need to send both a key down and a key up event to simulate a full press.
    *   **Modifier Keys**: If shortcuts involve Command, Option, Shift, Control, you'll need to set flags on the `CGEventRef` using `CGEventSetFlags`.
    *   **Posting Events**: `CGEventPostToPid(pid, event)` allows you to post an event directly to a specific application process ID (PID).
        *   You'll need to get the PID of the target application (e.g., using `NSRunningApplication` methods to find an app by its bundle ID and get its `processIdentifier`).
    *   Alternatively, `CGEventPost(kCGHIDEventTap, event)` posts to the system event stream, which then routes it to the active application. This might be simpler if the target app is guaranteed to be active, but `CGEventPostToPid` is more robust for background apps.
*   **Permissions**: Remember, posting events generally requires Accessibility permissions for your app.
*   **Sandboxing**: If the app is sandboxed, posting keyboard events to *other* applications can be restricted. This is a critical point to investigate. You might need specific entitlements, or it might only work for non-sandboxed apps.

**e. Code Structure:**

*   Consider creating a new protocol, say `MediaControllable`, with methods like `playPause`, `nextTrack`, `previousTrack`.
*   Your existing Spotify/iTunes handlers and your new `SimulatedPlayer` class could all conform to this protocol.
*   This would allow `AppDelegate` to hold a reference to the currently active `MediaControllable` object and simply call its methods, regardless of how that object implements the control (AppleScript, keyboard simulation, etc.).

### Example Snippet (Conceptual for `CGEventPost`):

```objectivec
// --- Conceptual: Do not copy-paste without adaptation ---
#import <ApplicationServices/ApplicationServices.h> // For CoreGraphics events

// Function to post a key event (down or up) to a specific PID
void postKeyboardEvent(pid_t pid, CGKeyCode keyCode, bool keyDown, CGEventFlags flags) {
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, keyCode, keyDown);
    if (!event) return;

    if (flags != 0) { // Only set flags if there are any
        CGEventSetFlags(event, flags);
    }

    CGEventPostToPid(pid, event);
    CFRelease(event);
}

// Example usage (replace with actual key codes, pid, and flags)
// To simulate Command-P (e.g., if 'P' was Play)
// CGKeyCode kVK_ANSI_P = 0x23; // Example, find correct key codes
// pid_t targetAppPID = ...; // Get this from NSRunningApplication

// postKeyboardEvent(targetAppPID, kVK_COMMAND, true, kCGEventFlagMaskCommand); // Command down
// postKeyboardEvent(targetAppPID, kVK_ANSI_P, true, kCGEventFlagMaskCommand);  // P down
// postKeyboardEvent(targetAppPID, kVK_ANSI_P, false, kCGEventFlagMaskCommand); // P up
// postKeyboardEvent(targetAppPID, kVK_COMMAND, false, kCGEventFlagMaskCommand); // Command up
// --- End Conceptual ---
```
**Note**: You need to find the correct `CGKeyCode` values for the keys. These are different from ASCII values. Headers like `<HIToolbox/Events.h>` contain constants (e.g., `kVK_Space`, `kVK_RightArrow`).

## 2. New Player Control Approach

This is more open-ended. "A new player control approach" could mean many things:

*   **More Abstract Control**: The `MediaControllable` protocol idea above is a step in this direction. It decouples the core app logic from the specific way each player is controlled.
*   **Plugin System**: For supporting many players, a more advanced approach would be a plugin system where new players can be added without recompiling the main app. This is likely overkill for just two new apps but good to keep in mind for future scalability.
*   **Enhanced UI for Player Selection**: Perhaps a more sophisticated UI for choosing which app to control, or rules for automatic selection.
*   **Global Hotkeys for Switching Players**: Allow the user to set hotkeys to directly target a specific player before sending media key commands.
*   **Discovering Running Media Apps**: Dynamically discovering which controllable media apps are currently running.

### Initial Steps:

1.  **Clarify Requirements**: The first step is to better define what "new player control approach" means. What are the goals?
    *   Easier to add new players?
    *   More flexible for the user?
    *   Better performance?
2.  **Refactor Existing Controls**: If `Spotify.h` and `iTunes.h` have very different ways of being called, consider refactoring them to a common interface (like the `MediaControllable` protocol). This makes it easier to swap them out or add new ones.
3.  **Centralize Control Logic**: Ensure that the `AppDelegate` (or a dedicated controller) is responsible for deciding *which* player to command, and then delegates the *how* to the specific player object.

By focusing on abstraction (like the protocol idea) for both new and existing app integrations, you'll naturally create a more flexible "player control approach."

## General Advice

*   **Start Small**: For adding the new apps, get one app working with keyboard simulation first.
*   **Test Thoroughly**: Keyboard simulation can be finicky. Test with the target apps active, in the background, etc.
*   **Read Apple's Documentation**: Especially for `CGEvent` functions and `NSRunningApplication`.
*   **Check Console Logs**: For errors from `CGEventPost` or permission issues.

This guidance should give you a solid foundation for planning and implementing these extensions. Good luck!

You've reached the end of the initial onboarding documentation! Head back to the [README](./README.md) if you need to review any sections.
