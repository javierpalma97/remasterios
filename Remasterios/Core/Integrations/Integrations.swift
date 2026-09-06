import Foundation
import AVFoundation
import ShazamKit
import CryptoKit

/// Puerto de lastfm/LastFM.kt + utils/ScrobbleManager.kt
final class LastFMService {
    static let shared = LastFMService()
    private let apiKey = "YOUR_LASTFM_API_KEY"
    private let secret = "YOUR_LASTFM_SECRET"
    private init() {}

    func authURL() -> URL {
        URL(string: "https://www.last.fm/api/auth/?api_key=\(apiKey)")!
    }
    private func sign(_ params: [String: String]) -> String {
        let s = params.sorted { $0.key < $1.key }.map { "\($0.key)\($0.value)" }.joined() + secret
        return Insecure.MD5.hash(data: Data(s.utf8)).map { String(format: "%02hhx", $0) }.joined()
    }
    func scrobble(artist: String, track: String, timestamp: Int) async {
        guard SettingsStore.shared.lastfmEnabled else { return }
        var p = ["method": "track.scrobble", "api_key": apiKey, "artist": artist, "track": track,
                 "timestamp": "\(timestamp)", "sk": SettingsStore.shared.lastfmSessionKey]
        p["api_sig"] = sign(p)
        await post(p)
    }
    func nowPlaying(artist: String, track: String) async {
        guard SettingsStore.shared.lastfmEnabled else { return }
        var p = ["method": "track.updateNowPlaying", "api_key": apiKey, "artist": artist, "track": track,
                 "sk": SettingsStore.shared.lastfmSessionKey]
        p["api_sig"] = sign(p)
        await post(p)
    }
    private func post(_ p: [String: String]) async {
        var req = URLRequest(url: URL(string: "https://ws.audioscrobbler.com/2.0/")!)
        req.httpMethod = "POST"
        req.httpBody = p.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&").data(using: .utf8)
        _ = try? await URLSession.shared.data(for: req)
    }
}

/// Reglas de scrobble: % duración (def 50%), mín 30s, delay 180s.
final class ScrobbleManager {
    static let shared = ScrobbleManager()
    private var startDate: Date?
    private var currentId: String?
    private init() {}
    func nowPlaying(song: SongItem) {
        currentId = song.id; startDate = Date()
        Task { await LastFMService.shared.nowPlaying(artist: song.artistsText, track: song.title) }
    }
    func onProgress(song: SongItem, position: Double) {
        guard song.id == currentId, let start = startDate else { return }
        let elapsed = Date().timeIntervalSince(start)
        let s = SettingsStore.shared
        let playedEnough = position >= song.duration * Double(s.scrobblePercent) / 100
        let longEnough = song.duration >= 30 && elapsed >= 30
        if playedEnough && longEnough {
            Task { await LastFMService.shared.scrobble(artist: song.artistsText, track: song.title, timestamp: Int(Date().timeIntervalSince1970)) }
            currentId = nil
        }
    }
}

// MARK: - Listen Together (listentogether/* + metroserver)
@MainActor
final class ListenTogetherSession: ObservableObject {
    static let shared = ListenTogetherSession()
    @Published var connected = false
    @Published var roomCode = ""
    @Published var isHost = false
    @Published var members: [String] = []
    private var socket: URLSessionWebSocketTask?
    private init() {}

    func createRoom(username: String) {
        roomCode = String((0..<6).map { _ in "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".randomElement()! })
        isHost = true
        connect(username: username)
    }
    func join(room: String, username: String) {
        roomCode = room; isHost = false
        connect(username: username)
    }
    private func connect(username: String) {
        let base = SettingsStore.shared.listenTogetherServer
        guard let url = URL(string: "\(base)/room/\(roomCode)?user=\(username)") else { return }
        socket = URLSession.shared.webSocketTask(with: url)
        socket?.resume()
        connected = true
        listen()
        broadcastState()
    }
    func leave() { socket?.cancel(); socket = nil; connected = false; members = [] }
    func broadcastState() {
        guard connected else { return }
        let p = PlayerService.shared
        let msg: [String: Any] = ["type": "state", "videoId": p.currentSong?.id as Any,
            "position": p.position, "playing": p.isPlaying, "ts": Date().timeIntervalSince1970]
        guard let d = try? JSONSerialization.data(withJSONObject: msg) else { return }
        socket?.send(.data(d)) { _ in }
    }
    private func listen() {
        socket?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                if case .success(let msg) = result {
                    // TODO: aplicar drift-correction + cola/volume sync (ServerClock/Protocol)
                    _ = msg
                }
                self.listen()
            }
        }
    }
}

// MARK: - Traducción IA (DeepL + OpenRouter)
struct TranslationService {
    static func viaDeepL(text: String) async -> String? {
        let s = SettingsStore.shared
        guard !s.deeplKey.isEmpty, let url = URL(string: "https://api-free.deepl.com/v2/translate") else { return nil }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("DeepL-Auth-Key \(s.deeplKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = "text=\(text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&target_lang=\(s.translateLanguage.uppercased())".data(using: .utf8)
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let t = ((json["translations"] as? [[String: Any]])?.first?["text"] as? String) else { return nil }
        return t
    }
    static func viaOpenRouter(lines: [String]) async -> [String]? {
        let s = SettingsStore.shared
        guard !s.openRouterKey.isEmpty, let url = URL(string: "https://openrouter.ai/api/v1/chat/completions") else { return nil }
        var req = URLRequest(url: url); req.httpMethod = "POST"
        req.setValue("Bearer \(s.openRouterKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let prompt = "Translate these lyric lines to \(s.translateLanguage). Reply ONLY JSON {\"lines\":[...]} with same count."
        let body: [String: Any] = ["model": s.openRouterModel, "messages": [["role": "user", "content": "\(prompt)\n\(lines.joined(separator: "\n"))"]]]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = ((json["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String,
              let jd = text.data(using: .utf8),
              let lj = try? JSONSerialization.jsonObject(with: jd) as? [String: Any],
              let out = lj["lines"] as? [String] else { return nil }
        return out
    }
}

// MARK: - Reconocimiento (ShazamKit nativo en iOS reemplaza firma custom)
final class MusicRecognition: NSObject, ObservableObject {
    static let shared = MusicRecognition()
    @Published var listening = false
    @Published var match: SHMatchedMediaItem?
    private let session = SHSession()
    private let audioEngine = AVAudioEngine()
    private override init() { super.init(); session.delegate = self }
    func toggle() { listening ? stop() : start() }
    func start() {
        listening = true
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.session.matchStreamingBuffer(buffer, at: time)
        }
        try? audioEngine.start()
    }
    func stop() {
        audioEngine.stop(); audioEngine.inputNode.removeTap(onBus: 0); listening = false
    }
}
extension MusicRecognition: SHSessionDelegate {
    func session(_ session: SHSession, didFind match: SHMatch) {
        self.match = match.mediaItems.first
        stop()
    }
    func session(_ session: SHSession, didNotFindMatchFor signature: SHSignature, error: Error?) { }
}

// MARK: - SyncEngine (SyncUtils: fullSync likes/uploads/subs/playlists/podcasts)
final class SyncEngine: ObservableObject {
    static let shared = SyncEngine()
    @Published var lastFullSync: Date?
    @Published var syncing = false
    private init() {}
    func fullSync() async {
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }
        // TODO: llamar a InnerTube library/likes/uploads y fusionar en SwiftData
        lastFullSync = Date()
    }
}
