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
    var parsedLyrics: ParsedLyrics = .none
    var showLyricsOverlay: Bool = false
    var isFetchingLyrics: Bool = false
    var currentLineIndex: Int = 0
    var progressMs: Int = 0
    var durationMs: Int = 0
    var auth: (any SpotifyAuthProviding)?
    private var timer: Timer?
    private var progressTimer: Timer?
    private var lastProgressUpdate: Date = Date()
    private var isSettingVolume = false
    private var volumeDebounceTask: Task<Void, Never>?
    private var lastCheckedTrackID: String = ""
    private var lastLyricsTrackID: String = ""
    private var currentPollingInterval: TimeInterval = 5.0

    private static let playingInterval: TimeInterval = 5.0
    private static let lyricsPlayingInterval: TimeInterval = 3.0
    private static let pausedInterval: TimeInterval = 15.0
    private static let inactiveInterval: TimeInterval = 30.0

    func startPolling() {
        fetchCurrentTrack()
        scheduleTimer(interval: Self.playingInterval)
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        stopProgressTimer()
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
        if showLyricsOverlay {
            showLyricsOverlay = false
            stopProgressTimer()
            return
        }
        guard !trackID.isEmpty else { return }
        showLyricsOverlay = true
        if isPlaying {
            startProgressTimer()
        }
        if lastLyricsTrackID == trackID {
            return
        }
        fetchLyrics()
    }

    // MARK: - Progress Tracking

    func startProgressTimer() {
        stopProgressTimer()
        lastProgressUpdate = Date()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = Date()
            let elapsed = Int(now.timeIntervalSince(self.lastProgressUpdate) * 1000)
            self.lastProgressUpdate = now
            if self.isPlaying {
                self.progressMs += elapsed
                self.updateCurrentLine()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    /// Lookahead offset so the line appears slightly before its timestamp,
    /// compensating for API latency and animation duration.
    static let lyricsLookaheadMs = 400

    private func updateCurrentLine() {
        guard case .synced(let lines) = parsedLyrics, !lines.isEmpty else { return }
        let newIndex = LyricsParser.currentLineIndex(for: progressMs + Self.lyricsLookaheadMs, in: lines)
        if newIndex != currentLineIndex {
            currentLineIndex = newIndex
        }
    }

    // MARK: - Lyrics Fetching

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

            let result: ParsedLyrics = await {
                guard let (data, response) = try? await URLSession.shared.data(for: request),
                      let status = (response as? HTTPURLResponse)?.statusCode,
                      status == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else { return .none }
                // Prefer synced lyrics for line-by-line highlighting
                if let synced = json["syncedLyrics"] as? String, !synced.isEmpty {
                    let lines = LyricsParser.parseSyncedLyrics(synced)
                    if !lines.isEmpty {
                        return .synced(lines)
                    }
                }
                if let plain = json["plainLyrics"] as? String, !plain.isEmpty {
                    return .plain(plain)
                }
                return .none
            }()

            await MainActor.run {
                guard self.trackID == id else { return }
                self.parsedLyrics = result
                self.lastLyricsTrackID = id
                self.isFetchingLyrics = false
                self.currentLineIndex = 0
                self.updateCurrentLine()
            }
        }
    }

    // MARK: - Playback Polling

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
            progressMs = 0
            durationMs = 0
            return
        }

        isSpotifyRunning = true
        hasCheckedPlayback = true
        trackName = state.trackName
        artistName = state.artistName
        artworkURL = state.artworkURL
        isPlaying = state.isPlaying
        supportsVolume = state.supportsVolume
        progressMs = state.progressMs
        durationMs = state.durationMs
        lastProgressUpdate = Date()
        if !isSettingVolume {
            volume = Double(auth?.getVolume() ?? state.volume)
        }

        // Manage progress timer based on play state and overlay visibility
        if showLyricsOverlay && isPlaying {
            if progressTimer == nil {
                startProgressTimer()
            }
        } else {
            stopProgressTimer()
        }

        let newTrackID = state.trackID
        if newTrackID != trackID {
            trackID = newTrackID
            parsedLyrics = .none
            lastLyricsTrackID = ""
            currentLineIndex = 0
            checkIfLiked()
            if showLyricsOverlay {
                fetchLyrics()
            }
        } else if lastCheckedTrackID != trackID {
            checkIfLiked()
        }

        updateCurrentLine()
    }

    private func updatePollingInterval(for state: PlaybackState?) {
        let newInterval: TimeInterval
        if let state {
            if showLyricsOverlay && state.isPlaying {
                newInterval = Self.lyricsPlayingInterval
            } else {
                newInterval = state.isPlaying ? Self.playingInterval : Self.pausedInterval
            }
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
