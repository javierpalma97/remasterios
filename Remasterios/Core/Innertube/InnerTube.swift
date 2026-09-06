import Foundation

/// Puerto Swift de innertube/ (InnerTube.kt + YouTube.kt + pages/*).
/// Cliente YouTube Music: search, player, browse, next, playlist, library, charts, etc.
final class InnerTubeClient {
    static let shared = InnerTubeClient()
    private let session = URLSession.shared
    private let base = URL(string: "https://music.youtube.com/youtubei/v1")!
    private let apiKey = "AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30"
    private var visitorData: String { SettingsStore.shared.visitorData }
    private var cookie: String { SettingsStore.shared.innerTubeCookie }

    private init() {}

    // MARK: request genérico
    private func post<T: Decodable>(_ endpoint: String, body: [String: Any]) async throws -> T {
        var req = URLRequest(url: base.appendingPathComponent(endpoint).appendingQueryParameters(["key": apiKey, "prettyPrint": "false"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var ctx = defaultContext()
        body.forEach { ctx[$0.key] = $0.value }
        req.httpBody = try JSONSerialization.data(withJSONObject: ["context": ctx] + body)
        if !cookie.isEmpty { req.setValue(cookie, forHTTPHeaderField: "Cookie") }
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw InnerTubeError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Variante que devuelve JSON crudo (para parseo tolerante de youtubei).
    private func postJSON(_ endpoint: String, body: [String: Any]) async throws -> Any {
        var req = URLRequest(url: base.appendingPathComponent(endpoint).appendingQueryParameters(["key": apiKey, "prettyPrint": "false"]))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var ctx = defaultContext()
        body.forEach { ctx[$0.key] = $0.value }
        req.httpBody = try JSONSerialization.data(withJSONObject: ["context": ctx] + body)
        if !cookie.isEmpty { req.setValue(cookie, forHTTPHeaderField: "Cookie") }
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw InnerTubeError.http((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    private func defaultContext() -> [String: Any] {
        let s = SettingsStore.shared
        return ["client": ["clientName": "WEB_REMIX", "clientVersion": "1.20240101.00",
                           "hl": s.contentLanguage, "gl": s.contentCountry,
                           "visitorData": visitorData.isEmpty ? nil : visitorData as Any],
                "user": [:]] as [String: Any]
    }

    // MARK: Endpoints principales (firmas espejo de YouTube.kt)
    func search(query: String) async throws -> SearchPageDTO { try await post("search", body: ["query": query]) }
    func player(videoId: String, playlistId: String? = nil) async throws -> PlayerDTO {
        try await post("player", body: ["videoId": videoId, "playlistId": playlistId as Any])
    }
    func browse(browseId: String, params: String? = nil) async throws -> BrowseDTO {
        try await post("browse", body: ["browseId": browseId, "params": params as Any])
    }
    func next(videoId: String, playlistId: String? = nil, params: String? = nil) async throws -> NextDTO {
        try await post("next", body: ["videoId": videoId, "playlistId": playlistId as Any, "params": params as Any])
    }
    func getSearchSuggestions(query: String) async throws -> SuggestionsDTO {
        try await post("music/get_search_suggestions", body: ["input": query])
    }

    // Biblioteca / feedback
    func likeVideo(_ videoId: String, like: Bool) async throws { _ = try await feedback(target: videoId, like: like) as EmptyDTO }
    private func feedback(target: String, like: Bool) async throws -> EmptyDTO {
        try await post("feedback", body: ["target": ["videoId": target],
            "feedbackTokens": [like ? "like" : "indifferent"]])
    }
    func subscribe(channelId: String, subscribe: Bool) async throws -> EmptyDTO {
        try await post("subscription/\(subscribe ? "subscribe" : "unsubscribe")", body: ["channelIds": [channelId]])
    }
    func createPlaylist(title: String, description: String? = nil) async throws -> String {
        let dto: CreatePlaylistDTO = try await post("playlist/create", body: ["title": title, "description": description as Any])
        return dto.playlistId
    }
    func addToPlaylist(playlistId: String, videoId: String) async throws -> EmptyDTO {
        try await post("browse/edit_playlist", body: ["playlistId": playlistId, "actions": [["addedVideoId": videoId, "action": "ACTION_ADD_VIDEO"]]])
    }
    func removeFromPlaylist(playlistId: String, setVideoId: String) async throws -> EmptyDTO {
        try await post("browse/edit_playlist", body: ["playlistId": playlistId, "actions": [["setVideoId": setVideoId, "action": "ACTION_REMOVE_VIDEO"]]])
    }

    // MARK: Búsqueda real (parseo tolerante del JSON youtubei → YTSong)
    func searchSongs(query: String) async -> [YTSong] {
        do {
            let json = try await postJSON("search", body: ["query": query])
            let songs = Self.parseSearchSongs(json)
            if !songs.isEmpty { return songs }
        } catch {}
        return []
    }

    /// Navega diccionarios/arrays por claves (los índices numéricos recorren arrays).
    private static func dig(_ obj: Any?, _ keys: String...) -> Any? {
        var cur = obj
        for k in keys {
            if let d = cur as? [String: Any] {
                cur = d[k]
            } else if let i = Int(k), let a = cur as? [Any], a.indices.contains(i) {
                cur = a[i]
            } else {
                return nil
            }
        }
        return cur
    }

    private static func parseDuration(_ s: String) -> Double? {
        let parts = s.split(separator: ":").compactMap { Double($0) }
        if parts.count == 2 { return parts[0] * 60 + parts[1] }
        if parts.count == 3 { return parts[0] * 3600 + parts[1] * 60 + parts[2] }
        return nil
    }

    static func parseSearchSongs(_ json: Any) -> [YTSong] {
        guard let contents = (json as? [String: Any])?["contents"] as? [String: Any],
              let tabbed = contents["tabbedSearchResultsRenderer"] as? [String: Any],
              let tabs = tabbed["tabs"] as? [[String: Any]] else { return [] }
        var out: [YTSong] = []
        for tab in tabs {
            guard let content = dig(tab, "tabRenderer", "content") as? [String: Any],
                  let sections = dig(content, "sectionListRenderer", "contents") as? [[String: Any]] else { continue }
            for section in sections {
                var shelves: [[String: Any]] = []
                if let s = section["musicShelfRenderer"] as? [String: Any] { shelves.append(s) }
                if let itemSec = section["itemSectionRenderer"] as? [String: Any],
                   let arr = itemSec["contents"] as? [[String: Any]] {
                    for c in arr {
                        if let s = c["musicShelfRenderer"] as? [String: Any] { shelves.append(s) }
                    }
                }
                for shelf in shelves {
                    guard let items = shelf["contents"] as? [[String: Any]] else { continue }
                    for item in items {
                        if let r = item["musicResponsiveListItemRenderer"] as? [String: Any],
                           let song = parseListItem(r) {
                            out.append(song)
                        }
                    }
                }
            }
        }
        return out
    }

    private static func columnText(_ col: [String: Any]?) -> (String, [[String: Any]]) {
        guard let t = dig(col ?? [:], "musicResponsiveListItemFlexColumnRenderer", "text") as? [String: Any] else {
            return ("", [])
        }
        let runs = t["runs"] as? [[String: Any]] ?? []
        let text = runs.compactMap { $0["text"] as? String }.joined()
        return (text, runs)
    }

    private static func parseListItem(_ r: [String: Any]) -> YTSong? {
        let videoId = (dig(r, "overlay", "musicItemThumbnailOverlayRenderer", "content",
                           "musicPlayButtonRenderer", "playNavigationEndpoint",
                           "watchEndpoint", "videoId") as? String)
            ?? (dig(r, "playlistItemData", "videoId") as? String)
        guard let id = videoId, !id.isEmpty else { return nil }
        guard let flex = r["flexColumns"] as? [[String: Any]], !flex.isEmpty else { return nil }
        let (title, _) = columnText(flex[0])
        guard !title.isEmpty else { return nil }

        var artists: [YTArtistRef] = []
        var album: YTAlbumRef? = nil
        var duration: Double? = nil
        if flex.count > 1 {
            let (_, runs) = columnText(flex[1])
            for run in runs {
                let text = (run["text"] as? String) ?? ""
                if text.isEmpty || text == " • " { continue }
                if let d = parseDuration(text) { duration = d; continue }
                let browseId = dig(run, "navigationEndpoint", "browseEndpoint", "browseId") as? String
                if let b = browseId, !b.isEmpty {
                    if b.hasPrefix("MPREb_") { album = YTAlbumRef(id: b, name: text) }
                    else { artists.append(YTArtistRef(id: b, name: text)) }
                } else if artists.isEmpty && text.rangeOfCharacter(from: .decimalDigits) == nil {
                    artists.append(YTArtistRef(id: nil, name: text))
                }
            }
        }

        let thumbsRaw = dig(r, "thumbnail", "musicThumbnailRenderer", "thumbnail", "thumbnails") as? [[String: Any]] ?? []
        let thumbs = thumbsRaw.compactMap { d -> YTThumb? in
            guard let url = d["url"] as? String else { return nil }
            return YTThumb(url: url, width: d["width"] as? Int, height: d["height"] as? Int)
        }
        let badges = r["badges"] as? [[String: Any]] ?? []
        let explicit = badges.contains {
            (dig($0, "musicInlineBadgeRenderer", "icon", "iconType") as? String) == "MUSIC_EXPLICIT_BADGE"
        }
        return YTSong(id: id, title: title, artists: artists, album: album,
                      duration: duration, thumbnails: thumbs, explicit: explicit)
    }
}

enum InnerTubeError: Error { case http(Int), decode, noStream }

// DTOs mínimos (el parseo completo de pages/* se mapea a YTSong/HomeSection en capa repo)
struct EmptyDTO: Codable {}
struct SearchPageDTO: Codable { var contents: [String: String]? }
struct PlayerDTO: Codable {
    var playabilityStatus: [String: String]?
    var streamingData: StreamingData?
    struct StreamingData: Codable {
        var adaptiveFormats: [AudioFormat]?
        struct AudioFormat: Codable { var url: String?; var itag: Int?; var bitrate: Int?; var loudnessDb: Double? }
    }
}
struct BrowseDTO: Codable { var contents: [String: String]? }
struct NextDTO: Codable { var contents: [String: String]? }
struct SuggestionsDTO: Codable { var contents: [String: String]? }
struct CreatePlaylistDTO: Codable { var playlistId: String }

private extension URL {
    func appendingQueryParameters(_ p: [String: String]) -> URL {
        var c = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        c.queryItems = p.map { URLQueryItem(name: $0.key, value: $0.value) }
        return c.url ?? self
    }
}

private func + (lhs: [String: Any], rhs: [String: Any]) -> [String: Any] {
    var m = lhs; rhs.forEach { m[$0.key] = $0.value }; return m
}

// MARK: - Repositorio de alto nivel (mapea DTO → YTSong/HomeSection, con demo offline)
final class MusicRepository {
    static let shared = MusicRepository()
    private init() {}
    func homeSections() async -> [HomeSection] {
        // TODO: parseo real de HomePage; de momento demo + lo que llegue de API
        do {
            _ = try await InnerTubeClient.shared.browse(browseId: "FEmusic_home")
        } catch {}
        return DemoData.home
    }
    func search(query: String) async -> [YTSong] {
        if query.isEmpty { return [] }
        let live = await InnerTubeClient.shared.searchSongs(query: query)
        if !live.isEmpty { return live }
        return DemoData.songs.filter { $0.title.localizedCaseInsensitiveContains(query) || query.count < 2 }
    }
    func streamURL(for videoId: String) async throws -> URL {
        let dto = try await InnerTubeClient.shared.player(videoId: videoId)
        guard let u = dto.streamingData?.adaptiveFormats?.compactMap({ $0.url }).first, let url = URL(string: u) else {
            throw InnerTubeError.noStream
        }
        return url
    }
}

// MARK: - Datos demo (para compilar/probar sin red, como QuickPicks)
enum DemoData {
    static let songs: [YTSong] = [
        YTSong(id: "dQw4w9WgXcQ", title: "Demo Song One", artists: [.init(id: "a1", name: "Demo Artist")], album: .init(id: "al1", name: "Demo Album"), duration: 213, thumbnails: [.init(url: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg")], explicit: false),
        YTSong(id: "9bZkp7q19f0", title: "Demo Song Two", artists: [.init(id: "a2", name: "Second Artist")], album: nil, duration: 187, thumbnails: [], explicit: false),
    ]
    static let home: [HomeSection] = [
        HomeSection(title: "Quick picks", songs: songs, playlists: []),
        HomeSection(title: "Forgotten favorites", songs: songs, playlists: []),
    ]
}
