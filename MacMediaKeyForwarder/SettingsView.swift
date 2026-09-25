//
//  SettingsView.swift
//  MacMediaKeyForwarder
//
//  The Settings window. A grouped Form in two tabs, bound directly to
//  AppSettings so changes apply immediately. Every literal below is a
//  LocalizedStringKey and is looked up in Localizable.strings.
//

import SwiftUI

struct SettingsView: View {
    enum Tab: Hashable {
        case general
        case players
    }

    @ObservedObject var settings: AppSettings
    @State private var selectedTab: Tab

    init(settings: AppSettings, initialTab: Tab = .general) {
        self.settings = settings
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(settings: settings)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Tab.general)
            PlayersSettingsView(settings: settings)
                .tabItem { Label("Players", systemImage: "music.note") }
                .tag(Tab.players)
        }
        // A grouped Form scrolls and has no intrinsic height, so each tab
        // declares the size its content needs.
        .frame(width: 480)
        .padding(.top, 10)
        .onAppear { settings.refreshExternalState() }
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: $settings.launchAtLogin)
                Toggle("Hide from menu bar", isOn: $settings.hideFromMenuBar)
            } footer: {
                Text("Reopen the app to show the icon again.")
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
        .formStyle(.grouped)
        .frame(height: 310)
    }
}

private struct PlayersSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
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
                Toggle("Also send volume keys to Apple Music", isOn: $settings.forwardVolumeToMusic)
            } footer: {
                Text("Changes Apple Music's own volume together with the system volume, which lets the volume keys control AirPlay speakers.")
            }
            Section {
                SecureField("Cider API Token", text: $settings.ciderApiToken)
            } header: {
                Text("Cider")
            } footer: {
                Text("Paste the token generated in Cider under Settings > Connectivity > Manage External Application Access to Cider. Leave empty if external access does not require a token.")
            }
        }
        .formStyle(.grouped)
        .frame(height: 500)
    }
}
