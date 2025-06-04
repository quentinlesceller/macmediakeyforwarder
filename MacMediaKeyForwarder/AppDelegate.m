#import "AppDelegate.h"
#import "GBLaunchAtLogin.h"
#import "iTunes.h" // Keep for casting iTunesApplication for fastForward/rewind, and for iTunes.h sdef specifics
#import "Spotify.h" // Keep for casting SpotifyApplication if needed for specific properties beyond PlayerController
#import <CoreServices/CoreServices.h>
#import <ScriptingBridge/ScriptingBridge.h>

// New imports for PlayerController architecture
#import "PlayerController.h"          // Protocol for player operations
#import "SpotifyController.h"       // Concrete controller for Spotify
#import "iTunesController.h"        // Concrete controller for iTunes/Music
#import "ScriptingBridgeStrategy.h" // Concrete strategy for ScriptingBridge control

// Enum for selecting which player to prioritize for media key events.
typedef NS_ENUM(NSInteger, MediaKeysPrioritize)
{
    MediaKeysPrioritizeNone,    // Send to all running players that respond.
    MediaKeysPrioritizeITunes,  // Prioritize iTunes (or Music.app on newer macOS).
    MediaKeysPrioritizeSpotify  // Prioritize Spotify.
};

// Enum for managing when media key forwarding is paused.
typedef NS_ENUM(NSInteger, PauseState)
{
    PauseStateNone,      // Forwarding is active.
    PauseStatePause,     // Forwarding is manually paused by the user.
    PauseStateAutomatic, // Forwarding is paused if no recognized players are running.
};

// Enum for tracking the state of held media keys, primarily for iTunes fast-forward/rewind.
typedef NS_ENUM(NSInteger, KeyHoldState)
{
    KeyHoldStateNone,    // No relevant key is being held.
    KeyHoldStateWaiting, // A relevant key (next/prev) has been pressed once, waiting for a second press to confirm hold or a release for single action.
    KeyHoldStateHolding  // A relevant key is being held down (for FF/REW).
};

// Keys for storing user preferences in NSUserDefaults.
static NSString *kUserDefaultsPriorityOptionKey = @"user_priority_option";
static NSString *kUserDefaultsPauseOptionKey = @"user_pause_option";
static NSString *kUserDefaultsHideFromMenuBarOptionKey = @"user_hide_from_menu_bar_option";

// Global state variables. These are accessed by the C callback `tapEventCallback`.
PauseState pauseState;
KeyHoldState keyHoldStatus;
MediaKeysPrioritize mediaKeysPriority;

@interface AppDelegate ()
{
    NSStatusItem* statusItem;        // The application's item in the system status bar.
    CFMachPortRef eventPort;         // Mach port for the event tap.
    CFRunLoopSourceRef eventPortSource; // Run loop source for the event tap.

    // Menu item collections for dynamic updates (e.g., checkmarks).
    NSMutableArray *priorityOptionItems;
    NSMutableArray *pauseOptionItems;
    NSMenuItem *startupItem;
    NSMenuItem *hideFromMenuBarItem;

    // --- New instance variables for PlayerController architecture ---
    // Array to hold all initialized player controllers (e.g., SpotifyController, iTunesController).
    NSMutableArray<id<PlayerController>> *playerControllers;
    // The single strategy instance used by all controllers. Currently, only ScriptingBridge is implemented.
    // Future extension could allow different strategies per controller or global strategy selection.
    id<PlaybackControlStrategy> scriptingBridgeStrategy;
}

// Declaration of private helper methods.
- (nullable id<PlayerController>)controllerForPlayerName:(NSString *)playerName;
- (nullable id<PlayerController>)prioritizedPlayerControllerIfRunning;
- (void)showEventTapErrorAlert; // Displays an alert if the event tap cannot be created.

@end

@implementation AppDelegate

// Retrieves a player controller instance from the `playerControllers` array by its `playerName`.
// `playerName` is a property defined in the `PlayerController` protocol (e.g., "Spotify", "iTunes").
// @param playerName The `playerName` of the desired controller.
// @return The `PlayerController` instance if found, otherwise nil.
- (nullable id<PlayerController>)controllerForPlayerName:(NSString *)playerName {
    if (!playerName) return nil;
    for (id<PlayerController> controller in playerControllers) {
        // The `playerName` property on iTunesController is "iTunes", even for Music.app,
        // to maintain consistency with the MediaKeysPrioritizeITunes enum value and related logic.
        if ([controller.playerName isEqualToString:playerName]) {
            return controller;
        }
    }
    return nil;
}

// Determines which player controller should receive commands based on the current `mediaKeysPriority` setting.
// If a priority is set (iTunes or Spotify), it returns that player's controller, but ONLY if that player is currently running.
// If priority is None, or if the prioritized player is not running, this method returns nil.
// @return The `PlayerController` instance for the prioritized and running player, or nil.
- (nullable id<PlayerController>)prioritizedPlayerControllerIfRunning {
    NSString *targetPlayerName = nil;
    if (mediaKeysPriority == MediaKeysPrioritizeITunes) {
        targetPlayerName = @"iTunes"; // Corresponds to iTunesController.playerName
    } else if (mediaKeysPriority == MediaKeysPrioritizeSpotify) {
        targetPlayerName = @"Spotify"; // Corresponds to SpotifyController.playerName
    }

    if (targetPlayerName) {
        id<PlayerController> controller = [self controllerForPlayerName:targetPlayerName];
        // Only return the controller if it exists and its underlying application is running.
        if (controller && [controller isRunning]) {
            return controller;
        }
    }
    return nil; // No priority, or prioritized app is not running.
}

// C callback function for the event tap. This function is called by the system for each relevant event.
// It processes media key events and dispatches actions to the appropriate player controllers.
static CGEventRef tapEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon)
{
    @autoreleasepool // Ensure objects created during this callback are autoreleased.
    {
        AppDelegate *self = (__bridge id)refcon; // Bridge `refcon` back to the AppDelegate instance.
        
        // Handle event tap timeout: re-enable the tap.
        if(type == kCGEventTapDisabledByTimeout)
        {
            if (self->eventPort) CGEventTapEnable(self->eventPort, TRUE);
            return event;
        }
        
        // Handle event tap disabled by user input (e.g., holding Esc): do nothing.
        if(type == kCGEventTapDisabledByUserInput)
        {
            return event; // The tap is automatically re-enabled by the system.
        }
        
        // We are only interested in system-defined events (media keys fall under this).
        if(type != NX_SYSDEFINED)
        {
            return event;
        }
        
        NSEvent *nsEvent = nil;
        @try
        {
            nsEvent = [NSEvent eventWithCGEvent:event]; // Convert CGEvent to NSEvent for easier inspection.
        }
        @catch (NSException * e)
        {
             NSLog(@"Exception converting CGEvent to NSEvent: %@", e);
            return event; // Don't process if conversion fails.
        }
        
        // Media keys have a subtype of 8.
        if([nsEvent subtype] != 8)
        {
            return event;
        }
        
        // Extract the actual key code from the event data.
        int keyCode = (([nsEvent data1] & 0xFFFF0000) >> 16);
        
        // Filter for specific media key codes we care about.
        if (keyCode != NX_KEYTYPE_PLAY &&
            keyCode != NX_KEYTYPE_FAST &&      // Next track / Fast-forward
            keyCode != NX_KEYTYPE_REWIND &&    // Previous track / Rewind
            keyCode != NX_KEYTYPE_PREVIOUS &&  // Explicit previous track
            keyCode != NX_KEYTYPE_NEXT)        // Explicit next track
        {
            return event;
        }
        
        // If forwarding is manually paused, ignore the event.
        if (self->pauseState == PauseStatePause)
        {
            return event; // Suppress original event by returning event, not NULL
        }
        
        // If forwarding is set to automatic pause, check if any player is running.
        // If no players are running, ignore the event.
        if (self->pauseState == PauseStateAutomatic)
        {
            BOOL anyPlayerRunning = NO;
            for (id<PlayerController> controller in self->playerControllers) {
                if ([controller isRunning]) {
                    anyPlayerRunning = YES;
                    break;
                }
            }
            if (!anyPlayerRunning) {
                return event; // Suppress event
            }
        }

        // Determine if the key was pressed down or released up.
        int keyFlags = ([nsEvent data1] & 0x0000FFFF);
        BOOL keyIsPressed = (((keyFlags & 0xFF00) >> 8)) == 0xA; // 0xA for key down, 0xB for key up.

        // Get the prioritized player controller, if one is set and running.
        id<PlayerController> prioritizedCtrl = [self prioritizedPlayerControllerIfRunning];

        if (keyIsPressed) {
            // --- Key Press Logic ---
            if (prioritizedCtrl) {
                // A specific player is prioritized and running. Send command only to it.
                if ([prioritizedCtrl.playerName isEqualToString:@"iTunes"]) {
                    // iTunes/Music has special handling for FF/REW on key hold.
                    iTunesController *iTunesCtrl = (iTunesController *)prioritizedCtrl;
                    iTunesApplication *iTunesAppInstance = iTunesCtrl.iTunesApp; // Get direct ScriptingBridge object for FF/REW

                    switch (keyCode) {
                        case NX_KEYTYPE_PLAY:
                            [iTunesCtrl playPause];
                            break;
                        case NX_KEYTYPE_FAST: // Typically Next Track key
                        case NX_KEYTYPE_NEXT: // Explicit Next key
                            if (keyHoldStatus == KeyHoldStateNone) keyHoldStatus = KeyHoldStateWaiting; // First press, wait for release or second press
                            else if (keyHoldStatus == KeyHoldStateWaiting) { // Second press while waiting means hold
                                keyHoldStatus = KeyHoldStateHolding;
                                if (iTunesAppInstance && [iTunesAppInstance respondsToSelector:@selector(fastForward)]) {
                                    [iTunesAppInstance fastForward]; // ScriptingBridge direct command
                                }
                            }
                            break;
                        case NX_KEYTYPE_REWIND: // Typically Previous Track key
                        case NX_KEYTYPE_PREVIOUS: // Explicit Previous key
                            if (keyHoldStatus == KeyHoldStateNone) keyHoldStatus = KeyHoldStateWaiting;
                            else if (keyHoldStatus == KeyHoldStateWaiting) {
                                keyHoldStatus = KeyHoldStateHolding;
                                if (iTunesAppInstance && [iTunesAppInstance respondsToSelector:@selector(rewind)]) {
                                    [iTunesAppInstance rewind]; // ScriptingBridge direct command
                                }
                            }
                            break;
                    }
                } else {
                    // For other prioritized players (e.g., Spotify), no special FF/REW logic.
                    switch (keyCode) {
                        case NX_KEYTYPE_PLAY:
                            [prioritizedCtrl playPause];
                            break;
                        case NX_KEYTYPE_FAST:
                        case NX_KEYTYPE_NEXT:
                            [prioritizedCtrl nextTrack];
                            break;
                        case NX_KEYTYPE_REWIND:
                        case NX_KEYTYPE_PREVIOUS:
                            [prioritizedCtrl previousTrack];
                            break;
                    }
                }
            } else {
                // No specific player prioritized (or it's not running). Send to all running players.
                for (id<PlayerController> controller in self->playerControllers) {
                    if ([controller isRunning]) {
                        // iTunes/Music needs to be handled carefully here if FF/REW logic is desired universally (currently not).
                        // For simplicity, if not prioritized, iTunes won't do FF/REW on hold here.
                        switch (keyCode) {
                            case NX_KEYTYPE_PLAY:
                                [controller playPause];
                                break;
                            case NX_KEYTYPE_FAST:
                            case NX_KEYTYPE_NEXT:
                                [controller nextTrack];
                                break;
                            case NX_KEYTYPE_REWIND:
                            case NX_KEYTYPE_PREVIOUS:
                                [controller previousTrack];
                                break;
                        }
                    }
                }
            }
        } else {
            // --- Key Release Logic (Primarily for iTunes FF/REW) ---
            if (mediaKeysPriority == MediaKeysPrioritizeITunes) {
                // Only handle release if iTunes/Music is the prioritized player.
                iTunesController *iTunesCtrl = (iTunesController *)[self controllerForPlayerName:@"iTunes"];
                if (iTunesCtrl && [iTunesCtrl isRunning]) {
                    iTunesApplication *iTunesAppInstance = iTunesCtrl.iTunesApp;
                    if (iTunesAppInstance) {
                        if (keyHoldStatus == KeyHoldStateWaiting) {
                            // Key was released after a single press (not held for FF/REW).
                            // This means a standard next/previous track action.
                            switch (keyCode) {
                                case NX_KEYTYPE_FAST:
                                case NX_KEYTYPE_NEXT:
                                    // The controller's nextTrack method uses the strategy, which handles iTunes's specific selector.
                                    [iTunesCtrl nextTrack];
                                    break;
                                case NX_KEYTYPE_REWIND:
                                case NX_KEYTYPE_PREVIOUS:
                                    [iTunesCtrl previousTrack];
                                    break;
                            }
                        } else if (keyHoldStatus == KeyHoldStateHolding) {
                            // Key was released after being held (FF/REW was active). Resume normal playback.
                            if ([iTunesAppInstance respondsToSelector:@selector(resume)]) {
                                [iTunesAppInstance resume]; // ScriptingBridge direct command
                            }
                        }
                    }
                }
            }
            keyHoldStatus = KeyHoldStateNone; // Reset hold state on any key release.
        }
        
        return NULL; // Consume the event so it's not passed to other applications.
    }
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    // This method is called when the application becomes active.
    // Could be used in the future, e.g., to refresh UI or state if the app is activated.
}

// Called when the application has finished launching.
// This is where initialization of controllers, UI, and event tap occurs.
- ( void ) applicationDidFinishLaunching : ( NSNotification*) theNotification
{
    // Initialize arrays for menu item references.
    priorityOptionItems = [[NSMutableArray alloc] init];
    pauseOptionItems = [[NSMutableArray alloc] init];
    
    // --- Initialize PlayerController Architecture ---
    // Create the playback strategy instance. Currently, only ScriptingBridge is used.
    // If other strategies (e.g., KeyboardSimulationStrategy) were to be selectable,
    // this initialization would be more dynamic.
    scriptingBridgeStrategy = [[ScriptingBridgeStrategy alloc] init];
    
    // Initialize the list of player controllers.
    playerControllers = [[NSMutableArray alloc] init];
    
    // Create and add SpotifyController.
    SpotifyController *spotifyCtrl = [[SpotifyController alloc] initWithStrategy:scriptingBridgeStrategy];
    if (spotifyCtrl) [playerControllers addObject:spotifyCtrl];
    
    // Create and add iTunesController (handles both iTunes and Music.app).
    iTunesController *itunesCtrl = [[iTunesController alloc] initWithStrategy:scriptingBridgeStrategy];
    if (itunesCtrl) [playerControllers addObject:itunesCtrl];
    // --- End PlayerController Architecture Initialization ---

    // Load saved user preferences or set defaults.
    pauseState = PauseStateNone;
    NSNumber *savedPauseState = [[NSUserDefaults standardUserDefaults] objectForKey:kUserDefaultsPauseOptionKey];
    if (savedPauseState) pauseState = [savedPauseState integerValue];

    keyHoldStatus = KeyHoldStateNone; // Always start with no key held.
    
    mediaKeysPriority = MediaKeysPrioritizeNone;
    NSNumber *savedPriority = [[NSUserDefaults standardUserDefaults] objectForKey:kUserDefaultsPriorityOptionKey];
    if (savedPriority) mediaKeysPriority = [savedPriority integerValue];
    
    // Setup version string for the menu.
    NSDictionary *bundleInfo = [[NSBundle mainBundle] infoDictionary];
    NSString *versionString = [NSString stringWithFormat:@"Version %@ (build %@)",
                               bundleInfo[@"CFBundleShortVersionString"],
                               bundleInfo[@"CFBundleVersion"] ];
    
    // --- Setup Menu Bar Item and Menu ---
    NSMenu *menu = [[NSMenu alloc] init];
    [menu setDelegate:self]; // Allows `menuWillOpen` to be called.
    [menu addItemWithTitle:versionString action:nil keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Pause options
    NSMenuItem* manualPauseMenuItem = [menu addItemWithTitle:NSLocalizedString(@"Pause Forwarding", @"Pause Forwarding menu item") action:@selector(manualPause) keyEquivalent:@""];
    NSMenuItem* autoPauseMenuItem = [menu addItemWithTitle:NSLocalizedString(@"Pause If No Player Running", @"Pause If No Player Running menu item") action:@selector(autoPause) keyEquivalent:@""];
    [pauseOptionItems addObject:manualPauseMenuItem];
    [pauseOptionItems addObject:autoPauseMenuItem];
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Prioritization options
    NSMenuItem* prioNoneItem = [menu addItemWithTitle:NSLocalizedString(@"Send to All Running Players", @"Send to All Running Players menu item") action:@selector(prioritizeNone) keyEquivalent:@""];
    // Dynamically set iTunes/Music menu item title based on what iTunesController is targeting.
    NSString *itunesMenuTitleText = ([itunesCtrl.bundleIdentifier isEqualToString:@"com.apple.music"]) ? NSLocalizedString(@"Prioritize Music", @"Prioritize Music menu item") : NSLocalizedString(@"Prioritize iTunes", @"Prioritize iTunes menu item");
    NSMenuItem* prioItunesItem = [menu addItemWithTitle:itunesMenuTitleText action:@selector(prioritizeITunes) keyEquivalent:@""];
    NSMenuItem* prioSpotifyItem = [menu addItemWithTitle:NSLocalizedString(@"Prioritize Spotify", @"Prioritize Spotify menu item") action:@selector(prioritizeSpotify) keyEquivalent:@""];
    [priorityOptionItems addObject:prioNoneItem];
    [priorityOptionItems addObject:prioItunesItem];
    [priorityOptionItems addObject:prioSpotifyItem];
    [menu addItem:[NSMenuItem separatorItem]];
    
    // Other options
    startupItem = [menu addItemWithTitle:NSLocalizedString(@"Open at Login", @"Open at Login menu item") action:@selector(toggleStartupItem) keyEquivalent:@""];
    hideFromMenuBarItem = [menu addItemWithTitle:NSLocalizedString(@"Hide Menu Bar Icon", @"Hide Menu Bar Icon menu item") action:@selector(hideFromMenuBar) keyEquivalent:@"l"];
    [hideFromMenuBarItem setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagShift];

    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:NSLocalizedString(@"Donate...", @"Donate menu item") action:@selector(support) keyEquivalent:@""];
    [menu addItemWithTitle:NSLocalizedString(@"Quit Mac Media Key Forwarder", @"Quit App menu item") action:@selector(terminate) keyEquivalent:@"q"];

    // Setup the status bar item.
    NSImage* image = [NSImage imageNamed:@"icon"]; // Ensure "icon.png" or "icon.icns" is in resources.
    if (image) {
        [image setTemplate:YES]; // Allows the icon to adapt to light/dark mode.
    }
    
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    [statusItem setToolTip:@"Mac Media Key Forwarder"];
    [statusItem setMenu:menu];
    [statusItem setImage:image];
    // Allow removal by Cmd+Drag, and terminate app if removed (standard behavior).
    [statusItem setBehavior:NSStatusItemBehaviorRemovalAllowed | NSStatusItemBehaviorTerminationOnRemoval];

    // Hide or show menu bar icon based on user preference.
    if ([self shouldHideFromMenuBar]) {
        [statusItem setVisible:NO];
    } else {
        [statusItem setVisible:YES];
    }
    
    // Set initial checkmark states for menu items.
    [self updateStartupItemState];
    [self updatePauseState];
    [self updateOptionState];
    
    // --- Setup Event Tap ---
    // Define the mask for events we are interested in (system defined events).
    CGEventMask eventMask = CGEventMaskBit(NX_SYSDEFINED);
    // Create the event tap.
    eventPort = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, eventMask, tapEventCallback, (__bridge void * _Nullable)(self));

    // Fallback if the more specific mask fails (less common).
    if (eventPort == NULL) {
        NSLog(@"Failed to create event tap with CGEventMaskBit(NX_SYSDEFINED). Trying NX_SYSDEFINEDMASK.");
        eventMask = NX_SYSDEFINEDMASK; // Broader mask for system defined events.
        eventPort = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, kCGEventTapOptionDefault, eventMask, tapEventCallback, (__bridge void * _Nullable)(self));
    }

    if (eventPort != NULL) {
        // Create a run loop source from the event tap mach port.
        eventPortSource = CFMachPortCreateRunLoopSource(kCFAllocatorSystemDefault, eventPort, 0);
        if (eventPortSource) {
            // Add the source to the current run loop.
            CFRunLoopAddSource(CFRunLoopGetCurrent(), eventPortSource, kCFRunLoopCommonModes);
            // Enable or disable the event tap based on the initial pause state.
            if (pauseState == PauseStatePause) {
                 CGEventTapEnable(eventPort, FALSE); // Disabled if manually paused.
            } else {
                 if (pauseState == PauseStateAutomatic) {
                    // If automatic, check if any player is running to decide initial tap state.
                    BOOL anyPlayerRunning = NO;
                    for (id<PlayerController> controller in playerControllers) {
                        if ([controller isRunning]) {anyPlayerRunning = YES; break;}
                    }
                    CGEventTapEnable(eventPort, anyPlayerRunning); // Enable only if a player is running.
                 } else {
                    CGEventTapEnable(eventPort, TRUE); // Enabled if not paused and not automatic with no players.
                 }
            }
        } else {
            // Failed to create run loop source. Clean up and terminate.
            NSLog(@"Failed to create event port run loop source.");
            if(eventPort) CFRelease(eventPort);
            eventPort = NULL;
            [self showEventTapErrorAlert]; // Inform user about the issue.
            [NSApp terminate:self];
        }
    } else {
        // Failed to create event tap. Inform user and terminate.
        NSLog(@"Failed to create event port.");
        [self showEventTapErrorAlert];
        [NSApp terminate:self];
    }
}

// Displays an alert to the user indicating that the event tap could not be created,
// often due to missing Accessibility or Automation permissions.
- (void)showEventTapErrorAlert {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:NSLocalizedString(@"Event Listening Error", @"Title for event listening error alert")];
    [alert setInformativeText:NSLocalizedString(@"Mac Media Key Forwarder could not start listening for media key events. This is often due to missing Accessibility or Automation permissions. Please check System Settings > Privacy & Security, and ensure Mac Media Key Forwarder is allowed in both Accessibility and Automation sections.", @"Informative text for event listening error")];
    [alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK button on alert")];
    [alert runModal];
}

// Called when the application is reopened (e.g., by clicking the Dock icon).
// If the menu bar icon is hidden, this action makes it visible again.
- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag
{
    if (statusItem && ![statusItem isVisible]) {
        [self setHideFromMenuBar:NO]; // Update preference to show.
        [statusItem setVisible:YES];  // Make status item visible.
    }
    return YES;
}

// Enables the event tap.
- (void)startEventSession
{
    if (eventPort && !CGEventTapIsEnabled(eventPort)) CGEventTapEnable(eventPort, TRUE);
}

// Disables the event tap.
- (void)stopEventSession
{
    if (eventPort && CGEventTapIsEnabled(eventPort)) CGEventTapEnable(eventPort, FALSE);
}

// Called when the application is about to terminate.
// Ensures proper cleanup of the event tap and run loop source.
- (void)terminate
{
    // Invalidate and release the run loop source.
    if (eventPortSource) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), eventPortSource, kCFRunLoopCommonModes);
        CFRunLoopSourceInvalidate(eventPortSource);
        CFRelease(eventPortSource);
        eventPortSource = NULL;
    }
    // Disable and release the event tap.
    if (eventPort) {
        if (CGEventTapIsEnabled(eventPort)) { // Check before disabling
            CGEventTapEnable(eventPort, FALSE);
        }
        // According to documentation, CFMachPortInvalidate should be called on the port
        // before releasing it if it was added to a runloop. However, CGEventTapCreate
        // returns a CFMachPortRef that is owned by the caller and should be released.
        // It's less clear if it needs invalidation in this specific CGEventTap context.
        // CFMachPortInvalidate(eventPort); // Potentially add if issues arise.
        CFRelease(eventPort);
        eventPort = NULL;
    }
    [NSApp terminate:nil]; // Proceed with application termination.
}

// Opens the donation link in the default web browser.
- (void)support
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://paypal.me/milgra"]];
}

#pragma mark - Menu Actions: App Prioritization

// Sets media key priority to "None" (send to all running players).
- (void)prioritizeNone
{
    mediaKeysPriority = MediaKeysPrioritizeNone;
    [[NSUserDefaults standardUserDefaults] setObject:@(mediaKeysPriority) forKey:kUserDefaultsPriorityOptionKey];
    [self updateOptionState]; // Update menu item checkmarks.
}

// Sets media key priority to "iTunes" (or "Music.app").
- (void)prioritizeITunes
{
    mediaKeysPriority = MediaKeysPrioritizeITunes;
    [[NSUserDefaults standardUserDefaults] setObject:@(mediaKeysPriority) forKey:kUserDefaultsPriorityOptionKey];
    [self updateOptionState];
}

// Sets media key priority to "Spotify".
- (void)prioritizeSpotify
{
    mediaKeysPriority = MediaKeysPrioritizeSpotify;
    [[NSUserDefaults standardUserDefaults] setObject:@(mediaKeysPriority) forKey:kUserDefaultsPriorityOptionKey];
    [self updateOptionState];
}

#pragma mark - Menu Actions: Pause Control

// Toggles manual pause state for media key forwarding.
- (void)manualPause
{
    if (pauseState == PauseStatePause) { // If currently manually paused, unpause.
        pauseState = PauseStateNone;      // Set state to normal (not paused).
        // If automatic pausing is also enabled, we need to respect its rules.
        if (self->pauseState == PauseStateAutomatic) { // Check the *effective* current global state for automatic after change
            BOOL anyPlayerRunning = NO;
            for (id<PlayerController> controller in playerControllers) {
                if ([controller isRunning]) { anyPlayerRunning = YES; break; }
            }
            if (anyPlayerRunning) [self startEventSession]; // Only start if a player is running.
            // else, it remains stopped due to auto-pause rules.
        } else {
            [self startEventSession]; // Not auto-pause, so just enable tap.
        }
    } else { // If not manually paused, then pause it.
        pauseState = PauseStatePause; // Set state to manually paused.
        [self stopEventSession];      // Disable event tap.
    }
    [[NSUserDefaults standardUserDefaults] setObject:@(pauseState) forKey:kUserDefaultsPauseOptionKey];
    [self updatePauseState]; // Update menu item checkmarks.
}

// Toggles automatic pause state (pause if no recognized players are running).
- (void)autoPause
{
    if (pauseState == PauseStateAutomatic) { // If currently in auto-pause mode, turn it off.
        pauseState = PauseStateNone;          // Set state to normal (neither manual nor auto pause).
        // If the event tap was previously disabled by auto-pause (because no players were running),
        // enabling it now makes sense as the user explicitly turned off auto-pause.
        if (eventPort && !CGEventTapIsEnabled(eventPort)) {
            [self startEventSession];
        }
    } else { // If not in auto-pause mode, turn it on.
        pauseState = PauseStateAutomatic;
        // Check current player running status to decide if tap should be immediately disabled.
        BOOL anyPlayerRunning = NO;
        for (id<PlayerController> controller in playerControllers) {
            if ([controller isRunning]) { anyPlayerRunning = YES; break; }
        }
        if (!anyPlayerRunning) {
            [self stopEventSession]; // No players running, so disable tap.
        } else {
            // Players are running, ensure tap is enabled (it might be off if manualPause was just active).
            if (eventPort && !CGEventTapIsEnabled(eventPort)) {
                 [self startEventSession];
            }
        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:@(pauseState) forKey:kUserDefaultsPauseOptionKey];
    [self updatePauseState]; // Update menu item checkmarks.
}

#pragma mark - Menu Actions: Other

// Toggles the "Open at Login" setting.
- (void)toggleStartupItem {
    [GBLaunchAtLogin toggleLaunchAtLogin]; // Uses a helper library for this.
    [self updateStartupItemState]; // Update menu item checkmark.
}

// Hides the menu bar icon.
// Also enables "Open at Login" if not already, to prevent losing access to the app.
- (void)hideFromMenuBar
{
    [self setHideFromMenuBar:YES]; // Save preference.
    if (statusItem) [statusItem setVisible:NO]; // Hide the icon.
    
    // If hiding the icon, ensure "Open at Login" is enabled so the app is still accessible after restart.
    if (![GBLaunchAtLogin isLoginItem]) {
        [GBLaunchAtLogin addAppAsLoginItem];
        [self updateStartupItemState];
    }
}

// Saves the preference for hiding the menu bar icon.
- (void)setHideFromMenuBar:(BOOL)hidden
{
    [[NSUserDefaults standardUserDefaults] setBool:hidden forKey:kUserDefaultsHideFromMenuBarOptionKey];
}

// Reads the preference for hiding the menu bar icon.
- (BOOL)shouldHideFromMenuBar
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:kUserDefaultsHideFromMenuBarOptionKey];
}

#pragma mark - UI Update Methods (for Menu Items)

// Updates checkmarks for prioritization menu items.
- (void)updateOptionState
{
    if (!priorityOptionItems || priorityOptionItems.count < 3) return; // Basic safety check.
    
    [priorityOptionItems[0] setState:(mediaKeysPriority == MediaKeysPrioritizeNone ? NSControlStateValueOn : NSControlStateValueOff)];
    [priorityOptionItems[1] setState:(mediaKeysPriority == MediaKeysPrioritizeITunes ? NSControlStateValueOn : NSControlStateValueOff)];
    [priorityOptionItems[2] setState:(mediaKeysPriority == MediaKeysPrioritizeSpotify ? NSControlStateValueOn : NSControlStateValueOff)];
}

// Updates checkmarks for pause control menu items.
- (void)updatePauseState
{
    if (!pauseOptionItems || pauseOptionItems.count < 2) return; // Basic safety check.
    
    // Exclusive states: only one of these can be "On" if they represent different modes.
    // If they are toggles, their logic might be different.
    // Current logic implies PauseStatePause and PauseStateAutomatic are mutually exclusive active states,
    // or both can be off (PauseStateNone).
    [pauseOptionItems[0] setState:(pauseState == PauseStatePause ? NSControlStateValueOn : NSControlStateValueOff)];     // Manual Pause
    [pauseOptionItems[1] setState:(pauseState == PauseStateAutomatic ? NSControlStateValueOn : NSControlStateValueOff)]; // Auto Pause
}

// Updates checkmark for the "Open at Login" menu item.
- (void)updateStartupItemState {
    if (startupItem) {
      [startupItem setState:[GBLaunchAtLogin isLoginItem] ? NSControlStateValueOn : NSControlStateValueOff];
    }
}

#pragma mark - NSMenuDelegate

// Called just before the menu is about to open.
// This is a good place to ensure all menu item states (checkmarks) are up-to-date.
- (void)menuWillOpen:(NSMenu *)menu
{
    [self updateStartupItemState];
    [self updatePauseState];
    [self updateOptionState];
}

@end
