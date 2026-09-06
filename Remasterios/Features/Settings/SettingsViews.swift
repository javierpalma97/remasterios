import SwiftUI
import SwiftData

// MARK: - Settings (SettingsScreen + subpantallas)
struct SettingsView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var settings: SettingsStore
    var body: some View {
        List {
            Section("Interfaz") { NavigationLink("Apariencia", value: AppRoute.appearanceSettings) }
            Section("Reproducción") { NavigationLink("Player y audio", value: AppRoute.playerSettings) }
            Section("Contenido") { NavigationLink("Contenido y red", value: AppRoute.contentSettings) }
            Section("IA y letras") { NavigationLink("IA / Traducción", value: AppRoute.aiSettings) }
            Section("Sistema") {
                NavigationLink("Almacenamiento", value: AppRoute.storageSettings)
                NavigationLink("Privacidad", value: AppRoute.privacySettings)
                NavigationLink("Backup y restauración", value: AppRoute.backupRestore)
                NavigationLink("Integraciones", value: AppRoute.integrationsSettings)
                NavigationLink("Acerca de", value: AppRoute.about)
            }
            Section("Extras") {
                NavigationLink("Ecualizador", value: AppRoute.equalizer)
                NavigationLink("Mi Wrapped", value: AppRoute.wrapped)
                NavigationLink("Cuenta", value: AppRoute.account)
            }
        }.navigationTitle("Ajustes")
    }
}

struct AppearanceSettingsView: View {
    @EnvironmentObject var s: SettingsStore
    var body: some View {
        Form {
            Toggle("Tema dinámico", isOn: $s.dynamicTheme)
            Toggle("Negro puro", isOn: $s.pureBlack)
            Picker("Modo oscuro", selection: $s.darkModeRaw) {
                Text("Auto").tag("auto"); Text("On").tag("on"); Text("Off").tag("off")
            }
            Slider(value: $s.densityScale, in: 0.55...1.0, step: 0.05) { Text("Escala \(Int(s.densityScale*100))%") }
            Toggle("Nuevo reproductor", isOn: $s.useNewPlayer)
            Toggle("Mostrar letras", isOn: $s.showLyrics)
        }.navigationTitle("Apariencia")
    }
}
extension SettingsStore {
    var darkModeRaw: String {
        get { darkMode.rawValue }
        set { darkMode = DarkMode(rawValue: newValue) ?? .auto }
    }
}

struct PlayerSettingsView: View {
    @EnvironmentObject var s: SettingsStore
    var body: some View {
        Form {
            Picker("Calidad", selection: $s.audioQuality) { Text("Auto").tag("auto"); Text("Baja").tag("low"); Text("Alta").tag("high") }
            Toggle("Normalización de volumen", isOn: $s.audioNormalization)
            Picker("Nivel", selection: $s.loudnessLevel) { Text("Agresivo").tag("aggressive"); Text("Alto").tag("loud"); Text("Balanceado").tag("balanced"); Text("Suave").tag("quiet") }
            Toggle("Saltar silencio", isOn: $s.skipSilence)
            Toggle("Crossfade", isOn: $s.crossfadeEnabled)
            Slider(value: $s.crossfadeSeconds, in: 1...12, step: 1) { Text("Crossfade \(Int(s.crossfadeSeconds))s") }
            Slider(value: $s.playbackSpeed, in: 0.5...2.0, step: 0.05) { Text("Velocidad \(s.playbackSpeed, specifier: "%.2f")x") }
            Toggle("Radio automática", isOn: $s.autoRadioQueue)
            Toggle("Autocargar más", isOn: $s.autoLoadMore)
            Toggle("Descargar al dar like", isOn: $s.autoDownloadOnLike)
            Toggle("Ocultar explícito", isOn: $s.hideExplicit)
            Toggle("Ocultar videos", isOn: $s.hideVideoSongs)
            Toggle("Cola persistente", isOn: $s.persistentQueue)
        }.navigationTitle("Player y audio")
    }
}

struct ContentSettingsView: View {
    @EnvironmentObject var s: SettingsStore
    var body: some View {
        Form {
            TextField("Idioma (hl)", text: $s.contentLanguage)
            TextField("País (gl)", text: $s.contentCountry)
            Toggle("Sincronizar YTM", isOn: $s.ytmSync)
            Toggle("Proxy", isOn: $s.proxyEnabled)
            TextField("URL proxy", text: $s.proxyURL)
        }.navigationTitle("Contenido")
    }
}

struct AISettingsView: View {
    @EnvironmentObject var s: SettingsStore
    var body: some View {
        Form {
            SecureField("OpenRouter API key", text: $s.openRouterKey)
            TextField("Modelo", text: $s.openRouterModel)
            SecureField("DeepL API key", text: $s.deeplKey)
            TextField("Idioma traducción", text: $s.translateLanguage)
        }.navigationTitle("IA / Traducción")
    }
}

struct StorageSettingsView: View {
    @EnvironmentObject var s: SettingsStore
    @State private var cacheMB = 0.0
    var body: some View {
        Form {
            Toggle("Caché de canciones", isOn: $s.enableSongCache)
            Stepper("Máx canciones: \(s.maxSongCacheMB) MB", value: $s.maxSongCacheMB, in: 128...8192, step: 128)
            Stepper("Máx imágenes: \(s.maxImageCacheMB) MB", value: $s.maxImageCacheMB, in: 64...2048, step: 64)
            Text("Uso offline: \(cacheMB, specifier: "%.1f") MB")
            Button("Limpiar descargas", role: .destructive) { DownloadManager.shared.clearAll(); cacheMB = 0 }
        }
        .navigationTitle("Almacenamiento")
        .onAppear { cacheMB = DownloadManager.shared.cacheSizeMB() }
    }
}

struct PrivacySettingsView: View {
    @EnvironmentObject var s: SettingsStore
    var body: some View {
        Form {
            Toggle("Pausar historial escucha", isOn: $s.pauseListenHistory)
            Toggle("Pausar historial búsqueda", isOn: $s.pauseSearchHistory)
        }.navigationTitle("Privacidad")
    }
}

struct IntegrationsSettingsView: View {
    @EnvironmentObject var s: SettingsStore
    var body: some View {
        Form {
            Section("Last.fm") {
                Toggle("Scrobbling", isOn: $s.lastfmEnabled)
                TextField("Usuario", text: $s.lastfmUsername)
                Stepper("% scrobble: \(s.scrobblePercent)%", value: $s.scrobblePercent, in: 10...100, step: 5)
            }
            Section("Listen together") {
                TextField("Servidor", text: $s.listenTogetherServer)
                TextField("Usuario", text: $s.listenTogetherUsername)
            }
            Section("Discord") {
                Toggle("Rich presence (vía relay)", isOn: $s.discordEnabled)
            }
        }.navigationTitle("Integraciones")
    }
}

struct AccountView: View {
    @Binding var path: NavigationPath
    @EnvironmentObject var s: SettingsStore
    var body: some View {
        Form {
            TextField("Cookie InnerTube", text: $s.innerTubeCookie)
            TextField("VisitorData", text: $s.visitorData)
            TextField("Cuenta", text: $s.accountName)
            NavigationLink("Iniciar sesión", value: AppRoute.login)
            Button("Sincronizar ahora") { Task { await SyncEngine.shared.fullSync() } }
        }.navigationTitle("Cuenta")
    }
}

struct LoginView: View {
    @EnvironmentObject var s: SettingsStore
    @State private var cookie = ""
    var body: some View {
        Form {
            Text("Pega la cookie de music.youtube.com (igual que en Metrolist → login por cookie).")
                .font(.caption).foregroundStyle(.secondary)
            TextEditor(text: $cookie).frame(height: 120)
            Button("Guardar") { s.innerTubeCookie = cookie }
        }.navigationTitle("Login")
    }
}

struct BackupRestoreView: View {
    var body: some View {
        Form {
            Text("Backup: exporta la base SwiftData + UserDefaults a JSON/ZIP y restáuralo. Incluye playlists, likes, historial (CSV/M3U soportado).")
            Button("Exportar backup") {}
            Button("Importar backup") {}
            Button("Importar playlist CSV/M3U") {}
        }.navigationTitle("Backup")
    }
}

struct AboutView: View {
    var body: some View {
        Form {
            Text("Remasterios — port iOS de Metrolist (cliente YouTube Music). SwiftUI + SwiftData + AVPlayer.")
            Text("No afiliado a YouTube/Google. Solo para sideload personal.")
        }.navigationTitle("Acerca de")
    }
}
