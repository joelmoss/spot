import Foundation

struct LyricsLine: Identifiable {
    let id = UUID()
    let timeMs: Int
    let text: String
}

enum ParsedLyrics {
    case synced([LyricsLine])
    case plain(String)
    case none

    var isSynced: Bool {
        if case .synced = self { return true }
        return false
    }
}

enum LyricsParser {
    private static let regex = try! NSRegularExpression(
        pattern: #"^\[(\d{2}):(\d{2})\.(\d{2})\]\s?(.*)"#
    )

    static func parseSyncedLyrics(_ raw: String) -> [LyricsLine] {
        var lines: [LyricsLine] = []
        for rawLine in raw.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            let nsRange = NSRange(trimmed.startIndex..., in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, range: nsRange) else { continue }

            guard let minRange = Range(match.range(at: 1), in: trimmed),
                  let secRange = Range(match.range(at: 2), in: trimmed),
                  let csRange = Range(match.range(at: 3), in: trimmed),
                  let textRange = Range(match.range(at: 4), in: trimmed)
            else { continue }

            let minutes = Int(trimmed[minRange]) ?? 0
            let seconds = Int(trimmed[secRange]) ?? 0
            let centiseconds = Int(trimmed[csRange]) ?? 0
            let timeMs = (minutes * 60 + seconds) * 1000 + centiseconds * 10
            let text = String(trimmed[textRange])
            if !text.isEmpty {
                lines.append(LyricsLine(timeMs: timeMs, text: text))
            }
        }
        return lines
    }

    static func currentLineIndex(for progressMs: Int, in lines: [LyricsLine]) -> Int {
        var index = 0
        for (i, line) in lines.enumerated() {
            if line.timeMs <= progressMs {
                index = i
            } else {
                break
            }
        }
        return index
    }
}
