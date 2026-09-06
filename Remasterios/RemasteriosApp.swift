import SwiftUI
import SwiftData

@main
struct RemasteriosApp: App {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var player = PlayerService.shared
    @StateObject private var sync = SyncEngine.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            SongItem.self,
            AlbumItem.self,
            ArtistItem.self,
            PlaylistItem.self,
            PlaylistSongLink.self,
            LyricsCache.self,
            PlayEvent.self,
            SearchHistoryItem.self,
            RecognitionItem.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("No se pudo crear ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(player)
                .environmentObject(sync)
                .preferredColorScheme(settings.darkMode == .on ? .dark : settings.darkMode == .off ? .light : nil)
        }
        .modelContainer(sharedModelContainer)
    }
}
