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
    var supportsVolume: Bool = true
    var hasCheckedPlayback: Bool = false
    var auth: (any SpotifyAuthProviding)?
    private var timer: Timer?
    private var isSettingVolume = false
    private var volumeDebounceTask: Task<Void, Never>?
    private var lastCheckedTrackID: String = ""

    func startPolling() {
        fetchCurrentTrack()
        timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
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
        volumeDebounceTask?.cancel()
        volumeDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            let intValue = Int(value)
            await Self.setVolumeViaAppleScript(intValue)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self.isSettingVolume = false }
        }
    }

    @MainActor
    private static func setVolumeViaAppleScript(_ percent: Int) {
        let source = "tell application \"Spotify\" to set sound volume to \(percent)"
        if let script = NSAppleScript(source: source) {
            var error: NSDictionary?
            script.executeAndReturnError(&error)
            if let error {
                print("[Spot] AppleScript set volume error: \(error)")
            }
        }
    }

    private static func getVolumeViaAppleScript() -> Int? {
        let source = "tell application \"Spotify\" to get sound volume"
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            print("[Spot] AppleScript get volume error: \(error)")
            return nil
        }
        return Int(result.int32Value)
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
            hasCheckedPlayback = true
            trackName = ""
            artistName = ""
            artworkURL = nil
            isPlaying = false
            trackID = ""
            isLiked = false
            return
        }

        isSpotifyRunning = true
        hasCheckedPlayback = true
        trackName = state.trackName
        artistName = state.artistName
        artworkURL = state.artworkURL
        isPlaying = state.isPlaying
        supportsVolume = state.supportsVolume
        if !isSettingVolume {
            volume = Double(Self.getVolumeViaAppleScript() ?? state.volume)
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
