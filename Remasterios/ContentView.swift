import SwiftUI

/// Equivalente a MainActivity.kt + Screens.kt: 4 tabs + bottom-sheet player + mini player + queue.
struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var player: PlayerService
    @State private var path = NavigationPath()
    @State private var tab = 0
    @State private var showPlayer = false
    @State private var showQueue = false
    @State private var showWelcome = false

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
        .onAppear {
            if SettingsStore.shared.innerTubeCookie.isEmpty && !UserDefaults.standard.bool(forKey: "welcomeDone") {
                showWelcome = true
            }
        }
        .sheet(isPresented: $showWelcome) { WelcomeView() }
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

/// Pantalla de bienvenida + login (antes solo estaba en Ajustes → Cuenta).
/// Metrolist usa login por cookie de YouTube Music: se pega aquí una vez.
struct WelcomeView: View {
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) var dismiss
    @State private var cookie = ""
    @State private var saved = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Para ver tus canciones, listas y recomendaciones necesitas conectar tu cuenta de YouTube Music.")
                }
                Section("Cómo conseguir la cookie") {
                    Text("1. En Safari abre music.youtube.com e inicia sesión.\n2. Copia el valor de la cookie (usa la app 'EditCookie' o similar).\n3. Pégala aquí abajo.")
                        .font(.callout)
                }
                Section("Cookie") {
                    TextEditor(text: $cookie)
                        .frame(height: 120)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Button("Guardar y continuar") {
                    settings.innerTubeCookie = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
                    UserDefaults.standard.set(true, forKey: "welcomeDone")
                    saved = true
                    dismiss()
                }
                .disabled(cookie.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Continuar sin cuenta (solo demo)") {
                    UserDefaults.standard.set(true, forKey: "welcomeDone")
                    dismiss()
                }
                if saved { Text("Cuenta guardada. Ya puedes buscar música real.").foregroundStyle(.green) }
            }
            .navigationTitle("Bienvenido a Remasterios")
        }
    }
}
