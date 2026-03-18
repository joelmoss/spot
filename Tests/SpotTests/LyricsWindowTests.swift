import XCTest
import AppKit

@testable import Spot

@MainActor
final class LyricsWindowTests: XCTestCase {

    func testLyricsWindowCanBecomeKey() {
        let window = LyricsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        XCTAssertTrue(window.canBecomeKey)
    }

    func testSendKeyDownEventCallsOnKeyDown() {
        let window = LyricsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        var called = false
        window.onKeyDown = { called = true }

        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        )!

        window.sendEvent(event)
        XCTAssertTrue(called)
    }

    func testMouseEventDoesNotCallOnKeyDown() {
        let window = LyricsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        var called = false
        window.onKeyDown = { called = true }

        let event = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 50, y: 50),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: window.windowNumber,
            context: nil,
            eventNumber: 0,
            clickCount: 1,
            pressure: 1.0
        )!

        window.sendEvent(event)
        XCTAssertFalse(called)
    }

    // MARK: - End-to-end: real key event dismisses overlay
    // NOTE: This test cannot pass in the XCTest runner because the test process
    // cannot become an active app (isActive=false) even with .regular policy.
    // The real app CAN activate. Manual verification required.

    // MARK: - Activation policy management

    func testShowOverlaySwitchesToRegularPolicy() {
        let appDelegate = AppDelegate()
        let spotify = SpotifyController()
        appDelegate.spotify = spotify

        appDelegate.showLyricsOverlay(spotify: spotify)

        XCTAssertEqual(NSApp.activationPolicy(), .regular,
            "Should switch to .regular so window can become key")

        appDelegate.dismissLyricsOverlay()
    }

    func testDismissRestoresAccessoryPolicy() {
        let appDelegate = AppDelegate()
        let spotify = SpotifyController()
        appDelegate.spotify = spotify

        appDelegate.showLyricsOverlay(spotify: spotify)
        appDelegate.dismissLyricsOverlay()

        XCTAssertEqual(NSApp.activationPolicy(), .accessory,
            "Should restore .accessory (LSUIElement) after dismiss")
    }

    // MARK: - AppDelegate lifecycle

    func testShowInstallsLocalMonitor() {
        let appDelegate = AppDelegate()
        let spotify = SpotifyController()
        appDelegate.spotify = spotify

        appDelegate.showLyricsOverlay(spotify: spotify)

        XCTAssertNotNil(appDelegate.lyricsLocalMonitor)

        appDelegate.dismissLyricsOverlay()
    }

    func testDismissCleansUp() {
        let appDelegate = AppDelegate()
        let spotify = SpotifyController()
        appDelegate.spotify = spotify
        spotify.showLyricsOverlay = true

        appDelegate.showLyricsOverlay(spotify: spotify)
        appDelegate.dismissLyricsOverlay()

        XCTAssertNil(appDelegate.lyricsWindow)
        XCTAssertNil(appDelegate.lyricsLocalMonitor)
        XCTAssertFalse(spotify.showLyricsOverlay)
    }

    func testDismissKeepsPlayerWindowVisible() async throws {
        let appDelegate = AppDelegate()
        let spotify = SpotifyController()
        appDelegate.spotify = spotify

        // Create a fake player window simulating the mini player
        let playerWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 220, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        playerWindow.level = .floating
        playerWindow.orderFront(nil)
        appDelegate.playerWindow = playerWindow

        XCTAssertTrue(playerWindow.isVisible, "Player window should be visible before overlay")

        // Show and dismiss the overlay
        appDelegate.showLyricsOverlay(spotify: spotify)
        try await Task.sleep(nanoseconds: 100_000_000)

        appDelegate.dismissLyricsOverlay()

        // Wait long enough for any async policy changes to take effect
        try await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(playerWindow.isVisible,
            "Player window must remain visible after lyrics overlay dismisses. "
            + "activationPolicy=\(NSApp.activationPolicy().rawValue)")

        playerWindow.orderOut(nil)
    }

    func testDismissRestoresToAccessoryNotProhibited() {
        let appDelegate = AppDelegate()
        let spotify = SpotifyController()
        appDelegate.spotify = spotify

        appDelegate.showLyricsOverlay(spotify: spotify)
        XCTAssertEqual(NSApp.activationPolicy(), .regular)

        appDelegate.dismissLyricsOverlay()

        // LSUIElement maps to .accessory, NOT .prohibited
        // .prohibited forcefully hides all windows
        XCTAssertEqual(NSApp.activationPolicy(), .accessory,
            "Must restore to .accessory (LSUIElement), not .prohibited which hides windows")
    }

    func testDoubleShowDoesNotCreateSecondWindow() {
        let appDelegate = AppDelegate()
        let spotify = SpotifyController()
        appDelegate.spotify = spotify

        appDelegate.showLyricsOverlay(spotify: spotify)
        let firstWindow = appDelegate.lyricsWindow

        appDelegate.showLyricsOverlay(spotify: spotify)

        XCTAssertTrue(firstWindow === appDelegate.lyricsWindow)

        appDelegate.dismissLyricsOverlay()
    }
}
