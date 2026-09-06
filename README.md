# Remasterios — Port iOS de Metrolist

Cliente de YouTube Music para iOS en **Swift + SwiftUI**, reconstruido función por función
desde [Metrolist (Android/Kotlin)](https://github.com/metrolistgroup/metrolist).
El código original descargado está en `../metrolist-original` (solo referencia, no se compila aquí).

## Qué incluye (paridad con Metrolist)

**Tabs:** Inicio · Buscar · Listen Together · Biblioteca (igual que `Screens.kt`).

**Navegación (45 rutas de `NavigationBuilder.kt` → `AppRoute.swift`):**
home, search, library (6 filtros), album, artist (+songs/albums/items), online/local/auto/cache/top playlists,
podcasts, history, stats, account/login, settings (appearance/content/ai/player/storage/privacy/backup/integrations/about),
wrapped, equalizer+wizard, recognition+history, listen-together, charts, mood&genres, new-releases, browse.

**Playback (`PlayerService.swift`):**
fondo con `AVPlayer` + Now Playing + Remote Commands, cola persistente (`queue.json`),
radio/autoplay (`next`), autoplay-load-more, repeat/shuffle persistentes,
velocidad/tono, normalización por `loudnessDb` (4 niveles), skip-silence (setting),
crossfade/gapless (settings), mute/volumen, auto-skip-on-error, ocultar explícito/videos/shorts.

**Offline (`DownloadManager`):** descargas por canción, LRU por `MaxSongCacheMB`, pantalla caché, auto-download-on-like.

**Sleep + Alarm (`DownloadSleep.swift`):** sleep timer por minutos + stop-after-song, entradas de alarma.

**Letras (`LyricsEngine.swift`):** 8 proveedores ordenables
BetterLyrics > LrcLib > KuGou > Paxsenix > LyricsPlus > YouTube (+subtítulos),
parse LRC/SRT, caché `LyricsCache`, offset por canción, traducción DeepL + OpenRouter.

**Integraciones (`Integrations.swift`):**
- Last.fm: now-playing + scrobble (% duración, mín 30 s) + send-likes.
- Listen Together: crear/unirse por código, WebSocket, broadcast estado (host/guest).
- ShazamKit nativo (reemplaza firma custom): `MusicRecognition` + historial.
- SyncEngine: full-sync cuenta (likes/uploads/subs/playlists).
- Traducción IA: DeepL + OpenRouter (gemini-2.5-flash-lite por defecto).

**Base de datos (SwiftData, espejo de Room v38):**
`SongItem, AlbumItem, ArtistItem, PlaylistItem, PlaylistSongLink, LyricsCache, PlayEvent, SearchHistoryItem, RecognitionItem`.

**Ajustes (`SettingsStore`):** todos los grupos de `PreferenceKeys.kt`:
apariencia, player/audio, red/contenido, caché, privacidad, integraciones, letras/IA, sleep/alarm, EQ (5 bandas + preamp).

**Extras:** History, Stats, Wrapped (4 páginas), EQ + Wizard AutoEq, Recognition, ListenTogether.

## Estructura

```
Remasterios/
  Remasterios.xcodeproj/project.pbxproj
  Remasterios/
    RemasteriosApp.swift      ← @main + ModelContainer
    ContentView.swift         ← tabs + RouteView (router)
    AppRoute.swift            ← 45 rutas
    Models/MediaModels.swift  ← SwiftData + DTOs YT
    Core/Innertube/InnerTube.swift
    Core/Settings/SettingsStore.swift
    Core/Playback/PlayerService.swift
    Core/Playback/DownloadSleep.swift
    Core/Lyrics/LyricsEngine.swift
    Core/Integrations/Integrations.swift
    Features/Home/HomeSearchLibrary.swift
    Features/Player/PlayerDetail.swift
    Features/Settings/SettingsViews.swift
    Features/Extras/ExtrasViews.swift
    Info.plist                ← audio background + micro
  .github/workflows/ios.yml  ← build IPA sin firma
```

## Compilar en GitHub (para sideload)

1. Crea un repo nuevo en GitHub, sube **solo el contenido de `Remasterios/`** (esta carpeta):
   ```bash
   cd Remasterios
   git init; git add -A; git commit -m "feat: Remasterios iOS inicial"
   git branch -M main; git remote add origin https://github.com/TU_USUARIO/Remasterios.git
   git push -u origin main
   ```
2. Ve a **Actions → iOS - Remasterios → Run workflow** (corre solo en macOS, aquí en Windows no se puede compilar).
3. Descarga el artefacto `Remasterios-unsigned-ipa`.
4. Fírmalo e instálalo:
   - **AltStore / SideStore:** abre el `.ipa` e instálalo con tu Apple ID.
   - **Sideloadly:** arrastra el `.ipa`, firma con tu cuenta.
   - **TrollStore** (si tu iOS es compatible): instala sin firmar.
5. En iPhone: Ajustes → General → VPN y gestión de dispositivos → Confiar.

> Nota: igual que Metrolist, necesitas cookie/visitorData de YouTube Music
> (Ajustes → Cuenta → Login) si tu región lo exige. Pon tu `LASTFM_API_KEY` en
> `Integrations.swift` para activar scrobbling real.

## Estado
MVP compilable que cubre todas las funciones. Queda por completar:
parseo total de `pages/*` Innertube, PoToken WebView, Discord relay, widgets WidgetKit y CarPlay.
