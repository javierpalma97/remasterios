import Foundation
import SwiftData

// MARK: - Modelos de dominio (equivalen a entities Room + modelos Innertube)

@Model
final class SongItem {
    @Attribute(.unique) var id: String  // videoId
    var title: String
    var artistsText: String
    var artistIds: [String]
    var albumId: String?
    var albumTitle: String?
    var duration: Double
    var thumbnailURL: String?
    var explicit: Bool
    var year: Int?
    var liked: Bool
    var likedDate: Date?
    var totalPlayTime: Double
    var inLibrary: Bool
    var isDownloaded: Bool
    var isUploaded: Bool
    var isVideo: Bool
    var isEpisode: Bool
    var isCached: Bool
    var dateDownload: Date?
    var playbackPosition: Double
    var lyricsOffset: Double
    var loudnessDb: Double?
    var dateAdded: Date

    init(id: String, title: String, artistsText: String = "", artistIds: [String] = [],
         albumId: String? = nil, albumTitle: String? = nil, duration: Double = 0,
         thumbnailURL: String? = nil, explicit: Bool = false) {
        self.id = id; self.title = title; self.artistsText = artistsText
        self.artistIds = artistIds; self.albumId = albumId; self.albumTitle = albumTitle
        self.duration = duration; self.thumbnailURL = thumbnailURL; self.explicit = explicit
        self.liked = false; self.totalPlayTime = 0; self.inLibrary = false
        self.isDownloaded = false; self.isUploaded = false; self.isVideo = false
        self.isEpisode = false; self.isCached = false; self.playbackPosition = 0
        self.lyricsOffset = 0; self.dateAdded = Date()
    }
}

@Model
final class AlbumItem {
    @Attribute(.unique) var id: String
    var title: String
    var year: Int?
    var thumbnailURL: String?
    var songCount: Int
    var duration: Double
    var explicit: Bool
    var inLibrary: Bool
    var likedDate: Date?
    var lastUpdate: Date?

    init(id: String, title: String, thumbnailURL: String? = nil) {
        self.id = id; self.title = title; self.thumbnailURL = thumbnailURL
        self.songCount = 0; self.duration = 0; self.explicit = false; self.inLibrary = false
    }
}

@Model
final class ArtistItem {
    @Attribute(.unique) var id: String
    var name: String
    var thumbnailURL: String?
    var channelId: String?
    var bookmarkedAt: Date?
    var isPodcastChannel: Bool
    var cachedPageJSON: String?

    init(id: String, name: String, thumbnailURL: String? = nil) {
        self.id = id; self.name = name; self.thumbnailURL = thumbnailURL
        self.isPodcastChannel = false
    }
}

@Model
final class PlaylistItem {
    @Attribute(.unique) var id: String
    var name: String
    var browseId: String?
    var isLocal: Bool
    var isEditable: Bool
    var thumbnailURL: String?
    var createdAt: Date
    var lastUpdate: Date
    var shareLink: String?

    init(id: String, name: String, isLocal: Bool = true) {
        self.id = id; self.name = name; self.isLocal = isLocal
        self.isEditable = isLocal; self.createdAt = Date(); self.lastUpdate = Date()
    }
}

@Model
final class PlaylistSongLink {
    var playlistId: String
    var songId: String
    var position: Int
    var setVideoId: String?

    init(playlistId: String, songId: String, position: Int) {
        self.playlistId = playlistId; self.songId = songId; self.position = position
    }
}

@Model
final class LyricsCache {
    @Attribute(.unique) var songId: String
    var plain: String?
    var synced: String?
    var provider: String?
    var translated: String?
    var translationLanguage: String?

    init(songId: String) { self.songId = songId }
}

@Model
final class PlayEvent {
    var songId: String
    var timestamp: Date
    var playTime: Double

    init(songId: String, playTime: Double) {
        self.songId = songId; self.timestamp = Date(); self.playTime = playTime
    }
}

@Model
final class SearchHistoryItem {
    @Attribute(.unique) var query: String
    var date: Date
    init(query: String) { self.query = query; self.date = Date() }
}

@Model
final class RecognitionItem {
    @Attribute(.unique) var trackId: String
    var title: String
    var artist: String
    var album: String?
    var coverURL: String?
    var genre: String?
    var date: Date
    var shazamURL: String?
    var youtubeVideoId: String?

    init(trackId: String, title: String, artist: String) {
        self.trackId = trackId; self.title = title; self.artist = artist; self.date = Date()
    }
}

// MARK: - Structs ligeros para API (Innertube pages)

struct YTSong: Codable, Hashable, Identifiable {
    var id: String; var title: String; var artists: [YTArtistRef]
    var album: YTAlbumRef?; var duration: Double?; var thumbnails: [YTThumb]
    var explicit: Bool?; var videoId: String { id }
}
struct YTArtistRef: Codable, Hashable { var id: String?; var name: String }
struct YTAlbumRef: Codable, Hashable { var id: String?; var name: String }
struct YTThumb: Codable, Hashable { var url: String; var width: Int?; var height: Int? }
struct YTPlaylistLite: Codable, Hashable, Identifiable {
    var id: String; var title: String; var subtitle: String?
    var thumbnails: [YTThumb]; var songCount: Int?
}
struct HomeSection: Codable, Hashable, Identifiable {
    var id: String { title }; var title: String; var songs: [YTSong]; var playlists: [YTPlaylistLite]
}
struct LyricLine: Hashable, Codable {
    var start: Double; var end: Double; var text: String
}
