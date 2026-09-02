import Foundation

/// Pure turn resolution. No SpriteKit, no side effects beyond the values it is
/// handed, which makes the combat maths easy to reason about and to unit test.
struct BattleEngine {

    enum Action {
        case attack
        case skill(Skill)
        case item(Item)
        case flee
    }

    /// One thing that happened, ready to be narrated and animated.
    struct Event {
        enum Kind {
            case heroAttack(damage: Int, critical: Bool)
            case heroSkill(skill: Skill, damage: Int, healed: Int)
            case heroItem(item: Item)
            case enemyAttack(damage: Int, critical: Bool)
            case notEnoughInk
            case fleeSucceeded
            case fleeFailed
            case enemyDefeated
            case heroDefeated
        }

        var kind: Kind
        var message: String
    }

    // MARK: - Damage

    /// Attack minus half defence, with a little randomness so identical fights
    /// never play out identically.
    static func damage(attack: Int, defense: Int, power: Int, luck: Int) -> (value: Int, critical: Bool) {
        let base = Double(attack + power) - Double(defense) * 0.5
        let jitter = Double.random(in: 0.88...1.12)
        let critical = Double.random(in: 0...1) < min(0.28, 0.04 + Double(luck) * 0.012)
        let multiplier = critical ? 1.75 : 1.0
        let value = Int((max(1.0, base) * jitter * multiplier).rounded())
        return (max(1, value), critical)
    }

    // MARK: - Hero turn

    static func resolveHero(action: Action,
                            hero: inout Combatant,
                            enemy: inout Combatant) -> [Event] {
        var events: [Event] = []

        switch action {
        case .attack:
            let hit = damage(attack: hero.stats.attack,
                             defense: enemy.stats.defense,
                             power: 0,
                             luck: hero.stats.luck)
            enemy.take(damage: hit.value)
            events.append(Event(
                kind: .heroAttack(damage: hit.value, critical: hit.critical),
                message: hit.critical
                    ? "A clean line! \(hit.value) damage."
                    : "You strike for \(hit.value)."))

        case .skill(let skill):
            guard hero.currentInk >= skill.inkCost else {
                return [Event(kind: .notEnoughInk, message: "Not enough ink.")]
            }
            hero.currentInk -= skill.inkCost

            switch skill.kind {
            case .damage:
                let hit = damage(attack: hero.stats.attack,
                                 defense: enemy.stats.defense,
                                 power: skill.power,
                                 luck: hero.stats.luck)
                enemy.take(damage: hit.value)
                events.append(Event(
                    kind: .heroSkill(skill: skill, damage: hit.value, healed: 0),
                    message: "\(skill.name)! \(hit.value) damage."))

            case .heal:
                let before = hero.currentHP
                hero.heal(skill.power)
                let healed = hero.currentHP - before
                events.append(Event(
                    kind: .heroSkill(skill: skill, damage: 0, healed: healed),
                    message: "\(skill.name). Restored \(healed) health."))

            case .buffAttack:
                hero.stats.attack += skill.power
                events.append(Event(
                    kind: .heroSkill(skill: skill, damage: 0, healed: 0),
                    message: "\(skill.name)! Your attack rises."))

            case .debuffDefense:
                enemy.stats.defense = max(0, enemy.stats.defense - skill.power)
                events.append(Event(
                    kind: .heroSkill(skill: skill, damage: 0, healed: 0),
                    message: "\(skill.name)! \(enemy.name) looks blotchy."))
            }

        case .item(let item):
            switch item.effect {
            case .restoreHP(let amount):
                let before = hero.currentHP
                hero.heal(amount)
                events.append(Event(kind: .heroItem(item: item),
                                    message: "\(item.name). Restored \(hero.currentHP - before) health."))
            case .restoreInk(let amount):
                let before = hero.currentInk
                hero.restoreInk(amount)
                events.append(Event(kind: .heroItem(item: item),
                                    message: "\(item.name). Restored \(hero.currentInk - before) ink."))
            case .cure, .keyItem:
                events.append(Event(kind: .heroItem(item: item),
                                    message: "\(item.name). Nothing happens."))
            }

        case .flee:
            // Faster heroes get away more often, but it is never guaranteed and
            // never hopeless.
            let odds = min(0.9, max(0.25,
                0.5 + Double(hero.stats.speed - enemy.stats.speed) * 0.05))
            if Double.random(in: 0...1) < odds {
                events.append(Event(kind: .fleeSucceeded, message: "You slip off the page."))
            } else {
                events.append(Event(kind: .fleeFailed, message: "It blocks your way!"))
            }
        }

        if enemy.isDown {
            events.append(Event(kind: .enemyDefeated, message: "\(enemy.name) is erased!"))
        }
        return events
    }

    // MARK: - Enemy turn

    static func resolveEnemy(hero: inout Combatant, enemy: inout Combatant) -> [Event] {
        guard !enemy.isDown else { return [] }

        let hit = damage(attack: enemy.stats.attack,
                         defense: hero.stats.defense,
                         power: 0,
                         luck: enemy.stats.luck)
        hero.take(damage: hit.value)

        var events = [Event(
            kind: .enemyAttack(damage: hit.value, critical: hit.critical),
            message: hit.critical
                ? "\(enemy.name) lands a heavy blow! \(hit.value) damage."
                : "\(enemy.name) hits you for \(hit.value).")]

        if hero.isDown {
            events.append(Event(kind: .heroDefeated, message: "Your outline fades..."))
        }
        return events
    }

    /// Does the hero move first this round?
    static func heroActsFirst(hero: Combatant, enemy: Combatant) -> Bool {
        if hero.stats.speed == enemy.stats.speed {
            return Bool.random()
        }
        return hero.stats.speed > enemy.stats.speed
    }
}
