import Foundation

/// The numbers behind every fighter in the game, hero or monster.
struct Stats: Codable, Equatable {
    var maxHP: Int
    var maxInk: Int
    var attack: Int
    var defense: Int
    var speed: Int
    var luck: Int

    static let zero = Stats(maxHP: 1, maxInk: 0, attack: 1, defense: 0, speed: 1, luck: 0)

    static func + (lhs: Stats, rhs: Stats) -> Stats {
        Stats(maxHP: lhs.maxHP + rhs.maxHP,
              maxInk: lhs.maxInk + rhs.maxInk,
              attack: lhs.attack + rhs.attack,
              defense: lhs.defense + rhs.defense,
              speed: lhs.speed + rhs.speed,
              luck: lhs.luck + rhs.luck)
    }
}

/// Level curve for the hero. Deliberately gentle so a play session feels
/// rewarding without long grinding stretches.
enum Progression {
    static let maxLevel = 30

    /// Total experience required to *reach* the given level.
    static func experience(forLevel level: Int) -> Int {
        guard level > 1 else { return 0 }
        let n = Double(level - 1)
        return Int(18.0 * n * n + 22.0 * n)
    }

    static func level(forExperience xp: Int) -> Int {
        var level = 1
        while level < maxLevel && xp >= experience(forLevel: level + 1) {
            level += 1
        }
        return level
    }

    /// Base stats for the hero at a given level.
    static func heroStats(atLevel level: Int) -> Stats {
        let n = level - 1
        return Stats(maxHP: 24 + n * 6,
                     maxInk: 10 + n * 3,
                     attack: 7 + n * 2,
                     defense: 4 + Int(Double(n) * 1.4),
                     speed: 6 + n,
                     luck: 3 + n / 2)
    }
}

/// A living combatant during a battle. Enemies and the hero share this shape so
/// `BattleEngine` can treat both sides uniformly.
struct Combatant: Identifiable {
    let id: UUID = UUID()
    var name: String
    var stats: Stats
    var currentHP: Int
    var currentInk: Int
    var spriteName: String
    var spriteFolder: String
    var isHero: Bool
    var skills: [Skill]
    var experienceReward: Int = 0
    var coinReward: Int = 0
    var lootTable: [String] = []

    var isDown: Bool { currentHP <= 0 }

    var hpFraction: Double {
        guard stats.maxHP > 0 else { return 0 }
        return max(0, min(1, Double(currentHP) / Double(stats.maxHP)))
    }

    mutating func take(damage: Int) {
        currentHP = max(0, currentHP - max(0, damage))
    }

    mutating func heal(_ amount: Int) {
        currentHP = min(stats.maxHP, currentHP + max(0, amount))
    }

    mutating func restoreInk(_ amount: Int) {
        currentInk = min(stats.maxInk, currentInk + max(0, amount))
    }
}
