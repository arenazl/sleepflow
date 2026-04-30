import Foundation
import AVFoundation
import MediaPlayer
import Combine

@MainActor
final class AudioEngineService: NSObject, ObservableObject {
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var currentTrackTitle: String?
    @Published private(set) var currentVolume: Float = 1.0
    @Published private(set) var queueLength: Int = 0
    @Published private(set) var hasMedia: Bool = false

    private var player: AVQueuePlayer?
    private var fadeTimer: Timer?
    private var loadedItems: [MPMediaItem] = []
    private var endObserver: NSObjectProtocol?
    private var fadeFromVolume: Float = 0
    private var fadeTargetVolume: Float = 0
    private var fadeStep: Int = 0
    private var fadeTotalSteps: Int = 0

    override init() {
        super.init()
        configureAudioSession()
    }

    deinit {
        fadeTimer?.invalidate()
        if let o = endObserver { NotificationCenter.default.removeObserver(o) }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("AVAudioSession activation error: \(error)")
        }
    }

    func loadAppleMusic(items: [MPMediaItem]) {
        let playableItems = items.filter { $0.assetURL != nil }
        guard !playableItems.isEmpty else { return }
        let avItems = playableItems.compactMap { item -> AVPlayerItem? in
            guard let url = item.assetURL else { return nil }
            return AVPlayerItem(url: url)
        }
        let queue = AVQueuePlayer(items: avItems)
        queue.actionAtItemEnd = .advance
        queue.volume = currentVolume
        player = queue
        loadedItems = playableItems
        queueLength = avItems.count
        currentTrackTitle = playableItems.first?.title ?? "Pista"
        hasMedia = true
        observeTrackChanges()
        updateNowPlaying()
    }

    func play() {
        player?.play()
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    func stop() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        player?.pause()
        player = nil
        loadedItems = []
        isPlaying = false
        currentTrackTitle = nil
        currentVolume = 1.0
        queueLength = 0
        hasMedia = false
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// Smoothly fade volume to `target` over `fadeDuration` seconds.
    func setVolume(_ target: Float, fadeDuration: TimeInterval) {
        let clamped = max(0, min(1, target))
        guard let player = player else { return }
        fadeTimer?.invalidate()

        if fadeDuration <= 0.05 {
            player.volume = clamped
            currentVolume = clamped
            return
        }

        fadeFromVolume = player.volume
        fadeTargetVolume = clamped
        fadeStep = 0
        fadeTotalSteps = max(1, Int(fadeDuration * 30))
        let stepInterval = fadeDuration / Double(fadeTotalSteps)

        let timer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] t in
            Task { @MainActor in
                self?.fadeTick(timer: t)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        fadeTimer = timer
    }

    private func fadeTick(timer: Timer) {
        guard let player = player else {
            timer.invalidate()
            fadeTimer = nil
            return
        }
        fadeStep += 1
        let progress = Float(fadeStep) / Float(fadeTotalSteps)
        let v = fadeFromVolume + (fadeTargetVolume - fadeFromVolume) * progress
        player.volume = v
        currentVolume = v
        if fadeStep >= fadeTotalSteps {
            player.volume = fadeTargetVolume
            currentVolume = fadeTargetVolume
            timer.invalidate()
            fadeTimer = nil
        }
    }

    private func observeTrackChanges() {
        if let o = endObserver { NotificationCenter.default.removeObserver(o) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                if player.items().count <= 1 {
                    let loop = self.loadedItems.compactMap { item -> AVPlayerItem? in
                        guard let url = item.assetURL else { return nil }
                        return AVPlayerItem(url: url)
                    }
                    for it in loop { player.insert(it, after: nil) }
                }
                if let curr = player.currentItem,
                   let asset = curr.asset as? AVURLAsset,
                   let match = self.loadedItems.first(where: { $0.assetURL == asset.url }) {
                    self.currentTrackTitle = match.title
                }
                self.updateNowPlaying()
            }
        }
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = currentTrackTitle ?? "SleepFlow"
        info[MPMediaItemPropertyArtist] = "SleepFlow"
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
