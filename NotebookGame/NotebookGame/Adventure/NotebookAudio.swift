import AVFoundation
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

enum NotebookAudioLoop: Hashable {
    case music(NotebookMusic)
    case ambience(NotebookAmbience)

    var path: String {
        switch self {
        case .music(let music): return "music/\(music.rawValue)"
        case .ambience(let ambience): return "ambience/\(ambience.rawValue)"
        }
    }

    var bus: NotebookAudioBus {
        switch self {
        case .music: return .music
        case .ambience: return .ambience
        }
    }
}

protocol NotebookAudioOutput: AnyObject {
    var onFailure: ((Error) -> Void)? { get set }
    func activate() throws
    func deactivate() throws
    func prepareEffects() throws
    func loop(_ loop: NotebookAudioLoop, gain: Float, pan: Float) throws
    func stop(_ loop: NotebookAudioLoop)
    func pause()
    func sound(_ sound: NotebookSound, gain: Float, pan: Float, rate: Float) throws
    func effectsVolume(_ volume: Float)
    func reset()
}

/// A single audio owner survives scene changes; no scene can leave a second
/// soundtrack behind. Its clocks never advance the game simulation.
final class NotebookAudio {
    static let shared = NotebookAudio()

    enum Suspension: Hashable { case inactive, interruption, routeChange, preview }

    private let output: NotebookAudioOutput
    private let defaults: UserDefaults
    private let clock: () -> TimeInterval
    private var timer: Timer?
    private var observations: [NSObjectProtocol] = []
    private var suspensions: Set<Suspension> = []
    private var lastPlayed: [NotebookSound: TimeInterval] = [:]
    private var weights: [NotebookAudioLoop: Float] = [:]
    private var volumes: [NotebookAudioBus: Float] = [:]
    private var lastMixTime: TimeInterval?
    private var sessionActive = false
    private var configured = false
    private var effectsPrepared = false
    private var failureLatched = false
    private var otherMusicPlaying = false
    private var context: NotebookSoundscape = .cover
    private var reading = false
    private(set) var lastError: String?

    var isSuspended: Bool { !suspensions.isEmpty }
    var needsResume: Bool { suspensions.contains(.routeChange) || suspensions.contains(.interruption) }
    var currentMusic: NotebookMusic { context.music }
    var activeLoopCount: Int { weights.count }

    init(output: NotebookAudioOutput = NotebookAVAudioOutput(),
         defaults: UserDefaults = .standard,
         clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         automaticUpdates: Bool = true) {
        self.output = output
        self.defaults = defaults
        self.clock = clock
        for bus in NotebookAudioBus.allCases {
            let stored = (defaults.object(forKey: Self.key(bus)) as? NSNumber)?.floatValue
            volumes[bus] = stored.flatMap { $0.isFinite ? min(1, max(0, $0)) : nil } ?? bus.defaultVolume
        }
        output.onFailure = { [weak self] error in self?.report(error) }
        if automaticUpdates {
            observeLifecycle()
            timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.updateMix() }
            RunLoop.main.add(timer!, forMode: .common)
        }
    }

    deinit {
        timer?.invalidate()
        observations.forEach(NotificationCenter.default.removeObserver)
        output.reset()
    }

    private static func key(_ bus: NotebookAudioBus) -> String { "notebook.audio.\(bus.rawValue)" }

    func volume(_ bus: NotebookAudioBus) -> Float { volumes[bus] ?? bus.defaultVolume }

    func cycleVolume(_ bus: NotebookAudioBus) {
        let current = volume(bus)
        let next = current >= 0.99 ? 0 : min(1, Float(Int((current + 0.001) * 4) + 1) / 4)
        setVolume(next, for: bus)
    }

    func setVolume(_ value: Float, for bus: NotebookAudioBus) {
        guard value.isFinite else {
            report(AudioError.invalidVolume)
            return
        }
        volumes[bus] = min(1, max(0, value))
        defaults.set(volume(bus), forKey: Self.key(bus))
        if bus == .effects { output.effectsVolume(volume(bus)) }
        applyVolumes()
    }

    func setSoundscape(_ context: NotebookSoundscape, reading: Bool = false) {
        configured = true
        self.context = context
        self.reading = reading
        activateIfNeeded()
        updateMix()
    }

    func setReading(_ reading: Bool) {
        self.reading = reading
        applyVolumes()
    }

    func play(_ sound: NotebookSound, pan: Float = 0) {
        guard configured, !isSuspended, !failureLatched, volume(.effects) > 0 else { return }
        activateIfNeeded()
        guard sessionActive else { return }
        let now = clock()
        if let last = lastPlayed[sound], now - last < sound.minimumInterval { return }
        lastPlayed[sound] = now
        do {
            let variation: Float = [.step1, .step2, .step3].contains(sound) ? 1 + Float(lastPlayed.count % 3 - 1) * 0.025 : 1
            try output.sound(sound, gain: sound.gain * volume(.effects),
                             pan: min(1, max(-1, pan)), rate: variation)
        } catch { report(error) }
    }

    func suspend(_ reason: Suspension) {
        suspensions.insert(reason)
        output.pause()
        lastMixTime = nil
        if sessionActive {
            do { try output.deactivate() } catch { report(error) }
            sessionActive = false
        }
    }

    func resume(_ reason: Suspension) {
        suspensions.remove(reason)
        lastMixTime = nil
        activateIfNeeded()
        applyVolumes()
    }

    func retry() {
        suspensions.remove(.routeChange)
        suspensions.remove(.interruption)
        rebuildOutput()
    }

    func rebuildOutput() {
        lastError = nil
        failureLatched = false
        output.reset()
        sessionActive = false
        effectsPrepared = false
        weights.removeAll()
        lastPlayed.removeAll()
        activateIfNeeded()
        updateMix()
    }

    func updateMix() {
        guard configured, !isSuspended, sessionActive, !failureLatched else { return }
        let now = clock()
        let dt = Float(min(0.1, max(0, now - (lastMixTime ?? now))))
        lastMixTime = now
        let wanted = NotebookAudioLoop.music(context.music)
        if weights[wanted] == nil { weights[wanted] = 0 }
        // Fast navigation retains only the loudest outgoing music bed.
        let outgoing = weights.keys.filter { $0.bus == .music && $0 != wanted }
            .sorted { (weights[$0] ?? 0) > (weights[$1] ?? 0) }
        for loop in outgoing.dropFirst() {
            output.stop(loop)
            weights.removeValue(forKey: loop)
        }
        for (ambience, level) in context.ambience where level.gain > 0 {
            if weights[.ambience(ambience)] == nil { weights[.ambience(ambience)] = 0 }
        }
        for loop in Array(weights.keys) {
            let target: Float
            switch loop {
            case .music: target = loop == wanted ? 1 : 0
            case .ambience(let sound): target = context.ambience[sound]?.gain ?? 0
            }
            let previous = weights[loop] ?? 0
            let amount = dt / (loop.bus == .music ? 1.6 : 0.65)
            let weight = target > previous ? min(target, previous + amount) : max(target, previous - amount)
            if weight == 0 && target == 0 {
                weights.removeValue(forKey: loop)
                output.stop(loop)
            } else { weights[loop] = weight }
        }
        applyVolumes()
    }

    private func activateIfNeeded() {
        guard configured, !isSuspended, !sessionActive, !failureLatched else { return }
        do {
            try output.activate()
            sessionActive = true
            if !effectsPrepared {
                try output.prepareEffects()
                effectsPrepared = true
            }
            #if canImport(UIKit)
            otherMusicPlaying = AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
            #endif
        } catch { report(error) }
    }

    private func applyVolumes() {
        guard sessionActive, !isSuspended, !failureLatched else { return }
        do {
            for (loop, weight) in weights {
                let gain: Float
                let pan: Float
                switch loop {
                case .music:
                    gain = otherMusicPlaying ? 0 : weight * volume(.music) * (reading ? 0.62 : 1)
                    pan = 0
                case .ambience(let sound):
                    gain = weight * volume(.ambience) * (reading ? 0.25 : 1)
                    pan = context.ambience[sound]?.pan ?? 0
                }
                try output.loop(loop, gain: gain, pan: pan)
            }
        } catch { report(error) }
    }

    private func report(_ error: Error) {
        lastError = "No se pudo iniciar el audio. Puedes reintentarlo aqui."
        failureLatched = true
        output.pause()
        if sessionActive {
            do { try output.deactivate() }
            catch { NSLog("Notebook audio session cleanup failed: %@", error.localizedDescription) }
            sessionActive = false
        }
        NSLog("Notebook audio error: %@", error.localizedDescription)
    }

    private func observe(_ name: Notification.Name, _ callback: @escaping (Notification) -> Void) {
        observations.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main,
                                                                    using: callback))
    }

    private func observeLifecycle() {
        #if canImport(UIKit)
        observe(UIApplication.willResignActiveNotification) { [weak self] _ in self?.suspend(.inactive) }
        observe(UIApplication.didBecomeActiveNotification) { [weak self] _ in self?.resume(.inactive) }
        observe(AVAudioSession.interruptionNotification) { [weak self] notification in
            guard let self, let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            if type == .began { self.suspend(.interruption) }
            else {
                let flags = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                if AVAudioSession.InterruptionOptions(rawValue: flags).contains(.shouldResume) {
                    self.resume(.interruption)
                }
            }
        }
        observe(AVAudioSession.routeChangeNotification) { [weak self] notification in
            guard let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt else { return }
            if AVAudioSession.RouteChangeReason(rawValue: raw) == .oldDeviceUnavailable {
                self?.suspend(.routeChange)
            }
        }
        observe(AVAudioSession.silenceSecondaryAudioHintNotification) { [weak self] _ in
            self?.otherMusicPlaying = AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
            self?.applyVolumes()
        }
        observe(AVAudioSession.mediaServicesWereResetNotification) { [weak self] _ in self?.rebuildOutput() }
        #else
        observe(NSApplication.willResignActiveNotification) { [weak self] _ in self?.suspend(.inactive) }
        observe(NSApplication.didBecomeActiveNotification) { [weak self] _ in self?.resume(.inactive) }
        #endif
    }

    enum AudioError: LocalizedError {
        case invalidVolume, missing(String), playback(String)
        var errorDescription: String? {
            switch self {
            case .invalidVolume: return "Non-finite notebook audio volume"
            case .missing(let path): return "Missing audio asset: \(path)"
            case .playback(let path): return "Could not play audio: \(path)"
            }
        }
    }
}

final class NotebookAVAudioOutput: NSObject, NotebookAudioOutput, AVAudioPlayerDelegate {
    var onFailure: ((Error) -> Void)?
    private struct Voice {
        let player: AVAudioPlayer
        let sound: NotebookSound
        let relativeGain: Float
    }
    private var loops: [NotebookAudioLoop: AVAudioPlayer] = [:]
    private var effectPool: [NotebookSound: [AVAudioPlayer]] = [:]
    private var voices: [Voice] = []

    static func assetURL(_ path: String) throws -> URL {
        #if canImport(UIKit)
        guard let root = Bundle.main.resourceURL else { throw NotebookAudio.AudioError.missing(path) }
        let url = root.appendingPathComponent("assets/audio/\(path).wav")
        #else
        let root = ProcessInfo.processInfo.environment["NOTEBOOK_ASSETS"]
            ?? FileManager.default.currentDirectoryPath + "/assets"
        let url = URL(fileURLWithPath: root).appendingPathComponent("audio/\(path).wav")
        #endif
        guard FileManager.default.fileExists(atPath: url.path) else { throw NotebookAudio.AudioError.missing(path) }
        return url
    }

    func activate() throws {
        #if canImport(UIKit)
        // Respect the ring/silent switch and music the player already has playing.
        try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    func deactivate() throws {
        #if canImport(UIKit)
        try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    func prepareEffects() throws {
        for sound in NotebookSound.allCases {
            let data = try Data(contentsOf: Self.assetURL("effects/\(sound.rawValue)"))
            effectPool[sound] = try (0..<2).map { _ in
                let player = try AVAudioPlayer(data: data)
                player.delegate = self
                player.enableRate = true
                guard player.prepareToPlay() else { throw NotebookAudio.AudioError.playback(sound.rawValue) }
                return player
            }
        }
    }

    func loop(_ loop: NotebookAudioLoop, gain: Float, pan: Float) throws {
        if gain <= 0 {
            loops[loop]?.volume = 0
            loops[loop]?.pause()
            return
        }
        let player: AVAudioPlayer
        if let existing = loops[loop] { player = existing }
        else {
            player = try AVAudioPlayer(contentsOf: Self.assetURL(loop.path))
            player.delegate = self
            player.numberOfLoops = -1
            if loop.bus == .music, player.duration > 0,
               let reference = loops.filter({ $0.key.bus == .music }).max(by: {
                   $0.value.volume < $1.value.volume
               })?.value {
                // The six arrangements share a 48-second musical grid.
                player.currentTime = reference.currentTime.truncatingRemainder(dividingBy: player.duration)
            }
            guard player.prepareToPlay() else { throw NotebookAudio.AudioError.playback(loop.path) }
            loops[loop] = player
        }
        player.volume = gain
        player.pan = pan
        if !player.isPlaying, !player.play() { throw NotebookAudio.AudioError.playback(loop.path) }
    }

    func stop(_ loop: NotebookAudioLoop) { loops.removeValue(forKey: loop)?.stop() }

    func pause() {
        loops.values.forEach { $0.pause() }
        voices.forEach { $0.player.stop() }
        voices.removeAll()
    }

    func sound(_ sound: NotebookSound, gain: Float, pan: Float, rate: Float) throws {
        guard let players = effectPool[sound], let player = players.first(where: { !$0.isPlaying }) ?? players.first else {
            throw NotebookAudio.AudioError.missing("effects/\(sound.rawValue)")
        }
        player.stop()
        player.currentTime = 0
        voices.removeAll { !$0.player.isPlaying || $0.player === player }
        if voices.count >= 10 { voices.removeFirst().player.stop() }
        player.volume = gain
        player.pan = pan
        player.rate = rate
        guard player.play() else { throw NotebookAudio.AudioError.playback(sound.rawValue) }
        voices.append(Voice(player: player, sound: sound, relativeGain: sound.gain))
    }

    func effectsVolume(_ volume: Float) {
        if volume == 0 {
            voices.forEach { $0.player.stop() }
            voices.removeAll()
        } else {
            voices.forEach { $0.player.volume = $0.relativeGain * volume }
        }
    }

    func reset() {
        pause()
        loops.removeAll()
        effectPool.removeAll()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        onFailure?(error ?? NotebookAudio.AudioError.playback("decoder"))
    }
}
