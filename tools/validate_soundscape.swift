import Foundation
import AVFoundation

final class RecordingAudioOutput: NotebookAudioOutput {
    var onFailure: ((Error) -> Void)?
    var loops: [NotebookAudioLoop: Float] = [:]
    var sounds: [NotebookSound] = []
    var activations = 0
    var prepares = 0
    var pauses = 0
    var failing = false
    var effectsGain: Float = 1

    func activate() throws {
        if failing { throw NotebookAudio.AudioError.playback("injected") }
        activations += 1
    }
    func deactivate() throws {}
    func prepareEffects() throws { prepares += 1 }
    func loop(_ loop: NotebookAudioLoop, gain: Float, pan: Float) throws {
        precondition((0...1).contains(gain) && (-1...1).contains(pan))
        loops[loop] = gain
    }
    func stop(_ loop: NotebookAudioLoop) { loops.removeValue(forKey: loop) }
    func pause() { pauses += 1 }
    func sound(_ sound: NotebookSound, gain: Float, pan: Float, rate: Float) throws {
        precondition(gain > 0 && gain <= 1)
        sounds.append(sound)
    }
    func effectsVolume(_ volume: Float) { effectsGain = volume }
    func reset() { loops.removeAll(); sounds.removeAll() }
}

@main
struct SoundscapeValidation {
    static var checks = 0
    static func expect(_ test: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        precondition(test(), message)
    }

    static func main() throws {
        var time: TimeInterval = 1
        let domain = "NotebookAudioValidation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let output = RecordingAudioOutput()
        let audio = NotebookAudio(output: output, defaults: defaults, clock: { time }, automaticUpdates: false)
        func advance(_ seconds: Double) {
            for _ in 0..<Int(seconds * 30) {
                time += 1.0 / 30
                audio.updateMix()
            }
        }
        expect(audio.volume(.music) == 0.5 && audio.volume(.effects) == 0.75, "Balanced first-run levels")
        audio.setSoundscape(.cover)
        advance(2)
        expect(output.activations == 1 && output.prepares == 1, "Session and effect pool initialize once")
        expect(abs((output.loops[.music(.cover)] ?? 0) - 0.5) < 0.001, "Cover music fades to saved volume")
        audio.setSoundscape(NotebookSoundscape(music: .surface))
        advance(0.5)
        expect(output.loops.count == 2 && (output.loops[.music(.cover)] ?? 0) > 0,
               "Scene transition crossfades instead of cutting off music")
        audio.setSoundscape(NotebookSoundscape(music: .night))
        expect(audio.activeLoopCount <= 2, "Fast scene changes cannot accumulate music players")
        advance(2)
        expect(output.loops.count == 1 && output.loops[.music(.night)] != nil, "Faded music players are released")
        audio.setReading(true)
        expect(abs((output.loops[.music(.night)] ?? 0) - 0.31) < 0.001, "Reading gently ducks music")
        audio.setReading(false)
        audio.setVolume(0, for: .music)
        expect(output.loops[.music(.night)] == 0, "Music mute takes effect immediately")
        audio.play(.paint)
        expect(output.sounds == [.paint], "Music mute does not mute effects")
        audio.play(.paint)
        expect(output.sounds.count == 1, "Duplicate touch events do not stack sound")
        time += 0.2
        audio.play(.paint)
        expect(output.sounds.count == 2, "A new action can play after its cooldown")
        audio.play(.hurt)
        time += 0.3
        audio.play(.hurt)
        expect(output.sounds.filter { $0 == .hurt }.count == 1, "Contact damage does not buzz every frame")
        audio.setVolume(0, for: .effects)
        audio.play(.erase)
        expect(output.effectsGain == 0 && !output.sounds.contains(.erase), "Effects mute silences current and future voices")
        audio.cycleVolume(.effects)
        expect(audio.volume(.effects) == 0.25, "Volume controls can restore a muted bus")
        let loaded = NotebookAudio(output: RecordingAudioOutput(), defaults: defaults, automaticUpdates: false)
        expect(loaded.volume(.music) == 0 && loaded.volume(.effects) == 0.25, "Volumes persist separately from the save")
        audio.suspend(.inactive)
        audio.suspend(.interruption)
        let soundCount = output.sounds.count
        audio.resume(.inactive)
        audio.play(.pickup)
        expect(audio.isSuspended && soundCount == output.sounds.count, "An active call prevents premature resume")
        audio.resume(.interruption)
        audio.play(.pickup)
        expect(!audio.isSuspended && output.sounds.count == soundCount + 1, "Resume works after all blockers clear")
        expect(output.prepares == 1, "Resume does not reload all effects")
        audio.suspend(.routeChange)
        expect(audio.needsResume, "Removing headphones exposes a resume control")
        audio.retry()
        expect(!audio.needsResume && !audio.isSuspended, "Explicit resume restores output")
        audio.suspend(.preview)
        audio.suspend(.inactive)
        audio.resume(.inactive)
        audio.retry()
        expect(audio.isSuspended, "Preview runs remain silent even after app activation or retry")

        let failure = RecordingAudioOutput()
        failure.failing = true
        let broken = NotebookAudio(output: failure, defaults: defaults, automaticUpdates: false)
        broken.setSoundscape(.cover)
        expect(broken.lastError != nil, "Audio errors are surfaced without crashing gameplay")
        failure.failing = false
        broken.retry()
        expect(broken.lastError == nil && failure.activations == 1, "Audio can recover after a startup failure")

        let engine = AdventureEngine()
        expect(NotebookSoundscape.adventure(engine).music == .cover, "Opening keeps the cover theme")
        engine.save.introSeen = true
        expect(NotebookSoundscape.adventure(engine).music == .surface, "Surface pages share exploration theme")
        engine.save.pageID = "reverse"
        expect(NotebookSoundscape.adventure(engine).music == .depths, "Depth changes arrangement")
        engine.save.pageID = "seam"
        expect(NotebookSoundscape.adventure(engine).music == .seam, "Deepest pages have their own arrangement")
        engine.save.elapsed = 170
        expect(NotebookSoundscape.adventure(engine).music == .night, "Night overrides depth mood")
        engine.save.x = 10
        engine.save.y = 11
        engine.save.builds = [
            PlacedBuild(id: "fire", pageID: "seam", point: PagePoint(x: 11, y: 11), kind: .campfire, fuel: 30)
        ]
        let nearby = NotebookSoundscape.adventure(engine)
        expect((nearby.ambience[.fire]?.gain ?? 0) > 0.8, "Nearby fire crackles")
        expect((nearby.ambience[.fire]?.pan ?? 0) > 0, "Fire is gently positioned in stereo")
        engine.save.builds[0].fuel = 0
        expect(NotebookSoundscape.adventure(engine).ambience[.fire] == nil, "Extinguished fire is silent")
        engine.save.ink["seam"] = []
        engine.save.creatures = [InkCreature(id: "nearby", pageID: "seam", x: 10.5, y: 11, remaining: 1)]
        expect((NotebookSoundscape.adventure(engine).ambience[.ink]?.gain ?? 0) > 0.5,
               "Approaching creatures are audible even away from an ink source")
        engine.save.creatures[0].pageID = "garden"
        expect(NotebookSoundscape.adventure(engine).ambience[.ink]?.gain == 0,
               "Enemies on another page are not audible")
        engine.save.flags.insert("restored")
        expect(NotebookSoundscape.adventure(engine).music == .restored
               && NotebookSoundscape.adventure(engine).ambience[.ink] == nil,
               "Restoration resolves the soundtrack and removes ink ambience")
        var steps = NotebookFootsteps()
        expect(steps.advance(distance: 0) == nil, "Standing still has no footsteps")
        expect(steps.advance(distance: 0.35) == nil, "Short movement accumulates distance")
        expect(steps.advance(distance: 0.35) == .step1, "First step follows actual distance")
        expect(steps.advance(distance: 0.68) == .step2 && steps.advance(distance: 0.68) == .step3,
               "Three soft footfalls alternate instead of a repeated sample")
        expect(steps.advance(distance: 5) == nil && steps.advance(distance: 0.1) == nil,
               "Teleporting resets the stride without a footstep burst")

        if CommandLine.arguments.contains("--policy-only") {
            print("Soundscape policy validation passed: \(checks) checks.")
            return
        }
        for path in NotebookMusic.allCases.map({ "music/\($0.rawValue)" })
            + NotebookSound.allCases.map({ "effects/\($0.rawValue)" })
            + NotebookAmbience.allCases.map({ "ambience/\($0.rawValue)" }) {
            let file = try AVAudioFile(forReading: NotebookAVAudioOutput.assetURL(path))
            expect(file.length > 0 && file.processingFormat.sampleRate >= 22050, "Playable audio \(path)")
            let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 2048)!
            try file.read(into: buffer)
            expect(buffer.frameLength > 0, "Native decoder reads \(path)")
        }
        if CommandLine.arguments.contains("--playback") {
            let live = NotebookAVAudioOutput()
            try live.activate()
            try live.prepareEffects()
            try live.loop(.music(.cover), gain: 0.08, pan: 0)
            for sound in NotebookSound.allCases {
                try live.sound(sound, gain: 0.15, pan: 0, rate: 1)
                Thread.sleep(forTimeInterval: 0.08)
            }
            live.pause()
            try live.loop(.music(.cover), gain: 0.08, pan: 0)
            Thread.sleep(forTimeInterval: 0.2)
            live.reset()
            try live.deactivate()
            expect(true, "Native audio session plays, pauses, resumes and releases all voices")
        }
        print("Soundscape validation passed: \(checks) checks, including native decoding, mix, mute, lifecycle and proximity.")
    }
}
