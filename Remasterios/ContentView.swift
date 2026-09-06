import SwiftUI

/// Equivalente a MainActivity.kt + Screens.kt: 4 tabs + bottom-sheet player + mini player + queue.
struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var player: PlayerService
    @State private var path = NavigationPath()
    @State private var tab = 0
    @State private var showPlayer = false
    @State private var showQueue = false

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $path) {
                HomeView(path: $path)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteView(route: route, path: $path)
                    }
            }
            .tabItem { Label("Inicio", systemImage: "house") }.tag(0)

            NavigationStack(path: $path) {
                SearchView(path: $path)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteView(route: route, path: $path)
                    }
            }
            .tabItem { Label("Buscar", systemImage: "magnifyingglass") }.tag(1)

            NavigationStack(path: $path) {
                ListenTogetherView(path: $path)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteView(route: route, path: $path)
                    }
            }
            .tabItem { Label("Juntos", systemImage: "person.2") }.tag(2)

            NavigationStack(path: $path) {
                LibraryView(path: $path)
                    .navigationDestination(for: AppRoute.self) { route in
                        RouteView(route: route, path: $path)
                    }
            }
            .tabItem { Label("Biblioteca", systemImage: "books.vertical") }.tag(3)
        }
        .safeAreaInset(edge: .bottom) {
            if player.currentSong != nil {
                MiniPlayerView(onTap: { showPlayer = true }, onQueue: { showQueue = true })
            }
        }
        .sheet(isPresented: $showPlayer) { PlayerView().presentationDetents([.large]) }
        .sheet(isPresented: $showQueue) { QueueView().presentationDetents([.medium, .large]) }
    }
}

/// Router central (NavigationBuilder.kt con 45 rutas).
struct RouteView: View {
    let route: AppRoute
    @Binding var path: NavigationPath
    var body: some View {
        switch route {
        case .home: HomeView(path: $path)
        case .searchInput: SearchView(path: $path)
        case .searchResults(let q): SearchResultsView(query: q, path: $path)
        case .library: LibraryView(path: $path)
        case .album(let id): AlbumView(albumId: id, path: $path)
        case .artist(let id, let pod): ArtistView(artistId: id, isPodcast: pod, path: $path)
        case .onlinePlaylist(let id): OnlinePlaylistView(playlistId: id, path: $path)
        case .localPlaylist(let id): LocalPlaylistView(playlistId: id, path: $path)
        case .history: HistoryView()
        case .stats: StatsView(path: $path)
        case .account: AccountView(path: $path)
        case .login: LoginView()
        case .settings: SettingsView(path: $path)
        case .appearanceSettings: AppearanceSettingsView()
        case .playerSettings: PlayerSettingsView()
        case .storageSettings: StorageSettingsView()
        case .privacySettings: PrivacySettingsView()
        case .integrationsSettings: IntegrationsSettingsView()
        case .aiSettings: AISettingsView()
        case .contentSettings: ContentSettingsView()
        case .backupRestore: BackupRestoreView()
        case .about: AboutView()
        case .wrapped: WrappedView()
        case .equalizer: EqualizerView()
        case .equalizerWizard: EqualizerWizardView()
        case .recognition(let auto): RecognitionView(autoStart: auto)
        case .recognitionHistory: RecognitionHistoryView()
        case .listenTogether: ListenTogetherView(path: $path)
        case .topPlaylist(let p): TopPlaylistView(period: p, path: $path)
        case .autoPlaylist(let k): AutoPlaylistView(kind: k, path: $path)
        default: Text("Pantalla \(String(describing: route))")
        }
    }
}
