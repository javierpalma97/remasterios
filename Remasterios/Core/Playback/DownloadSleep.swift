import Foundation
import AVFoundation

/// Puerto de DownloadUtil + ExoDownloadService + caché LRU + CachePlaylist.
/// Descarga offline con URLSession + gestión de cuota (MaxSongCacheSize).
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    @Published var downloading: Set<String> = []
    @Published var progress: [String: Double] = [:]
    private init() {}

    var baseDir: URL {
        let u = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("offline")
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    func localFile(for videoId: String) -> URL? {
        let f = baseDir.appendingPathComponent("\(videoId).m4a")
        return FileManager.default.fileExists(atPath: f.path) ? f : nil
    }

    func download(song: SongItem) async {
        guard !downloading.contains(song.id) else { return }
        downloading.insert(song.id)
        do {
            let url = try await MusicRepository.shared.streamURL(for: song.id)
            let (tmp, _) = try await URLSession.shared.download(from: url)
            let dest = baseDir.appendingPathComponent("\(song.id).m4a")
            if FileManager.default.fileExists(atPath: dest.path) { try? FileManager.default.removeItem(at: dest) }
            try FileManager.default.moveItem(at: tmp, to: dest)
            enforceQuota()
        } catch { }
        downloading.remove(song.id)
    }

    func remove(videoId: String) {
        try? FileManager.default.removeItem(at: baseDir.appendingPathComponent("\(videoId).m4a"))
    }

    private func fileSize(of url: URL) -> Int {
        let keys: Set<URLResourceKey> = [.fileSizeKey]
        return (try? url.resourceValues(forKeys: keys))?.fileSize ?? 0
    }

    private func modDate(of url: URL) -> Date {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        return (try? url.resourceValues(forKeys: keys))?.contentModificationDate ?? Date.distantPast
    }

    /// LRU según MaxSongCacheSize (MB). -1 = ilimitado en Android; aquí 0 = ilimitado.
    func enforceQuota() {
        let maxMB = SettingsStore.shared.maxSongCacheMB
        guard maxMB > 0 else { return }
        guard let files = try? FileManager.default.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey]) else { return }
        var total: Int = files.reduce(0) { $0 + fileSize(of: $1) }
        let limit = maxMB * 1024 * 1024
        let sorted = files.sorted { modDate(of: $0) < modDate(of: $1) }
        for f in sorted where total > limit {
            let size = fileSize(of: f)
            try? FileManager.default.removeItem(at: f)
            total -= size
        }
    }

    func cacheSizeMB() -> Double {
        guard let files = try? FileManager.default.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        let bytes: Int = files.reduce(0) { $0 + fileSize(of: $1) }
        return Double(bytes) / 1024 / 1024
    }
    func clearAll() {
        try? FileManager.default.removeItem(at: baseDir)
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
    }
}

// MARK: - SleepTimer + Alarm (playback/alarm/)
@MainActor
final class SleepTimerManager: ObservableObject {
    static let shared = SleepTimerManager()
    @Published var minutesLeft: Int?
    @Published var stopAfterCurrentSong = false
    private var timer: Timer?
    private init() {}

    func start(minutes: Int, stopAfterSong: Bool = false) {
        cancel()
        minutesLeft = minutes
        stopAfterCurrentSong = stopAfterSong
        PlayerService.shared.sleepMinutesLeft = minutes
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                guard let m = self.minutesLeft else { return }
                if m <= 1 {
                    if self.stopAfterCurrentSong {
                        // Se pausará al cambiar de canción (lo comprueba PlayerView)
                    } else {
                        PlayerService.shared.pause()
                    }
                    self.cancel()
                } else {
                    self.minutesLeft = m - 1
                    PlayerService.shared.sleepMinutesLeft = m - 1
                }
            }
        }
    }
    func cancel() {
        timer?.invalidate(); timer = nil
        minutesLeft = nil
        PlayerService.shared.sleepMinutesLeft = nil
    }
}

struct AlarmEntry: Codable, Hashable {
    var hour: Int; var minute: Int; var playlistId: String?; var randomSong: Bool
}
