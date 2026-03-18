import XCTest

@testable import Spot

final class LyricsModelTests: XCTestCase {

    func testParseSyncedLyrics() {
        let raw = """
            [00:12.34] First line
            [00:24.56] Second line
            [01:05.00] Third line
            """
        let lines = LyricsParser.parseSyncedLyrics(raw)

        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines[0].timeMs, 12340)
        XCTAssertEqual(lines[0].text, "First line")
        XCTAssertEqual(lines[1].timeMs, 24560)
        XCTAssertEqual(lines[1].text, "Second line")
        XCTAssertEqual(lines[2].timeMs, 65000)
        XCTAssertEqual(lines[2].text, "Third line")
    }

    func testParseSyncedLyricsSkipsMalformedLines() {
        let raw = """
            [00:05.00] Good line
            This has no timestamp
            [bad] Also bad
            [00:10.00] Another good line
            """
        let lines = LyricsParser.parseSyncedLyrics(raw)

        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "Good line")
        XCTAssertEqual(lines[1].text, "Another good line")
    }

    func testParseSyncedLyricsSkipsEmptyText() {
        let raw = """
            [00:05.00]
            [00:10.00] Has text
            [00:15.00]
            """
        let lines = LyricsParser.parseSyncedLyrics(raw)

        // Empty lines should be skipped, but " " (space) is not empty after trimming in regex
        XCTAssertEqual(lines[0].text, "Has text")
    }

    func testParseEmptyString() {
        let lines = LyricsParser.parseSyncedLyrics("")
        XCTAssertTrue(lines.isEmpty)
    }

    func testCurrentLineIndex() {
        let lines = [
            LyricsLine(timeMs: 0, text: "Intro"),
            LyricsLine(timeMs: 5000, text: "Line 1"),
            LyricsLine(timeMs: 10000, text: "Line 2"),
            LyricsLine(timeMs: 15000, text: "Line 3"),
        ]

        XCTAssertEqual(LyricsParser.currentLineIndex(for: 0, in: lines), 0)
        XCTAssertEqual(LyricsParser.currentLineIndex(for: 3000, in: lines), 0)
        XCTAssertEqual(LyricsParser.currentLineIndex(for: 5000, in: lines), 1)
        XCTAssertEqual(LyricsParser.currentLineIndex(for: 7500, in: lines), 1)
        XCTAssertEqual(LyricsParser.currentLineIndex(for: 10000, in: lines), 2)
        XCTAssertEqual(LyricsParser.currentLineIndex(for: 20000, in: lines), 3)
    }

    func testCurrentLineIndexEmptyLines() {
        let index = LyricsParser.currentLineIndex(for: 5000, in: [])
        XCTAssertEqual(index, 0)
    }

    func testParsedLyricsIsSynced() {
        let synced = ParsedLyrics.synced([LyricsLine(timeMs: 0, text: "Test")])
        XCTAssertTrue(synced.isSynced)

        let plain = ParsedLyrics.plain("Test")
        XCTAssertFalse(plain.isSynced)

        let none = ParsedLyrics.none
        XCTAssertFalse(none.isSynced)
    }
}
