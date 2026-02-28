import SwiftUI
import AppKit

struct OnboardingView: View {
    let auth: SpotifyAuth
    @State private var clientID = ""
    @State private var copied = false

    private static let redirectURI = "spot-app://callback"
    private static let dashboardURL = URL(string: "https://developer.spotify.com/dashboard")!

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("Welcome to Spot")
                    .font(.system(size: 16, weight: .semibold))
                Text("Connect your Spotify account to get started.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Steps
            VStack(alignment: .leading, spacing: 10) {
                step(number: 1, title: "Create an app on the Spotify Developer Dashboard") {
                    Button("Open Dashboard") {
                        NSWorkspace.shared.open(Self.dashboardURL)
                    }
                    .controlSize(.small)
                }

                step(number: 2, title: "Set the redirect URI and API type") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(Self.redirectURI)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)

                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(Self.redirectURI, forType: .string)
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copied = false
                                }
                            } label: {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Text("Select \"Web API\" as the API type.")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }

                step(number: 3, title: "Paste your Client ID below") {
                    EmptyView()
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Input
            HStack(spacing: 6) {
                TextField("Client ID", text: $clientID)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11, design: .monospaced))
                    .onSubmit { save() }

                Button("Save") { save() }
                    .controlSize(.small)
                    .disabled(clientID.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func step<Content: View>(number: Int, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(.secondary))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                content()
            }
        }
    }

    private func save() {
        let trimmed = clientID.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        auth.setClientID(trimmed)
    }
}
