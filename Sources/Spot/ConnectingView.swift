import SwiftUI

struct ConnectingView: View {
    let auth: SpotifyAuth
    @State private var showRetry = false
    @State private var timerTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)

            Text("Connecting to Spotify...")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            if showRetry {
                HStack(spacing: 12) {
                    Button("Try again") {
                        auth.authorize()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .underline()

                    Button("Restart") {
                        restart()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .underline()
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startTimer()
            auth.authorize()
        }
        .onDisappear {
            timerTask?.cancel()
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        showRetry = false
        timerTask = Task {
            try? await Task.sleep(for: .seconds(10))
            if !Task.isCancelled {
                withAnimation { showRetry = true }
            }
        }
    }

    private func tryAgain() {
        startTimer()
        auth.authorize()
    }

    private func restart() {
        timerTask?.cancel()
        auth.setClientID("")
    }
}
