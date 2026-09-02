import Foundation

/// A special move. Costs ink, the game's magic resource.
struct Skill: Codable, Equatable, Identifiable {
    enum Kind: String, Codable {
        case damage
        case heal
        case buffAttack
        case debuffDefense
    }

    var id: String
    var name: String
    var blurb: String
    var kind: Kind
    var power: Int
    var inkCost: Int
    /// Level at which the hero learns this move.
    var unlockLevel: Int = 1

    static let scribbleStrike = Skill(
        id: "scribble_strike", name: "Scribble Strike",
        blurb: "A furious flurry of pen strokes.",
        kind: .damage, power: 14, inkCost: 3, unlockLevel: 2)

    static let inkBlot = Skill(
        id: "ink_blot", name: "Ink Blot",
        blurb: "Splatter the foe and dull its guard.",
        kind: .debuffDefense, power: 4, inkCost: 4, unlockLevel: 5)

    static let patchUp = Skill(
        id: "patch_up", name: "Patch Up",
        blurb: "Redraw your own outline. Restores health.",
        kind: .heal, power: 26, inkCost: 5, unlockLevel: 7)

    static let boldStroke = Skill(
        id: "bold_stroke", name: "Bold Stroke",
        blurb: "Press down hard. Raises attack.",
        kind: .buffAttack, power: 5, inkCost: 4, unlockLevel: 10)

    static let fullPage = Skill(
        id: "full_page", name: "Full Page",
        blurb: "Fill the whole sheet with ink. Huge damage.",
        kind: .damage, power: 34, inkCost: 9, unlockLevel: 14)

    static let heroSkills: [Skill] = [
        .scribbleStrike, .inkBlot, .patchUp, .boldStroke, .fullPage
    ]

    static func heroSkills(forLevel level: Int) -> [Skill] {
        heroSkills.filter { $0.unlockLevel <= level }
    }
}

/// Anything the player can carry.
struct Item: Codable, Equatable, Identifiable {
    enum Effect: Codable, Equatable {
        case restoreHP(Int)
        case restoreInk(Int)
        case cure
        case keyItem
    }

    var id: String
    var name: String
    var blurb: String
    var effect: Effect
    var iconName: String
    var price: Int
    var usableInBattle: Bool = true
    var usableOnMap: Bool = true
}

/// A single stack of an item in the player's bag.
struct InventorySlot: Codable, Equatable, Identifiable {
    var id: String { itemID }
    var itemID: String
    var count: Int
}

/// Gear the hero can equip. Kept deliberately small: one weapon, one shield.
struct Equipment: Codable, Equatable, Identifiable {
    enum Slot: String, Codable {
        case weapon
        case shield
    }

    var id: String
    var name: String
    var blurb: String
    var slot: Slot
    var bonus: Stats
    var iconName: String
    var price: Int

    /// A compact "+6 atk, +1 spd" style description of what this gear adds.
    var summary: String {
        var parts: [String] = []
        if bonus.attack != 0 { parts.append("\(signed(bonus.attack)) atk") }
        if bonus.defense != 0 { parts.append("\(signed(bonus.defense)) def") }
        if bonus.maxHP != 0 { parts.append("\(signed(bonus.maxHP)) hp") }
        if bonus.maxInk != 0 { parts.append("\(signed(bonus.maxInk)) ink") }
        if bonus.speed != 0 { parts.append("\(signed(bonus.speed)) spd") }
        if bonus.luck != 0 { parts.append("\(signed(bonus.luck)) lck") }
        return parts.isEmpty ? "no bonus" : parts.joined(separator: ", ")
    }

    private func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : "\(value)"
    }
}
