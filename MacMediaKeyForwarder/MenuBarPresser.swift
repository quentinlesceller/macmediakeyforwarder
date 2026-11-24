//
//  MenuBarPresser.swift
//  MacMediaKeyForwarder
//
//  Presses another app's menu bar items through Accessibility, even while that app is in the background.
//

import ApplicationServices
import Cocoa

// An empty modifier mask means Command alone.
struct MenuItemShortcut: Equatable {
    let character: Int
    let modifiers: AXMenuItemModifiers
}

struct AccessibilityMenuItem {
    let element: AXUIElement

    var shortcut: MenuItemShortcut? {
        guard let character = AccessibilityElement.attribute(element, kAXMenuItemCmdCharAttribute) as? String,
              let scalar = character.unicodeScalars.first,
              let modifiers = AccessibilityElement.attribute(element, kAXMenuItemCmdModifiersAttribute) as? UInt32 else { return nil }
        return MenuItemShortcut(character: Int(scalar.value), modifiers: AXMenuItemModifiers(rawValue: modifiers))
    }
}

struct AccessibilityMenu {
    let items: [AccessibilityMenuItem]

    func item(withShortcut shortcut: MenuItemShortcut) -> AccessibilityMenuItem? {
        items.first { $0.shortcut == shortcut }
    }
}

final class MenuBarPresser {

    private let bundleIdentifier: String
    // Accessibility calls block until the target app answers, so they stay off the event tap.
    private let queue: DispatchQueue

    init(bundleIdentifier: String) {
        self.bundleIdentifier = bundleIdentifier
        queue = DispatchQueue(label: "MenuBarPresser.\(bundleIdentifier)")
    }

    func press(_ select: @escaping ([AccessibilityMenu]) -> AccessibilityMenuItem?) {
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first?.processIdentifier else { return }
        queue.async {
            let application = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(application, 1)
            guard let item = select(Self.menus(of: application)) else { return }
            AXUIElementPerformAction(item.element, kAXPressAction as CFString)
        }
    }

    private static func menus(of application: AXUIElement) -> [AccessibilityMenu] {
        guard let menuBar = AccessibilityElement.element(application, kAXMenuBarAttribute) else { return [] }
        return AccessibilityElement.children(menuBar).compactMap { menuBarItem in
            guard let menu = AccessibilityElement.children(menuBarItem).first else { return nil }
            return AccessibilityMenu(items: AccessibilityElement.children(menu).map(AccessibilityMenuItem.init))
        }
    }
}

private enum AccessibilityElement {

    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? []
    }
}
