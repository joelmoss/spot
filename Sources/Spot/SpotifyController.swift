import Foundation
import AppKit

@Observable
final class SpotifyController {
    var trackName: String = ""
    var artistName: String = ""
    var artworkURL: URL?
    var isPlaying: Bool = false
    var isSpotifyRunning: Bool = false
    var volume: Double = 50
    var trackID: String = ""
    var isLiked: Bool = false
    var auth: (any SpotifyAuthProviding)?
    private var timer: Timer?
    private var isSettingVolume = false
    private var lastCheckedTrackID: String = ""

    func startPolling() {
        fetchCurrentTrack()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.fetchCurrentTrack()
        }
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func nextTrack() {
        guard let auth else { return }
        Task {
            await auth.nextTrack()
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run { self.fetchCurrentTrack() }
        }
    }

    func previousTrack() {
        guard let auth else { return }
        Task {
            await auth.previousTrack()
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run { self.fetchCurrentTrack() }
        }
    }

    func setVolume(_ value: Double) {
        isSettingVolume = true
        volume = value
        guard let auth else { return }
        Task {
            await auth.setVolume(Int(value))
            try? await Task.sleep(nanoseconds: 500_000_000)
            await MainActor.run { self.isSettingVolume = false }
        }
    }

    func togglePlayPause() {
        guard let auth else { return }
        Task {
            if isPlaying {
                await auth.pause()
            } else {
                await auth.play()
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run { self.fetchCurrentTrack() }
        }
    }

    func toggleLike() {
        guard !trackID.isEmpty, let auth, auth.isAuthenticated else { return }
        let id = trackID
        let shouldSave = !isLiked
        isLiked = shouldSave // optimistic update

        Task {
            let success: Bool
            if shouldSave {
                success = await auth.saveTrack(trackID: id)
            } else {
                success = await auth.removeTrack(trackID: id)
            }
            if !success {
                await MainActor.run { isLiked = !shouldSave }
            }
        }
    }

    private func fetchCurrentTrack() {
        guard let auth, auth.isAuthenticated else {
            isSpotifyRunning = false
            return
        }

        Task {
            let state = await auth.getCurrentPlayback()
            await MainActor.run {
                self.applyPlaybackState(state)
            }
        }
    }

    func applyPlaybackState(_ state: PlaybackState?) {
        guard let state else {
            isSpotifyRunning = false
            trackName = ""
            artistName = ""
            artworkURL = nil
            isPlaying = false
            trackID = ""
            isLiked = false
            return
        }

        isSpotifyRunning = true
        trackName = state.trackName
        artistName = state.artistName
        artworkURL = state.artworkURL
        isPlaying = state.isPlaying
        if !isSettingVolume {
            volume = Double(state.volume)
        }

        let newTrackID = state.trackID
        if newTrackID != trackID {
            trackID = newTrackID
            checkIfLiked()
        } else if lastCheckedTrackID != trackID {
            checkIfLiked()
        }
    }

    private func checkIfLiked() {
        guard !trackID.isEmpty, let auth, auth.isAuthenticated else {
            isLiked = false
            return
        }
        let id = trackID
        lastCheckedTrackID = id

        Task {
            let liked = await auth.checkIfLiked(trackID: id)
            await MainActor.run {
                if self.trackID == id {
                    self.isLiked = liked
                }
            }
        }
    }
}
