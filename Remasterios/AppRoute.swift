import Foundation

/// Todas las rutas de navegación (equivalente a NavigationBuilder.kt con 45+ rutas).
enum AppRoute: Hashable, Codable {
    case home
    case moodGenres
    case newReleases
    case charts
    case browse(browseId: String)
    case youtubeBrowse(browseId: String, params: String?)
    case searchInput
    case searchResults(query: String)
    case library
    case album(id: String)
    case artist(id: String, isPodcastChannel: Bool = false)
    case artistSongs(artistId: String)
    case artistAlbums(artistId: String)
    case artistItems(browseId: String, params: String?)
    case onlinePlaylist(id: String)
    case localPlaylist(id: String)
    case autoPlaylist(kind: AutoPlaylistKind)
    case cachePlaylist
    case topPlaylist(period: TopPeriod)
    case onlinePodcast(id: String)
    case history
    case stats
    case account
    case login
    case settings
    case appearanceSettings
    case contentSettings
    case aiSettings
    case playerSettings
    case storageSettings
    case privacySettings
    case backupRestore
    case integrationsSettings
    case about
    case wrapped
    case equalizer
    case equalizerWizard
    case recognition(autoStart: Bool = false)
    case recognitionHistory
    case listenTogether
}

enum AutoPlaylistKind: String, Codable, Hashable, CaseIterable {
    case liked, downloaded, uploaded, cached, weeklyMost, monthlyMost
}

enum TopPeriod: String, Codable, Hashable, CaseIterable {
    case day, week, month, year, all
}

enum LibraryFilter: String, Codable, CaseIterable {
    case library, liked, downloaded, uploaded
}

enum LibrarySort: String, Codable, CaseIterable {
    case createDate, name, artist, playTime, year, songCount, length, lastUpdated
}
