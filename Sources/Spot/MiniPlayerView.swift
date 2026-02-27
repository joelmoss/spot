import SwiftUI
import AppKit

struct MiniPlayerView: View {
    let spotify: SpotifyController
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if spotify.isSpotifyRunning {
                    playerView
                } else {
                    notRunningView
                }
            }

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
        .frame(width: 320, height: 110)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onAppear {
            spotify.startPolling()
        }
        .onDisappear {
            spotify.stopPolling()
        }
    }

    private var playerView: some View {
        HStack(spacing: 12) {
            AsyncImage(url: spotify.artworkURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "music.note")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(spotify.trackName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(spotify.artistName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer().frame(height: 2)

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
            .frame(maxWidth: .infinity, alignment: .leading)

            controls
        }
        .padding(12)
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
            Text("Spotify is not running")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
