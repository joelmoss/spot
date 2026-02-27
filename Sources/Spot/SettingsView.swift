import SwiftUI

struct SettingsView: View {
    @AppStorage("showControls") private var showControls = true
    let auth: SpotifyAuth

    var body: some View {
        Form {
            Toggle("Show track controls", isOn: $showControls)

            Section("Spotify Account") {
                if auth.isAuthenticated {
                    HStack {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Spacer()
                        Button("Disconnect") {
                            auth.disconnect()
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
            }
        }
        .formStyle(.grouped)
        .scrollIndicators(.hidden)
        .frame(width: 320)
        .fixedSize()
    }
}
