import Foundation

/// What a single cell of the world is made of.
enum Ground: Character {
    case paper = "."
    case path = ","
    case sand = "s"
    case stone = "#"
    case water = "~"

    var textureName: String {
        switch self {
        case .paper: return "paper"
        case .path: return "path"
        case .sand: return "sand"
        case .stone: return "stone"
        case .water: return "water"
        }
    }

    var blocksMovement: Bool { self == .water }

    /// Stone is the floor of camps and shops, where monsters do not spawn.
    var isSafe: Bool { self == .stone }
}

/// Scenery drawn on top of the ground. Some of it blocks the player.
enum Prop: Character, CaseIterable {
    case none = " "
    case pineTree = "T"
    case roundTree = "t"
    case largeRock = "R"
    case smallRock = "r"
    case grass = "g"
    case bush = "b"
    case cactus = "c"
    case stump = "S"
    case flower = "f"
    case skull = "k"
    case campfire = "C"
    case inkwell = "i"
    case signpost = "p"

    var textureName: String? {
        switch self {
        case .none: return nil
        case .pineTree: return "tree_pine"
        case .roundTree: return "tree_round"
        case .largeRock: return "rock_large"
        case .smallRock: return "rock_small"
        case .grass: return "grass_tuft"
        case .bush: return "bush"
        case .cactus: return "cactus"
        case .stump: return "stump"
        case .flower: return "flower"
        case .skull: return "skull"
        case .campfire: return "campfire"
        case .inkwell: return "inkwell"
        case .signpost: return "signpost"
        }
    }

    var blocksMovement: Bool {
        switch self {
        case .none, .smallRock, .grass, .flower, .skull:
            return false
        case .pineTree, .roundTree, .largeRock, .bush, .cactus, .stump, .campfire, .inkwell, .signpost:
            return true
        }
    }

    /// How tall the prop is drawn, as a multiple of the tile size.
    var scale: CGFloat {
        switch self {
        case .pineTree, .roundTree: return 1.9
        case .largeRock, .stump, .cactus, .bush: return 1.25
        case .campfire, .inkwell, .signpost: return 1.1
        case .smallRock, .grass, .flower, .skull: return 0.6
        case .none: return 1
        }
    }
}

/// A person or object the player can talk to.
struct NPCDef {
    var id: String
    var spriteName: String
    var spriteFolder: String = "npcs"
    var x: Int
    var y: Int
    var scale: CGFloat = 1.4
    var lines: [String]
    /// Opens the vendor cart interface after the dialogue finishes.
    var opensShop: Bool = false
    /// Fully restores the party after the dialogue finishes.
    var restores: Bool = false
    /// Starts the final battle after the dialogue finishes.
    var bossID: String?
    /// Only appears when this flag is *absent*.
    var hiddenWhenFlag: String?
}

/// A walkable tile that moves the player to another map.
struct ExitDef {
    var x: Int
    var y: Int
    var targetMap: String
    var targetX: Int
    var targetY: Int
    var label: String
}

/// A one-time pickup.
struct ChestDef {
    var id: String
    var x: Int
    var y: Int
    var itemID: String?
    var equipmentID: String?
    var coins: Int = 0
}

struct MapDef {
    var id: String
    var name: String
    /// Rows are written top-down for readability and flipped when loaded.
    var groundRows: [String]
    var propRows: [String]
    var encounterPool: [String]
    /// Chance per tile stepped onto.
    var encounterRate: Double
    var npcs: [NPCDef] = []
    var exits: [ExitDef] = []
    var chests: [ChestDef] = []

    var width: Int { groundRows.map(\.count).max() ?? 0 }
    var height: Int { groundRows.count }
}

enum MapCatalog {

    // MARK: - Page one

    static let pencilPlains = MapDef(
        id: "pencil_plains",
        name: "Pencil Plains",
        groundRows: [
            "........................",
            "..#####.................",
            "..#####....,,,,.........",
            "..#####...,,,,,,........",
            "...,,,,,,,,....,,,......",
            "....,,,,........,,,.....",
            ".....,,..........,,,....",
            "....,,,...........,,,...",
            "...,,,.............,,,..",
            "..,,,...............,,,.",
            "..,,,................###",
            "...,,,...............###",
            "....,,,,.............###",
            "......,,,,..............",
            "........,,,,............",
            "........................"
        ],
        propRows: [
            "  T t   g    r   g    T ",
            "       f      g     t   ",
            "       r        g    r  ",
            "     b       g       g  ",
            "   r           r     b  ",
            " g    r      b      g   ",
            "    b     g       f     ",
            " R      f      g     r  ",
            "   g        b      g    ",
            " t     g        r     b ",
            "     r      g          i",
            "  b      f       g      ",
            " g    S       b       r ",
            "   f      g       t     ",
            " r     b       g     g  ",
            "  T  t    g   r    b  T "
        ],
        encounterPool: ["scribble", "ink_slime", "scribble", "eraser_bug"],
        encounterRate: 0.075,
        npcs: [
            NPCDef(id: "inkwell", spriteName: "old_inkwell", x: 4, y: 13, scale: 2.6,
                   lines: [
                    "The old inkwell sloshes awake.",
                    "\"Welcome to the page, little doodle.\"",
                    "\"A Smudge is spreading. It eats everything we draw.\"",
                    "\"Take some of me with you. Head east.\""
                   ]),
            NPCDef(id: "camp", spriteName: "campfire", spriteFolder: "props", x: 3, y: 11, scale: 1.2,
                   lines: ["You warm your ink by the fire.", "Health and ink fully restored."],
                   restores: true),
            NPCDef(id: "vendor", spriteName: "pencil_case_stall", x: 21, y: 5, scale: 2.0,
                   lines: ["\"Everything a doodle needs, all zipped up.\"", "\"Have a browse.\""],
                   opensShop: true),
            NPCDef(id: "elder", spriteName: "bench_elder", x: 20, y: 4, scale: 1.5,
                   lines: [
                    "\"Ink is your magic. Spend it wisely.\"",
                    "\"Tap SKILL in a scrap to use it.\""
                   ])
        ],
        exits: [
            ExitDef(x: 23, y: 6, targetMap: "eraser_desert", targetX: 1, targetY: 8,
                    label: "To the Eraser Desert")
        ],
        chests: [
            ChestDef(id: "plains_chest_1", x: 2, y: 6, itemID: "patch", coins: 25),
            ChestDef(id: "plains_chest_2", x: 18, y: 14, equipmentID: "sharp_pencil")
        ]
    )

    // MARK: - Page two

    static let eraserDesert = MapDef(
        id: "eraser_desert",
        name: "Eraser Desert",
        groundRows: [
            "ssssssssssssssssssssssss",
            "sssssss~~~~sssssssssssss",
            "ssssss~~~~~~ssssssssssss",
            "sssss~~~~~~~~sssssssssss",
            "ssss,,,,,,,,,,,,,,,,ssss",
            "sss,,,ssssssssssss,,,sss",
            ",,,,,ssssssssssssss,,,,,",
            "sssssssssssssssssss,,,ss",
            ",,,,,,,,ssssssssss,,,sss",
            "sssssss,,,,,,,,,,,,sssss",
            "ssssssssssss,,,,ssssssss",
            "sssssssss###ssssssssssss",
            "sssssssss###ssssssssssss",
            "sssssssss###ssssssssssss",
            "ssssssssssssssssssssssss",
            "ssssssssssssssssssssssss"
        ],
        propRows: [
            " c   k    c     k    c  ",
            "   r        c      r    ",
            " k     c        k     c ",
            "    c      r        r   ",
            " R      k       c     R ",
            "   c        r      k    ",
            "      k        c       c",
            " c        R        k    ",
            "     c        r      c  ",
            " k       c        R     ",
            "   R        k       c   ",
            " c     k   R   r      k ",
            "    c              c    ",
            " k       R      k     c ",
            "   c        c      r    ",
            " R   k    c    k    c  R"
        ],
        encounterPool: ["eraser_bug", "doodle_bat", "clip_crab", "ink_slime", "eraser_bug"],
        encounterRate: 0.095,
        npcs: [
            NPCDef(id: "desert_camp", spriteName: "campfire", spriteFolder: "props",
                   x: 11, y: 4, scale: 1.2,
                   lines: ["A traveller's fire, still warm.", "Health and ink fully restored."],
                   restores: true),
            NPCDef(id: "hiker", spriteName: "hiker", x: 16, y: 9, scale: 1.4,
                   lines: [
                    "\"Phew. Long walk.\"",
                    "\"The woods past the dunes have gone dark.\"",
                    "\"That's where it lives. The Big Smudge.\""
                   ])
        ],
        exits: [
            ExitDef(x: 0, y: 9, targetMap: "pencil_plains", targetX: 22, targetY: 6,
                    label: "Back to Pencil Plains"),
            ExitDef(x: 23, y: 7, targetMap: "inkwell_woods", targetX: 1, targetY: 8,
                    label: "Into the Inkwell Woods")
        ],
        chests: [
            ChestDef(id: "desert_chest_1", x: 2, y: 2, itemID: "big_patch", coins: 60),
            ChestDef(id: "desert_chest_2", x: 21, y: 13, equipmentID: "cover_shield")
        ]
    )

    // MARK: - Page three

    static let inkwellWoods = MapDef(
        id: "inkwell_woods",
        name: "Inkwell Woods",
        groundRows: [
            "........................",
            "........................",
            "....######..............",
            "....######..............",
            "....######..............",
            "..,,,,,,,,,,,,,,........",
            "..,,,,,,,,,,,,,,,,,,....",
            "..,,,,,,,,,,,,,,,,,,,,,,",
            ",,,,,,,,,,,,,,,,,,,,,,,,",
            "..,,,,,,,,,,,,,,,,,,,,,,",
            "........,,,,,,,,,,,,,,,,",
            "..............,,,,,,####",
            "...................#####",
            "...................#####",
            "........................",
            "........................"
        ],
        propRows: [
            "T t T t T t T t T t T t ",
            " T t T   b   t T   t T t",
            " t T          T t T   t ",
            "T          i        T t ",
            " T t          t T   t T ",
            "T   b     g      b    t ",
            " t     S      g     T   ",
            "T   g      b      S    t",
            "     b        g       T ",
            "T      g   S      b    t",
            " t T      g     T    t T",
            "T t T t T t T t T       ",
            " T t T t T t T t T      ",
            "T t T t T t T t T t     ",
            " T t T t T t T t T t T t",
            "T t T t T t T t T t T t "
        ],
        encounterPool: ["smudge", "clip_crab", "doodle_bat", "smudge", "eraser_bug"],
        encounterRate: 0.11,
        npcs: [
            NPCDef(id: "woods_camp", spriteName: "campfire", spriteFolder: "props",
                   x: 6, y: 3, scale: 1.2,
                   lines: ["The last safe fire on the page.", "Health and ink fully restored."],
                   restores: true),
            NPCDef(id: "boss", spriteName: "big_smudge", spriteFolder: "enemies",
                   x: 21, y: 12, scale: 3.2,
                   lines: [
                    "The page goes grey.",
                    "\"YOU. LITTLE. DOODLE.\"",
                    "\"I will smudge you into nothing.\""
                   ],
                   bossID: "big_smudge",
                   hiddenWhenFlag: GameState.Flag.bossDefeated)
        ],
        exits: [
            ExitDef(x: 0, y: 8, targetMap: "eraser_desert", targetX: 22, targetY: 8,
                    label: "Back to the Eraser Desert")
        ],
        chests: [
            ChestDef(id: "woods_chest_1", x: 6, y: 12, itemID: "ink_vial", coins: 90),
            ChestDef(id: "woods_chest_2", x: 12, y: 9, equipmentID: "fountain_pen"),
            ChestDef(id: "woods_chest_3", x: 20, y: 10, equipmentID: "hard_cover")
        ]
    )

    static let all: [MapDef] = [pencilPlains, eraserDesert, inkwellWoods]

    static func map(id: String) -> MapDef {
        all.first { $0.id == id } ?? pencilPlains
    }
}
