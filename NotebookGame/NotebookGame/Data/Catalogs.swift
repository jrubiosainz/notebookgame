import Foundation

/// A blueprint for a monster. `Bestiary` turns these into live `Combatant`s.
struct EnemyDef: Identifiable {
    var id: String
    var name: String
    var spriteName: String
    var stats: Stats
    var experienceReward: Int
    var coinReward: Int
    var skills: [Skill]
    var lootTable: [String]
    /// Rendered size in points at the widest dimension during battle.
    var battleScale: CGFloat

    func spawn() -> Combatant {
        Combatant(name: name,
                  stats: stats,
                  currentHP: stats.maxHP,
                  currentInk: stats.maxInk,
                  spriteName: spriteName,
                  spriteFolder: "enemies",
                  isHero: false,
                  skills: skills,
                  experienceReward: experienceReward,
                  coinReward: coinReward,
                  lootTable: lootTable)
    }
}

enum Bestiary {
    static let scribble = EnemyDef(
        id: "scribble", name: "Scribble", spriteName: "scribble",
        stats: Stats(maxHP: 18, maxInk: 0, attack: 6, defense: 2, speed: 5, luck: 2),
        experienceReward: 12, coinReward: 6,
        skills: [], lootTable: ["patch"], battleScale: 190)

    static let inkSlime = EnemyDef(
        id: "ink_slime", name: "Ink Slime", spriteName: "ink_slime",
        stats: Stats(maxHP: 24, maxInk: 0, attack: 7, defense: 4, speed: 3, luck: 1),
        experienceReward: 16, coinReward: 9,
        skills: [], lootTable: ["ink_vial", "patch"], battleScale: 180)

    static let eraserBug = EnemyDef(
        id: "eraser_bug", name: "Eraser Bug", spriteName: "eraser_bug",
        stats: Stats(maxHP: 30, maxInk: 0, attack: 9, defense: 7, speed: 4, luck: 2),
        experienceReward: 24, coinReward: 12,
        skills: [], lootTable: ["patch"], battleScale: 200)

    static let doodleBat = EnemyDef(
        id: "doodle_bat", name: "Doodle Bat", spriteName: "doodle_bat",
        stats: Stats(maxHP: 26, maxInk: 0, attack: 11, defense: 3, speed: 12, luck: 5),
        experienceReward: 28, coinReward: 14,
        skills: [], lootTable: ["ink_vial"], battleScale: 175)

    static let clipCrab = EnemyDef(
        id: "clip_crab", name: "Paperclip Crab", spriteName: "clip_crab",
        stats: Stats(maxHP: 44, maxInk: 0, attack: 13, defense: 11, speed: 5, luck: 3),
        experienceReward: 40, coinReward: 22,
        skills: [], lootTable: ["patch", "ink_vial"], battleScale: 210)

    static let smudge = EnemyDef(
        id: "smudge", name: "Smudge", spriteName: "smudge",
        stats: Stats(maxHP: 52, maxInk: 0, attack: 16, defense: 9, speed: 7, luck: 4),
        experienceReward: 52, coinReward: 30,
        skills: [], lootTable: ["big_patch"], battleScale: 205)

    static let bigSmudge = EnemyDef(
        id: "big_smudge", name: "The Big Smudge", spriteName: "big_smudge",
        stats: Stats(maxHP: 220, maxInk: 0, attack: 26, defense: 16, speed: 9, luck: 6),
        experienceReward: 400, coinReward: 250,
        skills: [], lootTable: ["big_patch", "big_patch"], battleScale: 340)

    static let all: [EnemyDef] = [
        scribble, inkSlime, eraserBug, doodleBat, clipCrab, smudge, bigSmudge
    ]

    static func definition(id: String) -> EnemyDef? {
        all.first { $0.id == id }
    }
}

enum ItemCatalog {
    static let all: [Item] = [
        Item(id: "patch", name: "Sticky Patch",
             blurb: "A scrap of paper. Restores 30 health.",
             effect: .restoreHP(30), iconName: "potion", price: 20),
        Item(id: "big_patch", name: "Big Patch",
             blurb: "A generous scrap. Restores 90 health.",
             effect: .restoreHP(90), iconName: "potion", price: 55),
        Item(id: "ink_vial", name: "Ink Vial",
             blurb: "A thimble of fresh ink. Restores 15 ink.",
             effect: .restoreInk(15), iconName: "ink_drop", price: 30),
        Item(id: "eraser_shard", name: "Eraser Shard",
             blurb: "A shard from a fallen bug. Proof of your travels.",
             effect: .keyItem, iconName: "star", price: 0,
             usableInBattle: false, usableOnMap: false)
    ]

    static func item(id: String) -> Item? { all.first { $0.id == id } }

    /// What the vendor cart sells.
    static let shopStock: [String] = ["patch", "big_patch", "ink_vial"]

    static var forSale: [Item] { shopStock.compactMap { item(id: $0) } }
}

enum EquipmentCatalog {
    static let all: [Equipment] = [
        Equipment(id: "stub_pencil", name: "Stub Pencil",
                  blurb: "Chewed, blunt, loyal.",
                  slot: .weapon,
                  bonus: Stats(maxHP: 0, maxInk: 0, attack: 0, defense: 0, speed: 0, luck: 0),
                  iconName: "pencil_sword", price: 0),
        Equipment(id: "sharp_pencil", name: "Sharpened Pencil",
                  blurb: "A fine point. Cuts cleanly through a Scribble.",
                  slot: .weapon,
                  bonus: Stats(maxHP: 0, maxInk: 0, attack: 6, defense: 0, speed: 1, luck: 0),
                  iconName: "pencil_sword", price: 120),
        Equipment(id: "fountain_pen", name: "Fountain Pen",
                  blurb: "Heavy, elegant, permanent.",
                  slot: .weapon,
                  bonus: Stats(maxHP: 0, maxInk: 6, attack: 14, defense: 0, speed: 0, luck: 2),
                  iconName: "pencil_sword", price: 320),
        Equipment(id: "cover_shield", name: "Notebook Cover",
                  blurb: "Cardboard, but it has seen things.",
                  slot: .shield,
                  bonus: Stats(maxHP: 6, maxInk: 0, attack: 0, defense: 4, speed: 0, luck: 0),
                  iconName: "shield_notebook", price: 90),
        Equipment(id: "hard_cover", name: "Hardback Cover",
                  blurb: "Nothing gets through a hardback.",
                  slot: .shield,
                  bonus: Stats(maxHP: 18, maxInk: 0, attack: 0, defense: 11, speed: -1, luck: 0),
                  iconName: "shield_notebook", price: 280)
    ]

    static func equipment(id: String) -> Equipment? { all.first { $0.id == id } }

    static let shopStock: [String] = ["sharp_pencil", "cover_shield", "fountain_pen", "hard_cover"]

    static var forSale: [Equipment] { shopStock.compactMap { equipment(id: $0) } }
}
