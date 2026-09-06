import SwiftUI
import SwiftData

// MARK: - Extras: History / Stats / Wrapped / EQ / Recognition / ListenTogether
struct HistoryView: View {
    @Query(sort: \PlayEvent.timestamp, order: .reverse) var events: [PlayEvent]
    var body: some View {
        List(events.prefix(200)) { e in
            HStack { Text(e.songId).lineLimit(1); Spacer(); Text(e.timestamp, style: .relative).font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("Historial")
    }
}

struct StatsView: View {
    @Binding var path: NavigationPath
    @Query var events: [PlayEvent]
    var body: some View {
        List {
            Section("Resumen") {
                Text("Reproducciones: \(events.count)")
                Text("Minutos: \(Int(events.reduce(0) { $0 + $1.playTime } / 60))")
            }
            NavigationLink("Top por periodo", value: AppRoute.topPlaylist(period: .month))
            NavigationLink("Mi Wrapped", value: AppRoute.wrapped)
        }.navigationTitle("Estadísticas")
    }
}

struct WrappedView: View {
    var body: some View {
        TabView {
            VStack { Text("Tu año en música").font(.largeTitle).bold(); Text("Remasterios Wrapped") }.tag(0)
            VStack { Text("Top 5 canciones").font(.title); Text("Calculado desde tus PlayEvent") }.tag(1)
            VStack { Text("Minutos escuchados").font(.title) }.tag(2)
            VStack { Text("Comparte tu resumen").font(.title); Button("Crear playlist anual") {} }.tag(3)
        }
        .tabViewStyle(.page).navigationTitle("Wrapped")
    }
}

struct EqualizerView: View {
    @EnvironmentObject var s: SettingsStore
    var body: some View {
        Form {
            Toggle("EQ activado", isOn: $s.eqEnabled)
            Slider(value: $s.eqPreamp, in: -12...12, step: 0.5) { Text("Preamp \(s.eqPreamp, specifier: "%.1f") dB") }
            ForEach(s.eqBands.indices, id: \.self) { i in
                Slider(value: $s.eqBands[i], in: -12...12, step: 0.5) { Text("Banda \(i+1): \(s.eqBands[i], specifier: "%.1f") dB") }
            }
            NavigationLink("Asistente AutoEq", value: AppRoute.equalizerWizard)
            Text("En iOS se aplica con AVAudioUnitEQ sobre AVAudioEngine.").font(.caption).foregroundStyle(.secondary)
        }.navigationTitle("Ecualizador")
    }
}
struct EqualizerWizardView: View {
    var body: some View { Text("Wizard AutoEq: busca perfiles de tus auriculares en GitHub AutoEq.").navigationTitle("Asistente EQ").padding() }
}

struct RecognitionView: View {
    var autoStart = false
    @StateObject private var rec = MusicRecognition.shared
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: rec.listening ? "waveform.circle.fill" : "shazam.logo.fill").font(.system(size: 100))
            Text(rec.listening ? "Escuchando…" : "Toca para reconocer")
            Button(rec.listening ? "Detener" : "Reconocer") { rec.toggle() }.buttonStyle(.borderedProminent)
            if let m = rec.match {
                Text(m.title ?? "Match").bold()
                Text(m.artist ?? "")
            }
            NavigationLink("Historial de reconocimientos", value: AppRoute.recognitionHistory)
        }
        .padding().navigationTitle("Reconocer")
        .onAppear { if autoStart && !rec.listening { rec.start() } }
    }
}
struct RecognitionHistoryView: View {
    @Query(sort: \RecognitionItem.date, order: .reverse) var items: [RecognitionItem]
    var body: some View {
        List(items) { r in VStack(alignment: .leading) { Text(r.title).bold(); Text("\(r.artist)").font(.caption) } }
            .navigationTitle("Reconocimientos")
    }
}

struct ListenTogetherView: View {
    @Binding var path: NavigationPath
    @StateObject private var session = ListenTogetherSession.shared
    @EnvironmentObject var s: SettingsStore
    @State private var room = ""
    var body: some View {
        Form {
            TextField("Tu nombre", text: $s.listenTogetherUsername)
            if session.connected {
                Text("Sala: \(session.roomCode)").bold()
                Text(session.isHost ? "Eres anfitrión" : "Eres invitado")
                Button("Emitir estado actual") { session.broadcastState() }
                Button("Salir", role: .destructive) { session.leave() }
            } else {
                Button("Crear sala") { session.createRoom(username: s.listenTogetherUsername.isEmpty ? "iOS" : s.listenTogetherUsername) }
                TextField("Código de sala", text: $room)
                Button("Unirse") { session.join(room: room, username: s.listenTogetherUsername.isEmpty ? "iOS" : s.listenTogetherUsername) }
            }
        }.navigationTitle("Listen together")
    }
}
