import Foundation
import SwiftUI
import SwiftData
import MediaPlayer
import Combine

@MainActor
final class SessionController: ObservableObject {
    enum Phase { case idle, active, finished }

    @Published var phase: Phase = .idle
    @Published var startDate: Date?
    @Published var endDate: Date?
    @Published var pickedTracks: [AudioTrack] = []
    @Published var playlistName: String = ""
    @Published var lastSummary: SleepSession?
    @Published var currentScore: Double = 0
    @Published var statusLabel: String = "—"

    let heart: HeartRateService
    let audio: AudioEngineService
    let settings: AppSettings

    private var pickedItems: [MPMediaItem] = []
    private var tickTimer: Timer?
    private var modelContext: ModelContext?
    private var samplesObserver: AnyCancellable?
    private var silenceSince: Date?

    init(heart: HeartRateService = HeartRateService(),
         audio: AudioEngineService = AudioEngineService(),
         settings: AppSettings = .shared) {
        self.heart = heart
        self.audio = audio
        self.settings = settings
        observeSamples()
    }

    func bind(_ context: ModelContext) {
        self.modelContext = context
    }

    private func observeSamples() {
        samplesObserver = heart.$samples
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.recompute() }
    }

    private func recompute() {
        let s = RelaxationCalculator.score(samples: heart.samples, basalHR: settings.basalHR)
        currentScore = s
        statusLabel = RelaxationCalculator.statusLabel(score: s)
        if phase == .active {
            applyVolume(score: s)
        }
    }

    // MARK: - Music selection

    func setPicked(items: [MPMediaItem]) {
        pickedItems = items
        pickedTracks = items.map {
            AudioTrack(
                title: $0.title ?? "Sin título",
                artist: $0.artist ?? "",
                persistentID: $0.persistentID,
                duration: $0.playbackDuration
            )
        }
        playlistName = items.count == 1
            ? (items.first?.title ?? "Pista")
            : "\(items.count) pistas"
        settings.lastPlaylistName = playlistName
    }

    // MARK: - Session lifecycle

    func start() {
        guard phase != .active else { return }
        let now = Date()
        startDate = now
        endDate = nil
        phase = .active
        silenceSince = nil

        heart.startMonitoring(from: now)

        if !pickedItems.isEmpty {
            audio.loadAppleMusic(items: pickedItems)
            audio.setVolume(1.0, fadeDuration: 0)
            audio.play()
        }

        scheduleAlarmIfNeeded()
        startTick()
    }

    func stop(autoFromSilence: Bool = false) {
        guard phase == .active else { return }
        let now = Date()
        endDate = now
        tickTimer?.invalidate()
        tickTimer = nil

        // Soft fade-out then full stop
        audio.setVolume(0, fadeDuration: 4)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            self.audio.stop()
        }

        heart.stopMonitoring()
        persistSession(start: startDate ?? now, end: now)
        phase = .finished
    }

    private func startTick() {
        tickTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func tick() {
        guard phase == .active else { return }
        recompute()
        // Auto-stop guard rails
        if let start = startDate {
            let elapsed = Date().timeIntervalSince(start)
            if elapsed > Double(settings.maxSessionMinutes) * 60 {
                stop(autoFromSilence: true)
                return
            }
        }
        if audio.currentVolume < 0.04 {
            if silenceSince == nil { silenceSince = Date() }
            else if let since = silenceSince,
                    Date().timeIntervalSince(since) > settings.fadeOutAfterSilenceSeconds {
                audio.pause()
            }
        } else {
            silenceSince = nil
        }
    }

    private func applyVolume(score: Double) {
        let target = RelaxationCalculator.targetVolume(score: score)
        audio.setVolume(target, fadeDuration: 8)
    }

    // MARK: - Persistence

    private func persistSession(start: Date, end: Date) {
        guard let ctx = modelContext else { return }
        let onset = RelaxationCalculator.sleepOnsetMinute(samples: heart.samples, basalHR: settings.basalHR)
        let session = SleepSession(
            startDate: start,
            playlistName: playlistName.isEmpty ? "Sin playlist" : playlistName,
            trackTitles: pickedTracks.map(\.title),
            basalHR: settings.basalHR
        )
        session.endDate = end
        session.estimatedSleepOnsetMinutes = onset
        session.hrSamples = heart.samples
        session.minHR = heart.samples.map(\.value).min()
        session.maxHR = heart.samples.map(\.value).max()
        ctx.insert(session)
        try? ctx.save()
        lastSummary = session
    }

    func dismissSummary() {
        phase = .idle
        startDate = nil
        endDate = nil
        lastSummary = nil
    }

    // MARK: - Alarm

    private func scheduleAlarmIfNeeded() {
        guard settings.alarmEnabled else { return }
        Task {
            _ = await NotificationService.requestAuthorization()
            await NotificationService.scheduleAlarm(
                hour: settings.alarmHour,
                minute: settings.alarmMinute
            )
        }
    }

    // MARK: - URL Scheme

    func handleURL(_ url: URL) {
        guard url.scheme == "sleepflow" else { return }
        switch url.host {
        case "start":
            if phase != .active { start() }
        case "stop":
            if phase == .active { stop() }
        default:
            break
        }
    }
}
