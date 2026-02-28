import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("showControls") private var showControls = true
    @State private var clientIDText = ""
    let auth: SpotifyAuth
    let updater: UpdaterController

    var body: some View {
        Form {
            Toggle("Show track controls", isOn: $showControls)

            Section("Spotify Account") {
                if !auth.hasClientID {
                    Text("Enter a Client ID below to connect your account.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if auth.isAuthenticated {
                    HStack {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Disconnect") {
                            auth.disconnect()
                            clientIDText = ""
                            dismiss()
                        }
                    }
                } else {
                    HStack {
                        Label("Not connected", systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Connect") {
                            auth.authorize()
                        }
                    }
                    Text("Connect to like songs from the player.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("Client ID", text: $clientIDText)
                    .font(.system(.body, design: .monospaced))
                    .disabled(auth.isAuthenticated)
                    .onChange(of: clientIDText) {
                        auth.setClientID(clientIDText)
                    }

                Link(
                    "Open Spotify Developer Dashboard",
                    destination: URL(string: "https://developer.spotify.com/dashboard")!
                )
                .font(.caption)

                if !auth.hasClientID {
                    Text(
                        "Create an app and set the redirect URI to **spot-app://callback**. Select **Web API** for the API type."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section("Updates") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(
                        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
                            as? String ?? "Unknown"
                    )
                    .foregroundStyle(.secondary)
                }

                Button("Check for Updates...") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)

                Toggle(
                    "Automatically check for updates",
                    isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    ))
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.hidden)
        .frame(width: 450)
        .fixedSize()
        .onAppear {
            clientIDText = auth.clientID ?? ""
            NSApp.setActivationPolicy(.regular)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window != NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
