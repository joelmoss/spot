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
    private var timer: Timer?
    private var isSettingVolume = false

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
        runAppleScript("tell application \"Spotify\" to next track")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.fetchCurrentTrack()
        }
    }

    func previousTrack() {
        runAppleScript("tell application \"Spotify\" to previous track")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.fetchCurrentTrack()
        }
    }

    func setVolume(_ value: Double) {
        isSettingVolume = true
        volume = value
        runAppleScript("tell application \"Spotify\" to set sound volume to \(Int(value))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.isSettingVolume = false
        }
    }

    func togglePlayPause() {
        runAppleScript("tell application \"Spotify\" to playpause")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.fetchCurrentTrack()
        }
    }

    private func fetchCurrentTrack() {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackArtwork to artwork url of current track
                set playerState to player state as string
                set vol to sound volume
                return trackName & "|||" & trackArtist & "|||" & trackArtwork & "|||" & playerState & "|||" & vol
            end tell
        else
            return "NOT_RUNNING"
        end if
        """

        guard let result = runAppleScript(script) else {
            isSpotifyRunning = false
            return
        }

        if result == "NOT_RUNNING" {
            isSpotifyRunning = false
            trackName = ""
            artistName = ""
            artworkURL = nil
            isPlaying = false
            return
        }

        let parts = result.components(separatedBy: "|||")
        guard parts.count >= 5 else { return }

        isSpotifyRunning = true
        trackName = parts[0]
        artistName = parts[1]
        artworkURL = URL(string: parts[2])
        isPlaying = parts[3] == "playing"
        if !isSettingVolume, let vol = Double(parts[4].trimmingCharacters(in: .whitespaces)) {
            volume = vol
        }
    }

    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        let script = NSAppleScript(source: source)
        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        if let error = error {
            print("AppleScript error: \(error)")
            return nil
        }
        return result?.stringValue
    }
}
