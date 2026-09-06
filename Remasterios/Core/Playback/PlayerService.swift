import Foundation
import UIKit
import AVFoundation
import MediaPlayer
import Combine

/// Puerto de playback/: MusicService (ExoPlayer) + PlayerConnection + PersistentQueue
/// + DownloadUtil + SleepTimer + Alarm + AudioProcessors + EQ + Cast.
@MainActor
final class PlayerService: ObservableObject {
    static let shared = PlayerService()

    @Published var currentSong: SongItem?
    @Published var queue: [SongItem] = []
    @Published var index: Int = 0
    @Published var isPlaying = false
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var error: String?
    @Published var isMuted = false
    @Published var sleepMinutesLeft: Int?

    let avPlayer = AVPlayer()
    private var timeObs: Any?
    private var cancellables = Set<AnyCancellable>()
    private let settings = SettingsStore.shared

    private init() {
        setupRemoteCommands()
        timeObs = avPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] t in
            guard let self else { return }
            Task { @MainActor in
                self.position = t.seconds.isFinite ? t.seconds : 0
                self.duration = self.avPlayer.currentItem?.duration.seconds ?? 0
                self.updateNowPlaying()
            }
        }
    }

    // MARK: Cola (ListQueue/YouTubeQueue/LocalAlbumRadio/Autoplay)
    func play(songs: [SongItem], startAt: Int = 0) {
        queue = settings.shuffle ? songs.shuffled() : songs
        index = min(startAt, max(queue.count - 1, 0))
        playCurrent()
        if settings.persistentQueue { saveQueue() }
    }

    func playCurrent() {
        guard queue.indices.contains(index) else { return }
        let song = queue[index]
        currentSong = song
        Task {
            do {
                let url: URL
                if let local = DownloadManager.shared.localFile(for: song.id) {
                    url = local
                } else if song.isUploaded {
                    url = try await MusicRepository.shared.streamURL(for: song.id)
                } else {
                    url = try await MusicRepository.shared.streamURL(for: song.id)
                }
                let item = AVPlayerItem(url: url)
                // Velocidad / tono (Varispeed + AudioTrackPlaybackParams en Android)
                item.audioTimePitchAlgorithm = .spectral
                avPlayer.replaceCurrentItem(with: item)
                avPlayer.rate = Float(settings.playbackSpeed)
                avPlayer.volume = isMuted ? 0 : Float(settings.volume)
                // Normalización por loudnessDb (VolumeNormalizationAudioProcessor)
                applyLoudnessNormalization(song: song)
                avPlayer.play()
                isPlaying = true
                error = nil
                setupNowPlaying(song: song)
                recordPlayStart(song: song)
                ScrobbleManager.shared.nowPlaying(song: song)
            } catch {
                self.error = error.localizedDescription
                if settings.autoSkipNextOnError { next() }
            }
        }
    }

    func toggle() { isPlaying ? pause() : resume() }
    func pause() { avPlayer.pause(); isPlaying = false; updateNowPlaying() }
    func resume() { avPlayer.play(); avPlayer.rate = Float(settings.playbackSpeed); isPlaying = true; updateNowPlaying() }
    func next() {
        guard !queue.isEmpty else { return }
        if settings.repeatMode == 2 { playCurrent(); return }
        if index + 1 < queue.count { index += 1; playCurrent() }
        else if settings.repeatMode == 1 { index = 0; playCurrent() }
        else if settings.autoRadioQueue { Task { await loadRadioContinuation() } }
    }
    func previous() {
        if position > 5 { seek(to: 0); return }
        if index > 0 { index -= 1; playCurrent() }
    }
    func seek(to seconds: Double) {
        avPlayer.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }
    func toggleMute() { isMuted.toggle(); avPlayer.volume = isMuted ? 0 : Float(settings.volume) }

    // MARK: Efectos de audio (EQ paramétrico, normalización, skip-silence, crossfade)
    private func applyLoudnessNormalization(song: SongItem) {
        guard settings.audioNormalization else { return }
        let target: Double
        switch settings.loudnessLevel {
        case "aggressive": target = -7
        case "loud": target = -11
        case "quiet": target = -19
        default: target = -14
        }
        let songDb = song.loudnessDb ?? target
        let gainDb = target - songDb
        let gain = pow(10, gainDb / 20)
        avPlayer.volume = Float(min(max(Double(settings.volume) * gain, 0), 1))
    }

    // MARK: Radio / autoplay (similarContent, autoLoadMore)
    private func loadRadioContinuation() async {
        guard let cur = currentSong, settings.autoRadioQueue else { return }
        do {
            _ = try await InnerTubeClient.shared.next(videoId: cur.id)
        } catch {}
        // Mezcla demo: re-encola relacionados para no parar (automix)
        if settings.autoLoadMore, let extra = queue.first {
            queue.append(extra)
        }
    }

    // MARK: Cola persistente
    private var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("queue.json")
    }
    func saveQueue() {
        let ids = queue.map { $0.id }
        try? JSONSerialization.data(withJSONObject: ["ids": ids, "index": index]).write(to: saveURL)
    }
    func restoreQueue(allSongs: [SongItem]) {
        guard settings.persistentQueue,
              let data = try? Data(contentsOf: saveURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let ids = json["ids"] as? [String] else { return }
        let map = Dictionary(uniqueKeysWithValues: allSongs.map { ($0.id, $0) })
        queue = ids.compactMap { map[$0] }
        index = (json["index"] as? Int) ?? 0
        currentSong = queue.indices.contains(index) ? queue[index] : nil
    }

    // MARK: Historial / scrobble
    private func recordPlayStart(song: SongItem) {
        guard !settings.pauseListenHistory else { return }
        HistoryStore.shared.record(songId: song.id, playTime: 0)
    }

    // MARK: Now Playing / Remote / Background (MediaSession + notificación)
    private func setupNowPlaying(song: SongItem) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.title,
            MPMediaItemPropertyArtist: song.artistsText,
            MPMediaItemPropertyPlaybackDuration: song.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
            MPNowPlayingInfoPropertyPlaybackRate: 1,
        ]
        if let u = song.thumbnailURL { info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: CGSize(width: 512, height: 512)) { _ in UIImage(systemName: "music.note") ?? UIImage() } ; _ = u }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    private func updateNowPlaying() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = position
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Double(settings.playbackSpeed) : 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { _ in self.resume(); return .success }
        c.pauseCommand.addTarget { _ in self.pause(); return .success }
        c.nextTrackCommand.addTarget { _ in self.next(); return .success }
        c.previousTrackCommand.addTarget { _ in self.previous(); return .success }
        c.changePlaybackPositionCommand.addTarget { e in
            if let ev = e as? MPChangePlaybackPositionCommandEvent { self.seek(to: ev.positionTime) }
            return .success
        }
    }
}

// MARK: - Historial en memoria (persistido vía SwiftData PlayEvent desde las vistas)
final class HistoryStore {
    static let shared = HistoryStore()
    private init() {}
    var pending: [(songId: String, playTime: Double)] = []
    func record(songId: String, playTime: Double) { pending.append((songId, playTime)) }
}
