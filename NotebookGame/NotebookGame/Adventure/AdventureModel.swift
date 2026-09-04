import Foundation

enum Pigment: String, Codable, CaseIterable {
    case brown, green, yellow, red, blue, violet

    var title: String {
        switch self {
        case .brown: return "Marron"
        case .green: return "Verde"
        case .yellow: return "Amarillo"
        case .red: return "Rojo"
        case .blue: return "Azul"
        case .violet: return "Violeta"
        }
    }
}

struct PagePoint: Codable, Hashable {
    var x: Int
    var y: Int
}

enum AdventureObjectKind: String, Codable {
    case pigment, chest, tree, berries, scraps, npc, gate, memory, inkwell, rock
}

struct AdventureObject: Identifiable {
    let id: String
    let kind: AdventureObjectKind
    let point: PagePoint
    let name: String
    let pigment: Pigment?
    let art: String
    let folder: String
    let lines: [String]
    let targetPage: String?
    let targetPoint: PagePoint?
    let requiredFlag: String?

    init(id: String, kind: AdventureObjectKind, point: PagePoint, name: String,
         pigment: Pigment? = nil, art: String = "signpost", folder: String = "props",
         lines: [String] = [], targetPage: String? = nil, targetPoint: PagePoint? = nil,
         requiredFlag: String? = nil) {
        self.id = id
        self.kind = kind
        self.point = point
        self.name = name
        self.pigment = pigment
        self.art = art
        self.folder = folder
        self.lines = lines
        self.targetPage = targetPage
        self.targetPoint = targetPoint
        self.requiredFlag = requiredFlag
    }
}

struct AdventurePage: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let number: Int
    let depth: Int
    let width: Int
    let height: Int
    let spawn: PagePoint
    let objects: [AdventureObject]
    let inkSources: [PagePoint]
    let blocked: Set<PagePoint>
    let flavor: String
}

enum BuildKind: String, Codable, CaseIterable {
    case wall, path, campfire, shelter

    var title: String {
        switch self {
        case .wall: return "Pared"
        case .path: return "Camino"
        case .campfire: return "Hoguera"
        case .shelter: return "Refugio"
        }
    }
}

struct PlacedBuild: Codable, Identifiable, Equatable {
    var id: String
    var pageID: String
    var point: PagePoint
    var kind: BuildKind
    var fuel: Double
}

struct InkCreature: Codable, Identifiable, Equatable {
    var id: String
    var pageID: String
    var x: Double
    var y: Double
    var remaining: Double
}

struct AdventureEvent {
    var title: String
    var lines: [String]
    var changedPage: Bool = false
    var color: Pigment? = nil
    var success: Bool = true
}

struct AdventureSave: Codable, Equatable {
    var version = 2
    var pageID = "margin"
    var x = 10.0
    var y = 11.0
    var colors: Set<Pigment> = []
    var painted: Set<String> = []
    var collected: Set<String> = []
    var flags: Set<String> = []
    var visited: Set<String> = ["margin"]
    var scraps = 8
    var wood = 0
    var food = 3
    var integrity = 100.0
    var hunger = 100.0
    var warmth = 100.0
    var elapsed = 0.0
    var builds: [PlacedBuild] = []
    var creatures: [InkCreature] = []
    var ink: [String: Set<PagePoint>] = [:]
    var eraserLevel = 0
    var introSeen = false
    var endingSeen = false
    var checkpointPage = "margin"
    var checkpoint = PagePoint(x: 10, y: 11)
    var facing = PagePoint(x: 0, y: -1)
    var harvestedDay: [String: Int] = [:]
    var nextInkAt = 12.0
    var nextCreatureAt = 20.0
    var nextEraseAt = 0.0
    var simulationRemainder = 0.0
    var sequence = 0

    static var fresh: Self { Self() }
    init() {}

    enum CodingKeys: String, CodingKey {
        case version, pageID, x, y, colors, painted, collected, flags, visited
        case scraps, wood, food, integrity, hunger, warmth, elapsed, builds, creatures, ink
        case eraserLevel, introSeen, endingSeen, checkpointPage, checkpoint, facing
        case harvestedDay, nextInkAt, nextCreatureAt, nextEraseAt, simulationRemainder, sequence
    }

    init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? version
        pageID = try c.decodeIfPresent(String.self, forKey: .pageID) ?? pageID
        x = try c.decodeIfPresent(Double.self, forKey: .x) ?? x
        y = try c.decodeIfPresent(Double.self, forKey: .y) ?? y
        colors = try c.decodeIfPresent(Set<Pigment>.self, forKey: .colors) ?? colors
        painted = try c.decodeIfPresent(Set<String>.self, forKey: .painted) ?? painted
        collected = try c.decodeIfPresent(Set<String>.self, forKey: .collected) ?? collected
        flags = try c.decodeIfPresent(Set<String>.self, forKey: .flags) ?? flags
        visited = try c.decodeIfPresent(Set<String>.self, forKey: .visited) ?? [pageID]
        scraps = try c.decodeIfPresent(Int.self, forKey: .scraps) ?? scraps
        wood = try c.decodeIfPresent(Int.self, forKey: .wood) ?? wood
        food = try c.decodeIfPresent(Int.self, forKey: .food) ?? food
        integrity = try c.decodeIfPresent(Double.self, forKey: .integrity) ?? integrity
        hunger = try c.decodeIfPresent(Double.self, forKey: .hunger) ?? hunger
        warmth = try c.decodeIfPresent(Double.self, forKey: .warmth) ?? warmth
        elapsed = try c.decodeIfPresent(Double.self, forKey: .elapsed) ?? elapsed
        builds = try c.decodeIfPresent([PlacedBuild].self, forKey: .builds) ?? builds
        creatures = try c.decodeIfPresent([InkCreature].self, forKey: .creatures) ?? creatures
        ink = try c.decodeIfPresent([String: Set<PagePoint>].self, forKey: .ink) ?? ink
        eraserLevel = try c.decodeIfPresent(Int.self, forKey: .eraserLevel) ?? eraserLevel
        introSeen = try c.decodeIfPresent(Bool.self, forKey: .introSeen) ?? introSeen
        endingSeen = try c.decodeIfPresent(Bool.self, forKey: .endingSeen) ?? endingSeen
        checkpointPage = try c.decodeIfPresent(String.self, forKey: .checkpointPage) ?? checkpointPage
        checkpoint = try c.decodeIfPresent(PagePoint.self, forKey: .checkpoint) ?? checkpoint
        facing = try c.decodeIfPresent(PagePoint.self, forKey: .facing) ?? facing
        harvestedDay = try c.decodeIfPresent([String: Int].self, forKey: .harvestedDay) ?? harvestedDay
        nextInkAt = try c.decodeIfPresent(Double.self, forKey: .nextInkAt) ?? elapsed + 12
        nextCreatureAt = try c.decodeIfPresent(Double.self, forKey: .nextCreatureAt) ?? elapsed + 20
        nextEraseAt = try c.decodeIfPresent(Double.self, forKey: .nextEraseAt) ?? elapsed
        simulationRemainder = try c.decodeIfPresent(Double.self, forKey: .simulationRemainder) ?? 0
        sequence = try c.decodeIfPresent(Int.self, forKey: .sequence) ?? 0
    }
}
