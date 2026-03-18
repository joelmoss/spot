import AppKit
import SwiftUI

struct LyricsOverlayView: View {
    var spotify: SpotifyController
    var dismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                if spotify.isFetchingLyrics {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                } else {
                    lyricsContent
                }

                Spacer()

                trackInfoBar
                    .padding(.bottom, 40)
            }
        }
        .onTapGesture { dismiss() }
    }

    @ViewBuilder
    private var lyricsContent: some View {
        switch spotify.parsedLyrics {
        case .synced(let lines):
            syncedLyricsView(lines: lines)
        case .plain(let text):
            plainLyricsView(text: text)
        case .none:
            Text("No lyrics found")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func syncedLyricsView(lines: [LyricsLine]) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                        let distance = abs(index - spotify.currentLineIndex)
                        Text(line.text)
                            .font(.system(size: fontSize(for: distance), weight: fontWeight(for: distance)))
                            .foregroundStyle(.white.opacity(lineOpacity(for: distance)))
                            .scaleEffect(lineScale(for: distance))
                            .blur(radius: lineBlur(for: distance))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: screenWidth * 0.75)
                            .id(line.id)
                            .allowsHitTesting(false)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: spotify.currentLineIndex)
                    }
                }
                .padding(.vertical, screenHeight / 2.5)
                .frame(maxWidth: .infinity)
            }
            .allowsHitTesting(false)
            .onChange(of: spotify.currentLineIndex) { _, newIndex in
                guard newIndex < lines.count else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    proxy.scrollTo(lines[newIndex].id, anchor: .center)
                }
            }
            .onAppear {
                guard spotify.currentLineIndex < lines.count else { return }
                proxy.scrollTo(lines[spotify.currentLineIndex].id, anchor: .center)
            }
        }
    }

    private func plainLyricsView(text: String) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            Text(text)
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .frame(maxWidth: screenWidth * 0.65)
                .padding(.vertical, 60)
                .frame(maxWidth: .infinity)
        }
        .allowsHitTesting(false)
    }

    private var trackInfoBar: some View {
        HStack(spacing: 12) {
            if let url = spotify.artworkURL {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color.gray.opacity(0.3)
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(spotify.trackName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(spotify.artistName)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Screen dimensions

    private var screenWidth: CGFloat {
        NSScreen.main?.frame.width ?? 1440
    }

    private var screenHeight: CGFloat {
        NSScreen.main?.frame.height ?? 900
    }

    // MARK: - Line Styling

    private func fontSize(for distance: Int) -> CGFloat {
        switch distance {
        case 0: return 64
        case 1: return 44
        case 2: return 34
        default: return 28
        }
    }

    private func fontWeight(for distance: Int) -> Font.Weight {
        switch distance {
        case 0: return .bold
        case 1: return .semibold
        default: return .regular
        }
    }

    private func lineOpacity(for distance: Int) -> Double {
        switch distance {
        case 0: return 1.0
        case 1: return 0.45
        case 2: return 0.25
        default: return 0.12
        }
    }

    private func lineScale(for distance: Int) -> CGFloat {
        switch distance {
        case 0: return 1.0
        case 1: return 0.95
        default: return 0.9
        }
    }

    private func lineBlur(for distance: Int) -> CGFloat {
        switch distance {
        case 0: return 0
        case 1: return 0
        case 2: return 0.5
        default: return 1.0
        }
    }
}
