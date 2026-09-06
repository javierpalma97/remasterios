import SwiftUI

// MARK: - Player (BottomSheetPlayer + MiniPlayer + Queue + lyrics inline + sleep inline)
struct MiniPlayerView: View {
    @EnvironmentObject var player: PlayerService
    var onTap: () -> Void
    var onQueue: () -> Void
    var body: some View {
        if let s = player.currentSong {
            HStack {
                Button(action: onTap) {
                    HStack {
                        AsyncImage(url: URL(string: s.thumbnailURL ?? "")) { $0.resizable() } placeholder: { Color.gray }
                            .frame(width: 44, height: 44).cornerRadius(6)
                        VStack(alignment: .leading) {
                            Text(s.title).lineLimit(1).font(.subheadline)
                            Text(s.artistsText).lineLimit(1).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Button { player.toggle() } label: { Image(systemName: player.isPlaying ? "pause.fill" : "play.fill") }
                Button { player.next() } label: { Image(systemName: "forward.fill") }
                Button(action: onQueue) { Image(systemName: "list.bullet") }
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }
}

struct PlayerView: View {
    @EnvironmentObject var player: PlayerService
    @EnvironmentObject var settings: SettingsStore
    @State private var showLyrics = true
    @State private var lyrics: LyricsResult?
    @State private var sleepSheet = false
    var body: some View {
        NavigationStack {
            VStack {
                AsyncImage(url: URL(string: player.currentSong?.thumbnailURL ?? "")) { $0.resizable() } placeholder: { RoundedRectangle(cornerRadius: 16).fill(.gray) }
                    .frame(width: 280, height: 280).cornerRadius(16).padding()
                Text(player.currentSong?.title ?? "—").font(.title2).bold()
                Text(player.currentSong?.artistsText ?? "").foregroundStyle(.secondary)
                // Slider (DEFAULT/WAVY/SLIM)
                Slider(value: Binding(get: { player.position }, set: { player.seek(to: $0) }), in: 0...(max(player.duration, 1)))
                    .padding()
                HStack {
                    Text(fmt(player.position)); Spacer(); Text(fmt(player.duration))
                }.font(.caption).padding(.horizontal)
                HStack(spacing: 32) {
                    Button { player.previous() } label: { Image(systemName: "backward.fill").font(.title) }
                    Button { player.toggle() } label: { Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 64)) }
                    Button { player.next() } label: { Image(systemName: "forward.fill").font(.title) }
                }.padding()
                HStack {
                    Button { player.toggleMute() } label: { Image(systemName: player.isMuted ? "speaker.slash" : "speaker.wave.2") }
                    Spacer()
                    Button("Sleep") { sleepSheet = true }
                    Spacer()
                    Button(showLyrics ? "Ocultar letra" : "Letra") { showLyrics.toggle() }
                }.padding(.horizontal)
                if showLyrics {
                    LyricsInlineView(song: player.currentSong, lyrics: $lyrics)
                }
                Spacer()
            }
            .navigationTitle("Reproductor").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $sleepSheet) {
                SleepTimerSheet()
            }
            .task(id: player.currentSong?.id) {
                guard let s = player.currentSong else { return }
                lyrics = await LyricsEngine.shared.fetchAll(artist: s.artistsText, title: s.title, duration: s.duration)
            }
        }
    }
    private func fmt(_ v: Double) -> String { guard v.isFinite else { return "0:00" }; return "\(Int(v/60)):\(String(format: "%02d", Int(v) % 60))" }
}

struct LyricsInlineView: View {
    var song: SongItem?
    @Binding var lyrics: LyricsResult?
    @EnvironmentObject var player: PlayerService
    var body: some View {
        ScrollView {
            if let l = lyrics, !l.syncedLines.isEmpty {
                ForEach(l.syncedLines.prefix(200), id: \.start) { line in
                    Text(line.text)
                        .foregroundStyle(abs(line.start - player.position) < 3 ? .primary : .secondary)
                        .bold(abs(line.start - player.position) < 3)
                        .frame(maxWidth: .infinity)
                }
            } else if let p = lyrics?.plain {
                Text(p).font(.subheadline).padding()
            } else {
                Text("Sin letra disponible").foregroundStyle(.secondary)
            }
        }
    }
}

struct QueueView: View {
    @EnvironmentObject var player: PlayerService
    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(player.queue.enumerated()), id: \.offset) { i, s in
                    HStack {
                        Text(s.title).bold(i == player.index)
                        Spacer()
                        if i == player.index { Image(systemName: "waveform") }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { player.index = i; player.playCurrent() }
                }
                .onMove { player.queue.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { player.queue.remove(atOffsets: $0) }
            }
            .navigationTitle("Cola").toolbar { EditButton() }
        }
    }
}

struct SleepTimerSheet: View {
    @State private var minutes = 30
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Stepper("Minutos: \(minutes)", value: $minutes, in: 5...180, step: 5)
                Button("Iniciar sleep timer") {
                    Task { @MainActor in SleepTimerManager.shared.start(minutes: minutes) }
                    dismiss()
                }
                if SleepTimerManager.shared.minutesLeft != nil {
                    Button("Cancelar", role: .destructive) {
                        Task { @MainActor in SleepTimerManager.shared.cancel() }
                        dismiss()
                    }
                }
            }.navigationTitle("Sleep timer")
        }
    }
}

// MARK: - Detalle: Album / Artist / Playlists / History / Stats
struct AlbumView: View {
    let albumId: String; @Binding var path: NavigationPath
    @EnvironmentObject var player: PlayerService
    @State private var songs: [YTSong] = []
    var body: some View {
        List(songs, id: \.id) { s in SongRow(song: s) { player.play(songs: songs.map { toItem($0) }, startAt: songs.firstIndex(of: s) ?? 0) } }
            .navigationTitle("Álbum")
            .task { _ = try? await InnerTubeClient.shared.browse(browseId: albumId); songs = DemoData.songs }
    }
    private func toItem(_ s: YTSong) -> SongItem { SongItem(id: s.id, title: s.title, artistsText: s.artists.map { $0.name }.joined(separator: ", "), duration: s.duration ?? 0, thumbnailURL: s.thumbnails.first?.url) }
}
struct ArtistView: View {
    let artistId: String; var isPodcast = false; @Binding var path: NavigationPath
    var body: some View { Text("Artista \(artistId)").navigationTitle("Artista") }
}
struct OnlinePlaylistView: View {
    let playlistId: String; @Binding var path: NavigationPath
    @EnvironmentObject var player: PlayerService
    @State private var songs: [YTSong] = DemoData.songs
    var body: some View {
        List(songs, id: \.id) { s in SongRow(song: s) { player.play(songs: [SongItem(id: s.id, title: s.title, artistsText: s.artists.map { $0.name }.joined(separator: ", "), duration: s.duration ?? 0)]) } }
            .navigationTitle("Playlist online")
    }
}
struct LocalPlaylistView: View {
    let playlistId: String; @Binding var path: NavigationPath
    var body: some View { Text("Playlist local \(playlistId)").navigationTitle("Playlist") }
}
struct AutoPlaylistView: View {
    let kind: AutoPlaylistKind; @Binding var path: NavigationPath
    var body: some View { Text("Auto playlist \(kind.rawValue)").navigationTitle(kind.rawValue.capitalized) }
}
struct TopPlaylistView: View {
    let period: TopPeriod; @Binding var path: NavigationPath
    var body: some View { Text("Top \(period.rawValue)").navigationTitle("Top") }
}
