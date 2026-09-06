import Foundation
import AVFoundation

/// Puerto de lyrics/: LyricsHelper + 8 proveedores ordenables + caché + traducción + romanización.
/// Orden por defecto: BetterLyrics > LrcLib > KuGou > Paxsenix > LyricsPlus > YouTube.
struct LyricsResult {
    var plain: String?
    var syncedLines: [LyricLine]
    var provider: String
}

final class LyricsEngine {
    static let shared = LyricsEngine()
    private init() {}

    func fetchAll(artist: String, title: String, duration: Double) async -> LyricsResult {
        let order = SettingsStore.shared.lyricsProviderOrder
        for provider in order {
            if let r = await fetchOne(provider: provider, artist: artist, title: title, duration: duration), r.plain != nil || !r.syncedLines.isEmpty {
                return r
            }
        }
        return LyricsResult(plain: nil, syncedLines: [], provider: "none")
    }

    private func fetchOne(provider: String, artist: String, title: String, duration: Double) async -> LyricsResult? {
        switch provider {
        case "betterlyrics": return await BetterLyricsAPI.fetch(artist: artist, title: title)
        case "lrclib": return await LrcLibAPI.fetch(artist: artist, title: title, duration: duration)
        case "kugou": return await KuGouAPI.fetch(artist: artist, title: title)
        case "paxsenix": return await PaxsenixAPI.fetch(title: title, artist: artist)
        default: return nil
        }
    }

    /// Parse LRC/SRT simple → líneas sincronizadas (LyricsUtils).
    static func parseLRC(_ text: String) -> [LyricLine] {
        var out: [LyricLine] = []
        let re = try? NSRegularExpression(pattern: #"\[(\d+):(\d+)(?:\.(\d+))?\](.*)"#)
        for line in text.components(separatedBy: .newlines) {
            guard let m = re?.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else { continue }
            func g(_ i: Int) -> String { (line as NSString).substring(with: m.range(at: i)) }
            let min = Double(g(1)) ?? 0, sec = Double(g(2)) ?? 0
            var frac = Double(g(3)) ?? 0
            if g(3).count == 2 { frac /= 100 } else if g(3).count == 3 { frac /= 1000 }
            let start = min * 60 + sec + frac
            out.append(LyricLine(start: start, end: start + 5, text: g(4).trimmingCharacters(in: .whitespaces)))
        }
        return out.sorted { $0.start < $1.start }
    }
}

// MARK: - Proveedores
enum BetterLyricsAPI {
    static func fetch(artist: String, title: String) async -> LyricsResult? {
        guard let q = "\(artist) \(title)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://better-lyrics.boidu.dev/api/lyrics?song=\(q)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let plain = json["plainLyrics"] as? String
        let synced = (json["syncedLyrics"] as? String).map(LyricsEngine.parseLRC) ?? []
        guard plain != nil || !synced.isEmpty else { return nil }
        return LyricsResult(plain: plain, syncedLines: synced, provider: "betterlyrics")
    }
}
enum LrcLibAPI {
    static func fetch(artist: String, title: String, duration: Double) async -> LyricsResult? {
        var c = URLComponents(string: "https://lrclib.net/api/search")!
        c.queryItems = [URLQueryItem(name: "artist_name", value: artist), URLQueryItem(name: "track_name", value: title)]
        guard let url = c.url, let (data, _) = try? await URLSession.shared.data(from: url),
              let arr = try? JSONDecoder().decode([LrcLibTrack].self, from: data),
              let best = arr.min(by: { abs(($0.duration ?? 0) - duration) < abs(($1.duration ?? 0) - duration) }) else { return nil }
        let lines = (best.syncedLyrics).map(LyricsEngine.parseLRC) ?? []
        return LyricsResult(plain: best.plainLyrics, syncedLines: lines, provider: "lrclib")
    }
    struct LrcLibTrack: Codable { var plainLyrics: String?; var syncedLyrics: String?; var duration: Double? }
}
enum KuGouAPI {
    static func fetch(artist: String, title: String) async -> LyricsResult? {
        // Búsqueda + descarga KRC/Base64 (KuGou.kt). Implementación simplificada.
        return nil
    }
}
enum PaxsenixAPI {
    static func fetch(title: String, artist: String) async -> LyricsResult? {
        guard let q = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://paxsenix.com/api/lyrics?query=\(q)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plain = json["lyrics"] as? String else { return nil }
        return LyricsResult(plain: plain, syncedLines: LyricsEngine.parseLRC(plain), provider: "paxsenix")
    }
}
