# 3. Building and Running the App

Now that you have the project open in Xcode and understand the basic environment, let's build and run MacMediaKeyForwarder.

## Selecting the Target/Scheme

1.  **Ensure the correct scheme is selected**: In the Xcode toolbar (top left, near the play and stop buttons), there's a dropdown menu. Make sure it's set to `MacMediaKeyForwarder` and the target device is `My Mac` (or your Mac's name).

    ![Xcode Scheme Selector](https://developer.apple.com/library/archive/documentation/ToolsLanguages/Conceptual/Xcode_Overview/Art/target_menu_2x.png)
    *(Image sourced from Apple's Xcode documentation for illustration)*

## Building the Application

1.  **Clean Build Folder (Optional but Recommended for First Time)**: Sometimes, old build artifacts can cause issues. You can clean the build folder by selecting **Product > Clean Build Folder** from the Xcode menu bar (or press **Shift + Command + K**).
2.  **Build**:
    *   Click the **Play button** (which also runs the app after building) in the Xcode toolbar.
    *   Alternatively, to just build without running, select **Product > Build** from the menu bar (or press **Command + B**).

    Xcode will compile the Objective-C code, link frameworks, and package the application. You can monitor the build progress in the status bar at the top of Xcode.

## Running the Application

1.  **Run**:
    *   If you clicked the **Play button** in the previous step, the application will attempt to run automatically after a successful build.
    *   If you only built the app (Command + B), you can run it by clicking the **Play button** now or by selecting **Product > Run** from the menu bar (or press **Command + R**).

## What to Expect When Running

*   **Status Bar Icon**: MacMediaKeyForwarder is likely a status bar application. This means it won't open a traditional window when it launches. Instead, look for its icon in the macOS menu bar at the top right of your screen.
    *   The icon might be `appicon.png` or similar from the project resources.
*   **Menu**: Clicking the status bar icon should reveal a menu with options to select which media player to control, settings, and a quit option.
*   **Permissions**:
    *   **Accessibility Access**: For an application like this to intercept media keys globally, it will almost certainly require Accessibility permissions.
    *   The first time you run it, or when you try to use its core feature, macOS should prompt you to grant these permissions.
    *   You'll need to go to **System Preferences > Security & Privacy > Privacy > Accessibility**.
    *   Click the lock icon to make changes (you'll need your admin password).
    *   Drag `MacMediaKeyForwarder.app` from the `Products` folder in Xcode's Project Navigator into the list, or find it in your `DerivedData` folder (Xcode's build output location) and add it. Ensure the checkbox next to it is checked.
    *   The `security_a.png` and `security_b.png` files in the project root might be screenshots related to this process.
    *   **You might need to restart the application after granting permissions.**

## Debugging

*   **Xcode Debugger**: When you run the app from Xcode (using the Play button), the built-in debugger is automatically attached.
*   **Breakpoints**: You can set breakpoints by clicking in the gutter next to a line number in your code. When the app execution hits that line, it will pause, allowing you to inspect variables and step through code.
*   **Console Output**: Output from `NSLog` statements (Objective-C's equivalent of `print` or `console.log`) will appear in the Xcode console pane (usually at the bottom of the Xcode window). If it's not visible, you can show it via **View > Debug Area > Activate Console**.
*   **Common Issues**:
    *   **Permissions Not Granted**: If media keys don't seem to work, double-check the Accessibility permissions.
    *   **App Crashing**: If the app crashes, the debugger will usually stop at the line of code that caused the crash. The console might also have an error message.

## Stopping the Application

*   **From Xcode**: Click the **Stop button** in the Xcode toolbar.
*   **From the App Itself**: If it's a status bar app, it should have a "Quit" option in its menu.

With these steps, you should be able to build, run, and start debugging MacMediaKeyForwarder.

Next, we'll dive into some [Objective-C Basics for This Project](./4_objective_c_basics.md).
