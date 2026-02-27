import XCTest

@testable import Spot

final class MockSpotifyAuth: SpotifyAuthProviding {
    var isAuthenticated: Bool = true
    var checkIfLikedResult: Bool = false
    var saveTrackResult: Bool = true
    var removeTrackResult: Bool = true
    var currentPlayback: PlaybackState?

    func checkIfLiked(trackID: String) async -> Bool {
        checkIfLikedResult
    }

    func saveTrack(trackID: String) async -> Bool {
        saveTrackResult
    }

    func removeTrack(trackID: String) async -> Bool {
        removeTrackResult
    }

    func getCurrentPlayback() async -> PlaybackState? {
        currentPlayback
    }

    func play() async {}
    func pause() async {}
    func nextTrack() async {}
    func previousTrack() async {}
    func setVolume(_ percent: Int) async {}
}

@MainActor
final class SpotifyControllerTests: XCTestCase {

    func testApplyPlaybackState() {
        let controller = SpotifyController()

        let state = PlaybackState(
            trackName: "Song Name",
            artistName: "Artist",
            artworkURL: URL(string: "https://artwork.url/img.jpg"),
            isPlaying: true,
            volume: 75,
            trackID: "6rqhFgbbKwnb9MLmUQDhG6"
        )
        controller.applyPlaybackState(state)

        XCTAssertEqual(controller.trackID, "6rqhFgbbKwnb9MLmUQDhG6")
        XCTAssertEqual(controller.trackName, "Song Name")
        XCTAssertEqual(controller.artistName, "Artist")
        XCTAssertEqual(controller.artworkURL, URL(string: "https://artwork.url/img.jpg"))
        XCTAssertTrue(controller.isPlaying)
        XCTAssertEqual(controller.volume, 75)
        XCTAssertTrue(controller.isSpotifyRunning)
    }

    func testCheckIfLikedCalledOnTrackChange() async throws {
        let controller = SpotifyController()
        let mockAuth = MockSpotifyAuth()
        mockAuth.checkIfLikedResult = true
        controller.auth = mockAuth

        let state = PlaybackState(
            trackName: "Song",
            artistName: "Artist",
            artworkURL: URL(string: "https://img.url"),
            isPlaying: true,
            volume: 50,
            trackID: "abc123"
        )
        controller.applyPlaybackState(state)

        // Allow the async Task spawned by checkIfLiked to complete
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(controller.trackID, "abc123")
        XCTAssertTrue(controller.isLiked)
    }

    func testCheckIfLikedRetryWhenAuthNotReady() async throws {
        let controller = SpotifyController()

        // First call without auth — checkIfLiked fails, lastCheckedTrackID not updated
        let state = PlaybackState(
            trackName: "Song",
            artistName: "Artist",
            artworkURL: URL(string: "https://img.url"),
            isPlaying: true,
            volume: 50,
            trackID: "abc123"
        )
        controller.applyPlaybackState(state)
        XCTAssertFalse(controller.isLiked)

        // Now set auth
        let mockAuth = MockSpotifyAuth()
        mockAuth.checkIfLikedResult = true
        controller.auth = mockAuth

        // Same track — triggers retry because lastCheckedTrackID != trackID
        controller.applyPlaybackState(state)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(controller.isLiked)
    }

    func testToggleLikeOptimisticUpdate() {
        let controller = SpotifyController()
        let mockAuth = MockSpotifyAuth()
        controller.auth = mockAuth
        controller.trackID = "abc123"
        controller.isLiked = false

        controller.toggleLike()

        // isLiked flips immediately (optimistic update)
        XCTAssertTrue(controller.isLiked)
    }

    func testToggleLikeRollbackOnFailure() async throws {
        let controller = SpotifyController()
        let mockAuth = MockSpotifyAuth()
        mockAuth.saveTrackResult = false
        controller.auth = mockAuth
        controller.trackID = "abc123"
        controller.isLiked = false

        controller.toggleLike()

        // Optimistic update
        XCTAssertTrue(controller.isLiked)

        // Wait for the async Task to complete and rollback
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(controller.isLiked)
    }

    func testNilPlaybackClearsState() {
        let controller = SpotifyController()

        // Set some state first
        let state = PlaybackState(
            trackName: "Song",
            artistName: "Artist",
            artworkURL: URL(string: "https://img.url"),
            isPlaying: true,
            volume: 50,
            trackID: "abc123"
        )
        controller.applyPlaybackState(state)
        XCTAssertTrue(controller.isSpotifyRunning)
        XCTAssertEqual(controller.trackID, "abc123")

        // nil should clear everything
        controller.applyPlaybackState(nil)

        XCTAssertFalse(controller.isSpotifyRunning)
        XCTAssertEqual(controller.trackName, "")
        XCTAssertEqual(controller.artistName, "")
        XCTAssertNil(controller.artworkURL)
        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(controller.trackID, "")
        XCTAssertFalse(controller.isLiked)
    }
}
