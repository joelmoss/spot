import SwiftUI
import AppKit

struct MiniPlayerView: View {
    @Environment(\.openWindow) private var openWindow
    let spotify: SpotifyController
    let auth: SpotifyAuth
    @State private var isHovering = false
    @AppStorage("showControls") private var showControls = true

    var body: some View {
        Group {
            if spotify.isSpotifyRunning {
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
            if isHovering {
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
        .frame(width: showControls ? 320 : 220, height: showControls ? 110 : 300, alignment: .top)
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
        Group {
            if showControls {
                horizontalLayout
            } else {
                verticalLayout
            }
        }
    }

    private var horizontalLayout: some View {
        HStack(spacing: 0) {
            artwork(size: 110)
                .overlay(alignment: .bottomTrailing) {
                    likeButton(size: 12)
                        .padding(6)
                }

            VStack(alignment: .leading, spacing: 2) {
                trackInfo

                Spacer().frame(height: 6)

                volumeSlider
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            controls
                .padding(.trailing, 12)
        }
    }

    private var verticalLayout: some View {
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

    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(spotify.trackName)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)

            Text(spotify.artistName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
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

    private var controls: some View {
        HStack(spacing: 4) {
            Button(action: spotify.previousTrack) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)

            Button(action: spotify.togglePlayPause) {
                Image(systemName: spotify.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)

            Button(action: spotify.nextTrack) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
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

    private var notRunningView: some View {
        VStack(spacing: 4) {
            Image(systemName: "music.note")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No active playback")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
