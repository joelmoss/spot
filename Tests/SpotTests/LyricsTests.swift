import XCTest

@testable import Spot

@MainActor
final class LyricsTests: XCTestCase {

    func testToggleLyricsOpensOverlay() {
        let controller = SpotifyController()
        controller.trackID = "abc123"

        controller.toggleLyrics()

        XCTAssertTrue(controller.showLyricsOverlay)
    }

    func testToggleLyricsClosesOverlay() {
        let controller = SpotifyController()
        controller.trackID = "abc123"
        controller.showLyricsOverlay = true

        controller.toggleLyrics()

        XCTAssertFalse(controller.showLyricsOverlay)
    }

    func testToggleLyricsRequiresTrackID() {
        let controller = SpotifyController()
        controller.trackID = ""

        controller.toggleLyrics()

        XCTAssertFalse(controller.showLyricsOverlay)
    }

    func testTrackChangeResetsParsedLyrics() {
        let controller = SpotifyController()
        let mockAuth = MockSpotifyAuth()
        controller.auth = mockAuth

        // Set initial track
        let state1 = PlaybackState(
            trackName: "Song 1", artistName: "Artist", artworkURL: nil,
            isPlaying: true, volume: 50, trackID: "track1", supportsVolume: true,
            progressMs: 0, durationMs: 200000
        )
        controller.applyPlaybackState(state1)

        // Simulate having lyrics loaded
        controller.currentLineIndex = 5

        // Change track
        let state2 = PlaybackState(
            trackName: "Song 2", artistName: "Artist", artworkURL: nil,
            isPlaying: true, volume: 50, trackID: "track2", supportsVolume: true,
            progressMs: 0, durationMs: 180000
        )
        controller.applyPlaybackState(state2)

        XCTAssertEqual(controller.currentLineIndex, 0)
        if case .none = controller.parsedLyrics {} else {
            XCTFail("Expected parsedLyrics to be .none after track change")
        }
    }

    func testApplyPlaybackStateUpdatesProgress() {
        let controller = SpotifyController()
        let mockAuth = MockSpotifyAuth()
        controller.auth = mockAuth

        let state = PlaybackState(
            trackName: "Song", artistName: "Artist", artworkURL: nil,
            isPlaying: true, volume: 50, trackID: "abc", supportsVolume: true,
            progressMs: 45000, durationMs: 200000
        )
        controller.applyPlaybackState(state)

        XCTAssertEqual(controller.progressMs, 45000)
        XCTAssertEqual(controller.durationMs, 200000)
    }

    func testLookaheadAdvancesCurrentLine() {
        let controller = SpotifyController()
        let mockAuth = MockSpotifyAuth()
        controller.auth = mockAuth

        // Set track ID first so applyPlaybackState doesn't treat it as a track change
        controller.trackID = "track1"

        // Set up synced lyrics with a line at 5000ms
        let lines: [LyricsLine] = [
            LyricsLine(timeMs: 0, text: "Line 1"),
            LyricsLine(timeMs: 5000, text: "Line 2"),
            LyricsLine(timeMs: 10000, text: "Line 3"),
        ]
        controller.parsedLyrics = .synced(lines)
        controller.currentLineIndex = 0

        // Progress at 4700ms — before line 2's 5000ms timestamp
        // but within 400ms lookahead, so line 2 should be active
        let progressMs = 5000 - SpotifyController.lyricsLookaheadMs + 100

        let state = PlaybackState(
            trackName: "Song", artistName: "Artist", artworkURL: nil,
            isPlaying: true, volume: 50, trackID: "track1", supportsVolume: true,
            progressMs: progressMs, durationMs: 30000
        )
        controller.applyPlaybackState(state)

        XCTAssertEqual(controller.currentLineIndex, 1,
            "Lookahead should advance to line 2 before its timestamp. "
            + "progressMs=\(controller.progressMs), lookahead=\(SpotifyController.lyricsLookaheadMs)")
    }

    func testNilPlaybackClearsProgress() {
        let controller = SpotifyController()

        let state = PlaybackState(
            trackName: "Song", artistName: "Artist", artworkURL: nil,
            isPlaying: true, volume: 50, trackID: "abc", supportsVolume: true,
            progressMs: 45000, durationMs: 200000
        )
        controller.applyPlaybackState(state)
        controller.applyPlaybackState(nil)

        XCTAssertEqual(controller.progressMs, 0)
        XCTAssertEqual(controller.durationMs, 0)
    }
}
