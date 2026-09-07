import Foundation

enum NotebookMusic: String, CaseIterable {
    case cover, surface, depths, seam, night, restored
}

enum NotebookSound: String, CaseIterable {
    case step1 = "step_1", step2 = "step_2", step3 = "step_3"
    case paint, erase, erased, pigment, pickup, chest, build
    case fireLight = "fire_light", pageTurn = "page_turn"
    case talk, uiTap = "ui_tap", denied, eat, rest, memory, hurt, respawn

    var minimumInterval: TimeInterval {
        switch self {
        case .hurt: return 1.1
        case .denied: return 0.5
        case .uiTap, .talk: return 0.08
        default: return 0.10
        }
    }

    var gain: Float {
        switch self {
        case .step1, .step2, .step3: return 0.48
        case .uiTap, .denied: return 0.52
        case .hurt: return 0.7
        default: return 0.85
        }
    }
}

enum NotebookAmbience: String, CaseIterable {
    case fire, ink, nightAir = "night_air"
}

enum NotebookAudioBus: String, CaseIterable {
    case music, effects, ambience

    var title: String {
        switch self {
        case .music: return "Musica"
        case .effects: return "Efectos"
        case .ambience: return "Ambiente"
        }
    }

    var defaultVolume: Float {
        switch self {
        case .music: return 0.5
        case .effects: return 0.75
        case .ambience: return 0.5
        }
    }
}

struct NotebookAmbientLevel: Equatable {
    var gain: Float
    var pan: Float = 0
}

struct NotebookSoundscape: Equatable {
    var music: NotebookMusic
    var ambience: [NotebookAmbience: NotebookAmbientLevel] = [:]

    static let cover = Self(music: .cover)

    static func adventure(_ engine: AdventureEngine) -> Self {
        let music: NotebookMusic
        if !engine.save.introSeen { music = .cover }
        else if engine.isCompleted { music = .restored }
        else if engine.isNight { music = .night }
        else if engine.page.depth == 2 { music = .seam }
        else if engine.page.depth == 1 { music = .depths }
        else { music = .surface }
        var result = Self(music: music)
        guard engine.save.introSeen else { return result }
        let x = engine.save.x
        let y = engine.save.y
        if let fire = engine.save.builds.filter({
            $0.pageID == engine.page.id && $0.kind == .campfire && $0.fuel > 0
        }).min(by: {
            hypot(Double($0.point.x) - x, Double($0.point.y) - y) <
                hypot(Double($1.point.x) - x, Double($1.point.y) - y)
        }) {
            let distance = hypot(Double(fire.point.x) - x, Double(fire.point.y) - y)
            result.ambience[.fire] = NotebookAmbientLevel(gain: Float(max(0, 1 - distance / 6)),
                                                         pan: Float(max(-0.65, min(0.65, (Double(fire.point.x) - x) / 8))))
        }
        if !engine.isCompleted {
            let stainDistance = engine.inkTiles.map { hypot(Double($0.x) - x, Double($0.y) - y) }.min() ?? 10
            let creatureDistance = engine.save.creatures.filter {
                $0.pageID == engine.page.id && $0.remaining > 0
            }.map { hypot($0.x - x, $0.y - y) }.min() ?? 10
            let distance = min(stainDistance, creatureDistance)
            result.ambience[.ink] = NotebookAmbientLevel(gain: Float(max(0, 1 - distance / 5)) * 0.65)
            result.ambience[.nightAir] = NotebookAmbientLevel(gain: engine.isNight ? 0.55 : 0)
        }
        return result
    }
}

/// The stride matches half of NibAnimator's four-frame walk cycle.
struct NotebookFootsteps {
    private var distance = 0.0
    private var variant = 0

    mutating func advance(distance moved: Double) -> NotebookSound? {
        guard moved.isFinite, moved >= 0, moved < 1 else {
            reset()
            return nil
        }
        guard moved > 0.00001 else { return nil }
        distance += moved
        guard distance >= 0.68 else { return nil }
        distance.formTruncatingRemainder(dividingBy: 0.68)
        let sounds: [NotebookSound] = [.step1, .step2, .step3]
        let sound = sounds[variant % sounds.count]
        variant += 1
        return sound
    }

    mutating func reset() { distance = 0 }
}
