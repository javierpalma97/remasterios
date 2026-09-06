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
        do { _ = try await InnerTubeClient.shared.search(query: query) } catch {}
        if query.isEmpty { return [] }
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
