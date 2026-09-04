#if DEBUG
import Foundation

/// Reproducible, reachable development states. Never used by a Release build.
enum AdventurePreviewFixtures {
    static func save(for name: String) -> AdventureSave {
        var save = AdventureSave.fresh
        switch name {
        case "prologue": return save
        case "first-pigment":
            save.introSeen = true
        case "brown-awakening":
            save.introSeen = true
            save.x = 11
            save.y = 11
            save.colors = [.brown]
            save.collected = ["pigment_brown"]
            save.painted = ["first_chest"]
        case "violet-seam":
            save = camp
            save.pageID = "seam"
            save.x = 8
            save.y = 15
            save.elapsed = 485
            save.visited.insert("seam")
        default:
            save = camp
        }
        return save
    }

    private static var camp: AdventureSave {
        var save = AdventureSave.fresh
        save.introSeen = true
        save.pageID = "reverse"
        save.visited = ["margin", "garden", "reverse", "archive"]
        save.colors = [.brown, .green, .yellow, .red, .blue]
        save.collected = ["first_chest", "pigment_brown", "pigment_green", "pigment_yellow", "pigment_red",
                          "pigment_blue", "memory_margin", "memory_garden", "memory_reverse"]
        save.painted = ["first_chest", "reverse_tree", "reverse_berries"]
        save.flags = ["margin_pass", "garden_pass", "reverse_pass"]
        save.x = 10.5
        save.y = 12
        save.elapsed = 418
        save.hunger = 73
        save.warmth = 88
        save.integrity = 94
        save.eraserLevel = 1
        save.wood = 18
        save.scraps = 24
        save.food = 6
        save.nextInkAt = save.elapsed + 12
        save.nextCreatureAt = save.elapsed + 20
        save.builds = [
            PlacedBuild(id: "preview-fire", pageID: "reverse", point: PagePoint(x: 11, y: 13),
                        kind: .campfire, fuel: 100),
            PlacedBuild(id: "preview-home", pageID: "reverse", point: PagePoint(x: 9, y: 14),
                        kind: .shelter, fuel: 0)
        ]
        for y in 10...15 {
            save.builds.append(PlacedBuild(id: "preview-wall-\(y)", pageID: "reverse",
                                          point: PagePoint(x: 13, y: y), kind: .wall, fuel: 0))
            for x in 14...18 {
                save.ink["reverse", default: []].insert(PagePoint(x: x, y: y))
            }
        }
        for x in 14...17 {
            save.builds.append(PlacedBuild(id: "preview-path-\(x)", pageID: "reverse",
                                          point: PagePoint(x: x, y: 9), kind: .path, fuel: 0))
            save.ink["reverse", default: []].insert(PagePoint(x: x, y: 9))
        }
        save.creatures = [
            InkCreature(id: "preview-creature", pageID: "reverse", x: 14, y: 12, remaining: 1)
        ]
        return save
    }
}
#endif
