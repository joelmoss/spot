import SwiftUI
import AppKit

struct MiniPlayerView: View {
    @Environment(\.openWindow) private var openWindow
    let spotify: SpotifyController
    let auth: SpotifyAuth
    @State private var isHovering = false

    var body: some View {
        Group {
            if !auth.hasClientID {
                OnboardingView(auth: auth)
            } else if !auth.isAuthenticated {
                connectView
            } else if spotify.isSpotifyRunning {
                playerView
            } else {
                notRunningView
            }
        }
        .overlay(alignment: .topLeading) {
            if isHovering {
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .background(Circle().fill(.ultraThickMaterial).frame(width: 12, height: 12))
                }
                .buttonStyle(.plain)
                .padding(6)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isHovering && auth.hasClientID {
                Button {
                    openWindow(id: "settings")
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .background(Circle().fill(.ultraThickMaterial).frame(width: 12, height: 12))
                }
                .buttonStyle(.plain)
                .padding(6)
                .transition(.opacity)
            }
        }
        .frame(width: windowWidth, height: windowHeight, alignment: .top)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onAppear {
            spotify.auth = auth
            spotify.startPolling()
        }
        .onDisappear {
            spotify.stopPolling()
        }
    }

    private var playerView: some View {
        VStack(spacing: 0) {
            artwork(size: 220)
                .overlay(alignment: .bottomTrailing) {
                    likeButton(size: 14)
                        .padding(8)
                }

            VStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text(spotify.trackName)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)

                    Text(spotify.artistName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                volumeSlider
            }
            .padding(12)
        }
    }

    private func artwork(size: CGFloat) -> some View {
        AsyncImage(url: spotify.artworkURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.3))
                        .foregroundStyle(.secondary)
                }
        }
        .frame(width: size, height: size)
        .clipped()
    }

    private var volumeSlider: some View {
        HStack(spacing: 4) {
            Image(systemName: volumeIcon)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 12)

            Slider(value: Binding(
                get: { spotify.volume },
                set: { spotify.setVolume($0) }
            ), in: 0...100)
            .controlSize(.mini)
        }
    }

    private func likeButton(size: CGFloat) -> some View {
        Group {
            if spotify.auth?.isAuthenticated == true && !spotify.trackID.isEmpty {
                Button(action: spotify.toggleLike) {
                    Image(systemName: spotify.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: size))
                        .foregroundStyle(spotify.isLiked ? .red : .white)
                        .contentTransition(.symbolEffect(.replace))
                        .shadow(color: .black.opacity(0.5), radius: 2)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var volumeIcon: String {
        if spotify.volume == 0 { return "speaker.slash.fill" }
        if spotify.volume < 33 { return "speaker.wave.1.fill" }
        if spotify.volume < 66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private var windowWidth: CGFloat {
        if !auth.hasClientID { return 340 }
        if !auth.isAuthenticated { return 220 }
        return 220
    }

    private var windowHeight: CGFloat {
        if !auth.hasClientID { return 380 }
        if !auth.isAuthenticated { return 160 }
        return 300
    }

    private var connectView: some View {
        ConnectingView(auth: auth)
    }

    private var notRunningView: some View {
        VStack(spacing: 4) {
            Image(systemName: "music.note")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No active playback")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            if let until = auth.rateLimitedUntil, until > Date() {
                let total = Int(ceil(until.timeIntervalSinceNow))
                let label = if total >= 3600 {
                    "\(total / 3600) hr"
                } else if total >= 60 {
                    "\(Int(ceil(Double(total) / 60))) min"
                } else {
                    "\(total) sec"
                }
                Text("Rate limited — retrying in \(label)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
