//
//  SettingsView.swift
//  MacMediaKeyForwarder
//
//  The Settings window: a toolbar with one tab per pane, like most Mac apps.
//  Each pane is a grouped Form bound directly to AppSettings so changes apply
//  immediately, and the window resizes to fit the selected pane. Every literal
//  below is a LocalizedStringKey and is looked up in Localizable.strings.
//

import Cocoa
import SwiftUI

final class SettingsWindowController: NSWindowController {

    convenience init(settings: AppSettings) {
        let tabs = SettingsTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addPane(GeneralSettingsView(settings: settings),
                     title: NSLocalizedString("General", comment: "General"),
                     symbolName: "gearshape")
        tabs.addPane(PlayersSettingsView(settings: settings),
                     title: NSLocalizedString("Players", comment: "Players"),
                     symbolName: "music.note")

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    override func showWindow(_ sender: Any?) {
        if window?.isVisible != true {
            window?.center()
        }
        super.showWindow(sender)
    }
}

/// Resizes the window to the selected pane, keeping its top edge in place,
/// both when switching tabs and when a pane's content height changes.
private final class SettingsTabViewController: NSTabViewController {

    func addPane<Content: View>(_ view: Content, title: String, symbolName: String) {
        let controller = NSHostingController(rootView: view)
        controller.sizingOptions = [.preferredContentSize]
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: title)
        addTabViewItem(item)
    }

    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        fitWindow(animate: true)
    }

    override func preferredContentSizeDidChange(for viewController: NSViewController) {
        super.preferredContentSizeDidChange(for: viewController)
        if viewController === tabViewItems[selectedTabViewItemIndex].viewController {
            fitWindow(animate: view.window?.isVisible == true)
        }
    }

    private func fitWindow(animate: Bool) {
        guard let window = view.window,
              let selected = tabViewItems[selectedTabViewItemIndex].viewController else { return }
        let size = selected.preferredContentSize
        guard size.height > 0 else { return }
        let contentRect = window.contentRect(forFrameRect: window.frame)
        guard contentRect.size != size else { return }
        var frame = window.frameRect(forContentRect: NSRect(origin: contentRect.origin, size: size))
        frame.origin.y = window.frame.maxY - frame.height
        window.setFrame(frame, display: true, animate: animate)
    }
}

/// A grouped Form scrolls and has no intrinsic height, so measure its content
/// and size it to fit. The window then follows the pane's height, which keeps
/// longer translations from being clipped.
private struct SettingsPane<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 300

    var body: some View {
        Form { content }
            .formStyle(.grouped)
            .scrollDisabled(true)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentSize.height + geometry.contentInsets.top + geometry.contentInsets.bottom
            } action: { _, newHeight in
                height = newHeight
            }
            .frame(width: 480, height: height)
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsPane {
            Section {
                Toggle("Open at login", isOn: $settings.launchAtLogin)
                Toggle(isOn: $settings.hideFromMenuBar) {
                    Text("Hide from menu bar")
                    Text("Reopen the app to show the icon again.")
                }
            }
            Section("Media key forwarding") {
                Picker("Media key forwarding", selection: $settings.pauseState) {
                    Text("On").tag(PauseState.none)
                    Text("Paused").tag(PauseState.pause)
                    Text("Pause if no player is running").tag(PauseState.automatic)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
        }
        .onAppear { settings.refreshExternalState() }
    }
}

private struct PlayersSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsPane {
            Section("Prioritized player") {
                Picker("Prioritized player", selection: $settings.priority) {
                    Text("Send events to all players").tag(MediaKeysPrioritize.none)
                    Text("Prioritize Apple Music").tag(MediaKeysPrioritize.music)
                    Text("Prioritize Spotify").tag(MediaKeysPrioritize.spotify)
                    Text("Prioritize Cider").tag(MediaKeysPrioritize.cider)
                    Text("Prioritize Spotifast").tag(MediaKeysPrioritize.spotifast)
                    Text("Prioritize Pear (YouTube Music)").tag(MediaKeysPrioritize.pear)
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
            Section {
                Toggle(isOn: $settings.launchPlayerHidden) {
                    Text("Launch player hidden")
                    Text("When the prioritized Apple Music or Spotify is not running, a media key starts it hidden instead of bringing its window to the front.")
                }
                Toggle(isOn: $settings.forwardVolumeToMusic) {
                    Text("Also send volume keys to Apple Music")
                    Text("Changes Apple Music's own volume together with the system volume, which lets the volume keys control AirPlay speakers.")
                }
            }
            Section {
                SecureField(text: $settings.ciderApiToken, prompt: Text("Optional")) {
                    Text("Cider API Token")
                }
            } header: {
                Text("Cider")
            } footer: {
                Text("Paste the token generated in Cider under Settings > Connectivity > Manage External Application Access to Cider. Leave empty if external access does not require a token.")
            }
        }
    }
}
