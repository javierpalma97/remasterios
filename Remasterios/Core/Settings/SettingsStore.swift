import Foundation
import Combine

/// Equivalente a PreferenceKeys.kt (~150 keys con DataStore) → UserDefaults + @Published.
/// Todos los ajustes de Metrolist portados: apariencia, player, audio, red, caché,
/// privacidad, integraciones, sorts, letras/IA, sleep/alarm, sistema.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    private let d = UserDefaults.standard

    // MARK: Apariencia / UI
    @Published var dynamicTheme = true
    @Published var pureBlack = false
    @Published var darkMode: DarkMode = .auto
    @Published var themeColor: String = "red"
    @Published var densityScale: Double = 1.0
    @Published var defaultTab: String = "home"
    @Published var slimNavBar = false
    @Published var sliderStyle: String = "wavy"
    @Published var useNewPlayer = true
    @Published var appLanguage: String = "system"
    @Published var showLyrics = true
    @Published var lyricsAnimation: String = "karaoke"

    // MARK: Player / Audio
    @Published var audioQuality: String = "high" // auto/low/high
    @Published var audioNormalization = true
    @Published var loudnessLevel: String = "balanced" // aggressive/loud/balanced/quiet
    @Published var skipSilence = false
    @Published var skipSilenceInstant = false
    @Published var crossfadeEnabled = false
    @Published var crossfadeSeconds: Double = 5
    @Published var gapless = true
    @Published var playbackSpeed: Double = 1.0
    @Published var playbackPitch: Double = 0  // semitonos
    @Published var autoRadioQueue = true
    @Published var autoLoadMore = true
    @Published var autoDownloadOnLike = false
    @Published var similarContent = true
    @Published var autoSkipNextOnError = true
    @Published var autoplay = true
    @Published var stopMusicOnTaskClear = false
    @Published var pauseOnMute = true
    @Published var resumeOnBluetooth = true
    @Published var keepScreenOn = false
    @Published var hideExplicit = false
    @Published var hideVideoSongs = false
    @Published var hideShorts = true
    @Published var volume: Double = 1.0
    @Published var repeatMode: Int = 0 // 0 off 1 all 2 one
    @Published var shuffle = false
    @Published var persistentQueue = true

    // MARK: Red / Contenido
    @Published var contentLanguage = "es"
    @Published var contentCountry = "ES"
    @Published var visitorData = ""
    @Published var innerTubeCookie = ""
    @Published var accountName = ""
    @Published var proxyEnabled = false
    @Published var proxyURL = ""
    @Published var ytmSync = true

    // MARK: Caché
    @Published var enableSongCache = true
    @Published var maxSongCacheMB: Int = 1024
    @Published var maxImageCacheMB: Int = 512

    // MARK: Privacidad
    @Published var pauseListenHistory = false
    @Published var pauseSearchHistory = false

    // MARK: Integraciones
    @Published var lastfmEnabled = false
    @Published var lastfmUsername = ""
    @Published var lastfmSessionKey = ""
    @Published var scrobblePercent = 50
    @Published var discordEnabled = false
    @Published var listenTogetherServer = "wss://metroserver.example"
    @Published var listenTogetherUsername = ""

    // MARK: Letras / IA
    @Published var preferredLyricsProvider = "betterlyrics"
    @Published var lyricsProviderOrder: [String] = ["betterlyrics","lrclib","kugou","paxsenix","lyricsplus","youtube"]
    @Published var openRouterKey = ""
    @Published var openRouterModel = "google/gemini-2.5-flash-lite"
    @Published var deeplKey = ""
    @Published var translateLanguage = "es"

    // MARK: Sleep / Alarm
    @Published var sleepTimerMinutes = 30
    @Published var sleepStopAfterCurrentSong = false
    @Published var alarmEnabled = false
    @Published var alarmHour = 8
    @Published var alarmMinute = 0
    @Published var alarmPlaylistId = ""

    // MARK: EQ
    @Published var eqEnabled = false
    @Published var eqPreamp: Double = 0
    @Published var eqBands: [Double] = [0,0,0,0,0] // 5 bandas

    private init() {}

    enum DarkMode: String {
        case auto, on, off
    }
}
