import Foundation

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
    var lyrics: String?
    var showLyrics: Bool = false
    var isFetchingLyrics: Bool = false
    var auth: (any SpotifyAuthProviding)?
    private var timer: Timer?
    private var isSettingVolume = false
    private var volumeDebounceTask: Task<Void, Never>?
    private var lastCheckedTrackID: String = ""
    private var lastLyricsTrackID: String = ""
    private var currentPollingInterval: TimeInterval = 5.0

    private static let playingInterval: TimeInterval = 5.0
    private static let pausedInterval: TimeInterval = 15.0
    private static let inactiveInterval: TimeInterval = 30.0

    func startPolling() {
        fetchCurrentTrack()
        scheduleTimer(interval: Self.playingInterval)
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    func nextTrack() {
        guard let auth else { return }
        Task {
            await auth.nextTrack()
            await MainActor.run { self.resetTimer(after: 0.5) }
        }
    }

    func previousTrack() {
        guard let auth else { return }
        Task {
            await auth.previousTrack()
            await MainActor.run { self.resetTimer(after: 0.5) }
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
            await auth?.setVolume(intValue)
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
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
            await MainActor.run { self.resetTimer(after: 0.5) }
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

    func toggleLyrics() {
        if showLyrics {
            showLyrics = false
            return
        }
        guard !trackID.isEmpty else { return }
        showLyrics = true
        if lastLyricsTrackID == trackID {
            return
        }
        fetchLyrics()
    }

    private func fetchLyrics() {
        guard !trackName.isEmpty, !artistName.isEmpty else { return }
        isFetchingLyrics = true
        let track = trackName
        let artist = artistName
        let id = trackID

        Task {
            var components = URLComponents(string: "https://lrclib.net/api/get")!
            components.queryItems = [
                URLQueryItem(name: "track_name", value: track),
                URLQueryItem(name: "artist_name", value: artist),
            ]
            var request = URLRequest(url: components.url!)
            request.setValue("Spot/1.0 (https://github.com/joelmoss/spot)", forHTTPHeaderField: "User-Agent")

            let result: String? = await {
                guard let (data, response) = try? await URLSession.shared.data(for: request),
                      let status = (response as? HTTPURLResponse)?.statusCode,
                      status == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return nil }
                // Prefer plain lyrics over synced
                if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
                    return plain
                }
                if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
                    // Strip timestamp tags like [00:12.34]
                    return synced.replacingOccurrences(of: "\\[\\d{2}:\\d{2}\\.\\d{2}\\]\\s?", with: "", options: .regularExpression)
                }
                return nil
            }()

            await MainActor.run {
                guard self.trackID == id else { return }
                self.lyrics = result
                self.lastLyricsTrackID = id
                self.isFetchingLyrics = false
            }
        }
    }

    private func fetchCurrentTrack() {
        guard let auth, auth.isAuthenticated else {
            isSpotifyRunning = false
            updatePollingInterval(for: nil)
            return
        }

        // If rate-limited, skip and schedule next poll for when rate limit expires
        if let until = auth.rateLimitedUntil, Date() < until {
            let delay = until.timeIntervalSinceNow + 0.5
            resetTimer(after: max(1.0, delay))
            return
        }

        Task {
            let state = await auth.getCurrentPlayback()
            await MainActor.run {
                self.applyPlaybackState(state)
                self.updatePollingInterval(for: state)
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
            volume = Double(auth?.getVolume() ?? state.volume)
        }

        let newTrackID = state.trackID
        if newTrackID != trackID {
            trackID = newTrackID
            lyrics = nil
            lastLyricsTrackID = ""
            checkIfLiked()
            if showLyrics {
                fetchLyrics()
            }
        } else if lastCheckedTrackID != trackID {
            checkIfLiked()
        }
    }

    private func updatePollingInterval(for state: PlaybackState?) {
        let newInterval: TimeInterval
        if let state {
            newInterval = state.isPlaying ? Self.playingInterval : Self.pausedInterval
        } else {
            newInterval = Self.inactiveInterval
        }

        if newInterval != currentPollingInterval {
            scheduleTimer(interval: newInterval)
        }
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer?.invalidate()
        currentPollingInterval = interval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.fetchCurrentTrack()
        }
    }

    /// Resets the timer so the next poll fires after `delay` seconds, then resumes normal interval.
    private func resetTimer(after delay: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.fetchCurrentTrack()
            self.scheduleTimer(interval: self.currentPollingInterval)
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
