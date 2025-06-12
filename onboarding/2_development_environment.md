# 2. Development Environment Setup

This guide will help you set up your development environment to work on MacMediaKeyForwarder. Since you've used Xcode before, some of this might be familiar, but we'll highlight project-specific aspects.

## Prerequisites

*   A Mac running a compatible version of macOS.
*   Xcode: Ensure you have a recent version of Xcode installed. You can download it from the Mac App Store.

## Opening the Project

1.  **Clone the Repository**: If you haven't already, clone the project repository to your local machine.
2.  **Open in Xcode**:
    *   Navigate to the root directory of the cloned project.
    *   Locate the `MacMediaKeyForwarder.xcodeproj` file. This is the Xcode project file.
    *   Double-click `MacMediaKeyForwarder.xcodeproj` to open the project in Xcode.

## Xcode Interface Quick Points

*   **Project Navigator (Left Pane)**: Shows all the files and folders in the project. You'll see `MacMediaKeyForwarder` as the main group, containing source files (`.m`, `.h`), resources, and frameworks.
*   **Editor Area (Center Pane)**: Where you'll view and edit code, UI files (like `.xib` files), and other project assets.
*   **Toolbar (Top)**: Contains buttons to run/stop the app, select the active scheme (target + build configuration), and view build status.
*   **Inspectors (Right Pane)**: Provides context-sensitive information and settings for selected files or UI elements.

## Project Structure Highlights

*   **`MacMediaKeyForwarder` Group**:
    *   `AppDelegate.h` / `AppDelegate.m`: The main entry point and delegate for the application.
    *   `main.m`: Contains the `main()` function, which starts the application.
    *   `.xib` files (e.g., `Base.lproj/MainMenu.xib`): These are Interface Builder files that define the application's user interface. You can edit these visually in Xcode. Double-clicking them will open them in Interface Builder mode.
    *   `Info.plist`: A configuration file containing metadata about the app (bundle ID, version, etc.).
    *   `.lproj` folders (e.g., `en.lproj`, `de.lproj`): Contain localized resources, primarily string files for different languages.
*   **`Frameworks` Group**:
    *   `GBLaunchAtLogin`: This is a third-party framework used to provide the "Launch at Login" functionality for the application. You can find its source code and license within this group.
*   **`Products` Group**:
    *   `MacMediaKeyForwarder.app`: This is the compiled application bundle that gets generated when you build the project.

## Build Schemes and Configurations

*   **Scheme**: In Xcode, a scheme defines what to build, how to build it, and what tests to run. The project should have a default scheme, likely named `MacMediaKeyForwarder`.
    *   You can select the active scheme from the dropdown menu in the Xcode toolbar (next to the Run/Stop buttons).
*   **Build Configurations**: Typically `Debug` and `Release`.
    *   `Debug`: Used during development. Includes debugging symbols and less optimization.
    *   `Release`: Used for distributing the app. More optimized and excludes debugging symbols.
    You usually work with the `Debug` configuration during development.

## Dependencies

The main external dependency noted so far is `GBLaunchAtLogin.framework`, which is included directly in the project. There don't appear to be package manager configurations like CocoaPods or Swift Package Manager in the root, so dependencies are likely managed manually or are minimal.

## A Note on `.xib` Files

Since you're not deeply familiar with Xcode, here's a quick on `.xib` (often called "NIB") files like `MainMenu.xib`:

*   These files store your app's user interface.
*   When you select a `.xib` file in the Project Navigator, Xcode shows a visual representation of the UI.
*   You can drag and drop UI elements (buttons, labels, menus) onto the canvas.
*   The "Connections Inspector" (often on the right-hand side) is used to link UI elements to code (IBOutlets and IBActions). This is how button clicks trigger code in your `.m` files.

This project seems to be primarily an Objective-C application. We'll cover some language basics relevant to this project next.

Proceed to: [Building and Running the App](./3_building_and_running.md)
