import Foundation
import Combine

/// The single source of truth for the player's run. Scenes read and mutate this
/// object; it owns persistence and derived stats.
final class GameState: ObservableObject {
    static let shared = GameState()

    @Published private(set) var save: SaveGame

    private var lastTick: Date = Date()

    private init() {
        save = SaveSystem.load() ?? .fresh
    }

    // MARK: - Derived hero values

    var level: Int { Progression.level(forExperience: save.experience) }

    var baseStats: Stats { Progression.heroStats(atLevel: level) }

    var equippedWeapon: Equipment? { EquipmentCatalog.equipment(id: save.weaponID) }

    var equippedShield: Equipment? {
        save.shieldID.flatMap { EquipmentCatalog.equipment(id: $0) }
    }

    /// Base stats plus gear bonuses.
    var totalStats: Stats {
        var s = baseStats
        if let w = equippedWeapon { s = s + w.bonus }
        if let sh = equippedShield { s = s + sh.bonus }
        return s
    }

    var currentHP: Int { min(save.currentHP, totalStats.maxHP) }
    var currentInk: Int { min(save.currentInk, totalStats.maxInk) }
    var coins: Int { save.coins }

    var experienceIntoLevel: Int {
        save.experience - Progression.experience(forLevel: level)
    }

    var experienceForNextLevel: Int {
        guard level < Progression.maxLevel else { return experienceIntoLevel }
        return Progression.experience(forLevel: level + 1) - Progression.experience(forLevel: level)
    }

    var skills: [Skill] { Skill.heroSkills(forLevel: level) }

    /// The hero as a battle-ready combatant.
    func makeHeroCombatant() -> Combatant {
        let s = totalStats
        return Combatant(name: "Nib",
                         stats: s,
                         currentHP: max(1, currentHP),
                         currentInk: currentInk,
                         spriteName: "nib_idle",
                         spriteFolder: "characters",
                         isHero: true,
                         skills: skills)
    }

    // MARK: - Mutation

    func setPosition(mapID: String, x: Int, y: Int) {
        save.mapID = mapID
        save.tileX = x
        save.tileY = y
    }

    func syncFromBattle(hp: Int, ink: Int) {
        save.currentHP = max(0, min(hp, totalStats.maxHP))
        save.currentInk = max(0, min(ink, totalStats.maxInk))
    }

    /// Applies rewards and reports whether the hero gained a level.
    @discardableResult
    func award(experience xp: Int, coins gold: Int, loot: [String]) -> Bool {
        let before = level
        save.experience += max(0, xp)
        save.coins += max(0, gold)
        save.defeatedCount += 1
        for id in loot { addItem(id, count: 1) }

        let levelled = level > before
        if levelled {
            // A level up is a full restore. It is a doodle game, be generous.
            save.currentHP = totalStats.maxHP
            save.currentInk = totalStats.maxInk
        }
        persist()
        return levelled
    }

    func heal(_ amount: Int) {
        save.currentHP = min(totalStats.maxHP, save.currentHP + amount)
        persist()
    }

    func restoreInk(_ amount: Int) {
        save.currentInk = min(totalStats.maxInk, save.currentInk + amount)
        persist()
    }

    func fullRestore() {
        save.currentHP = totalStats.maxHP
        save.currentInk = totalStats.maxInk
        persist()
    }

    func spendInk(_ amount: Int) -> Bool {
        guard save.currentInk >= amount else { return false }
        save.currentInk -= amount
        return true
    }

    // MARK: - Inventory

    var inventory: [InventorySlot] { save.inventory }

    func count(of itemID: String) -> Int {
        save.inventory.first { $0.itemID == itemID }?.count ?? 0
    }

    func addItem(_ id: String, count: Int = 1) {
        guard count > 0, ItemCatalog.item(id: id) != nil else { return }
        if let index = save.inventory.firstIndex(where: { $0.itemID == id }) {
            save.inventory[index].count += count
        } else {
            save.inventory.append(InventorySlot(itemID: id, count: count))
        }
    }

    @discardableResult
    func consumeItem(_ id: String) -> Item? {
        guard let index = save.inventory.firstIndex(where: { $0.itemID == id }),
              let item = ItemCatalog.item(id: id) else { return nil }
        save.inventory[index].count -= 1
        if save.inventory[index].count <= 0 {
            save.inventory.remove(at: index)
        }
        return item
    }

    // MARK: - Shopping

    func canAfford(_ price: Int) -> Bool { save.coins >= price }

    func addCoins(_ amount: Int) {
        save.coins = max(0, save.coins + amount)
    }

    /// Adds gear to the player's owned list without charging for it, used by
    /// treasure chests and story rewards.
    func grantEquipment(_ id: String) {
        guard EquipmentCatalog.equipment(id: id) != nil else { return }
        if !save.ownedEquipment.contains(id) {
            save.ownedEquipment.append(id)
        }
    }

    @discardableResult
    func buyItem(_ id: String) -> Bool {
        guard let item = ItemCatalog.item(id: id), canAfford(item.price) else { return false }
        save.coins -= item.price
        addItem(id)
        persist()
        return true
    }

    @discardableResult
    func buyEquipment(_ id: String) -> Bool {
        guard let gear = EquipmentCatalog.equipment(id: id),
              !save.ownedEquipment.contains(id),
              canAfford(gear.price) else { return false }
        save.coins -= gear.price
        save.ownedEquipment.append(id)
        equip(id)
        persist()
        return true
    }

    var ownedEquipment: [Equipment] {
        save.ownedEquipment.compactMap { EquipmentCatalog.equipment(id: $0) }
    }

    func equip(_ id: String) {
        guard let gear = EquipmentCatalog.equipment(id: id),
              save.ownedEquipment.contains(id) else { return }
        switch gear.slot {
        case .weapon: save.weaponID = id
        case .shield: save.shieldID = id
        }
        persist()
    }

    // MARK: - Story flags

    /// Named so the write site and the read site cannot drift apart. They did:
    /// the battle wrote "beat_big_smudge" while the map hid the boss on
    /// "boss_defeated", so the final boss respawned forever.
    enum Flag {
        static let bossDefeated = "boss_defeated"
    }

    func has(flag: String) -> Bool { save.flags.contains(flag) }

    func set(flag: String) {
        guard !save.flags.contains(flag) else { return }
        save.flags.append(flag)
        persist()
    }

    // MARK: - Lifecycle

    func tickPlaytime() {
        let now = Date()
        save.playtimeSeconds += now.timeIntervalSince(lastTick)
        lastTick = now
    }

    func persist() {
        tickPlaytime()
        SaveSystem.save(save)
        objectWillChange.send()
    }

    func startNewGame() {
        save = .fresh
        lastTick = Date()
        SaveSystem.save(save)
        objectWillChange.send()
    }

    func reviveAtCamp() {
        save.currentHP = totalStats.maxHP
        save.currentInk = totalStats.maxInk
        save.coins = max(0, save.coins - save.coins / 10)
        save.mapID = "pencil_plains"
        save.tileX = 8
        save.tileY = 10
        persist()
    }
}
