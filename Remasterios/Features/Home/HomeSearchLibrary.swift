import SwiftUI
import SwiftData

// MARK: - Home (HomeScreen + HomeViewModel: QuickPicks, ForgottenFavorites, HomePage, SpeedDial)
struct HomeView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var player: PlayerService
    @Environment(\.modelContext) var context
    @State private var sections: [HomeSection] = []
    @State private var loading = true

    var body: some View {
        List {
            if loading { ProgressView("Cargando inicio…") }
            ForEach(sections) { s in
                Section(s.title) {
                    ForEach(s.songs, id: \.id) { song in
                        SongRow(song: song) {
                            player.play(songs: [toItem(song)])
                        }
                    }
                }
            }
            Section("Accesos") {
                Button("Novedades") { path.append(AppRoute.newReleases) }
                Button("Charts") { path.append(AppRoute.charts) }
                Button("Mi Wrapped") { path.append(AppRoute.wrapped) }
                Button("Reconocer música") { path.append(AppRoute.recognition(autoStart: false)) }
            }
        }
        .navigationTitle("Inicio")
        .task { sections = await MusicRepository.shared.homeSections(); loading = false }
        .refreshable { sections = await MusicRepository.shared.homeSections() }
    }

    private func toItem(_ s: YTSong) -> SongItem {
        SongItem(id: s.id, title: s.title, artistsText: s.artists.map { $0.name }.joined(separator: ", "),
                 artistIds: s.artists.compactMap { $0.id }, duration: s.duration ?? 0,
                 thumbnailURL: s.thumbnails.first?.url)
    }
}

struct SongRow: View {
    let song: YTSong
    var onPlay: () -> Void
    var body: some View {
        Button(action: onPlay) {
            HStack {
                AsyncImage(url: URL(string: song.thumbnails.first?.url ?? "")) { $0.resizable() } placeholder: { Color.gray }
                    .frame(width: 48, height: 48).cornerRadius(8)
                VStack(alignment: .leading) {
                    Text(song.title).lineLimit(1)
                    Text(song.artists.map { $0.name }.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if let d = song.duration { Text(formatDur(d)).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
    private func formatDur(_ s: Double) -> String { "\(Int(s/60)):\(String(format: "%02d", Int(s) % 60))" }
}

// MARK: - Search (SearchScreen: LOCAL/ONLINE, historial, sugerencias, parseo URLs)
struct SearchView: View {
    @Binding var path: NavigationPath
    @State private var query = ""
    @State private var online = true
    @Query(sort: \SearchHistoryItem.date, order: .reverse) var history: [SearchHistoryItem]
    @Environment(\.modelContext) var context

    var body: some View {
        VStack {
            Picker("Fuente", selection: $online) {
                Text("Online").tag(true); Text("Local").tag(false)
            }.pickerStyle(.segmented).padding()
            List {
                ForEach(history.prefix(10)) { h in
                    Button(h.query) { query = h.query; go() }
                }
            }
        }
        .searchable(text: $query, prompt: "Canciones, álbumes, artistas…")
        .onSubmit(of: .search) { go() }
        .navigationTitle("Buscar")
    }
    private func go() {
        if !query.isEmpty {
            try? context.insert(SearchHistoryItem(query: query)); try? context.save()
            // Parseo de URLs de YouTube (OnlineSearchResult lo resuelve)
            path.append(AppRoute.searchResults(query: query))
        }
    }
}

struct SearchResultsView: View {
    let query: String
    @Binding var path: NavigationPath
    @EnvironmentObject var player: PlayerService
    @State private var songs: [YTSong] = []
    var body: some View {
        List(songs, id: \.id) { s in
            SongRow(song: s) {
                player.play(songs: [SongItem(id: s.id, title: s.title, artistsText: s.artists.map { $0.name }.joined(separator: ", "), duration: s.duration ?? 0, thumbnailURL: s.thumbnails.first?.url)])
            }
        }
        .navigationTitle(query)
        .task { songs = await MusicRepository.shared.search(query: query) }
    }
}

// MARK: - Library (LibraryScreen + 6 filtros + sorts + LIST/GRID)
struct LibraryView: View {
    @Binding var path: NavigationPath
    @Query(sort: \SongItem.dateAdded, order: .reverse) var songs: [SongItem]
    @Query(sort: \PlaylistItem.lastUpdate, order: .reverse) var playlists: [PlaylistItem]
    @State private var filter = 0
    var body: some View {
        List {
            Section("Biblioteca") {
                NavigationLink("Canciones (\(songs.count))", value: AppRoute.autoPlaylist(kind: .liked))
                NavigationLink("Playlists (\(playlists.count))", value: AppRoute.library)
                NavigationLink("Descargas", value: AppRoute.autoPlaylist(kind: .downloaded))
                NavigationLink("Historial", value: AppRoute.history)
                NavigationLink("Estadísticas", value: AppRoute.stats)
                NavigationLink("Podcasts", value: AppRoute.library)
            }
            Section("Playlists") {
                ForEach(playlists) { p in
                    NavigationLink(p.name, value: AppRoute.localPlaylist(id: p.id))
                }
            }
        }
        .navigationTitle("Biblioteca")
        .toolbar {
            NavigationLink(value: AppRoute.settings) { Image(systemName: "gear") }
        }
    }
}
