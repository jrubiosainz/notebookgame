import Foundation

// swiftc NotebookGame/NotebookGame/Adventure/*.swift tools/validate_adventure.swift -o /tmp/validate-adventure
@main
struct AdventureValidation {
    static var checks = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String,
                       file: StaticString = #file, line: UInt = #line) {
        checks += 1
        precondition(condition(), message, file: file, line: line)
    }

    static func fixture(page: String = "margin", x: Double = 10, y: Double = 6) -> AdventureEngine {
        var save = AdventureSave.fresh
        save.pageID = page
        save.x = x
        save.y = y
        return AdventureEngine(save: save)
    }

    static func advance(_ engine: AdventureEngine, seconds: Int) {
        for _ in 0..<seconds { engine.tick(1) }
    }

    static func path(_ engine: AdventureEngine, to target: PagePoint) -> [PagePoint]? {
        let start = PagePoint(x: Int(engine.save.x.rounded()), y: Int(engine.save.y.rounded()))
        var queue = [start]
        var seen: Set<PagePoint> = [start]
        var previous: [PagePoint: PagePoint] = [:]
        var index = 0
        while index < queue.count {
            let point = queue[index]
            index += 1
            if point == target {
                var result: [PagePoint] = []
                var cursor = target
                while cursor != start {
                    result.append(cursor)
                    cursor = previous[cursor]!
                }
                return result.reversed()
            }
            for delta in [PagePoint(x: 1, y: 0), PagePoint(x: -1, y: 0),
                          PagePoint(x: 0, y: 1), PagePoint(x: 0, y: -1)] {
                let next = PagePoint(x: point.x + delta.x, y: point.y + delta.y)
                if !seen.contains(next), engine.canStand(x: Double(next.x), y: Double(next.y)) {
                    seen.insert(next)
                    previous[next] = point
                    queue.append(next)
                }
            }
        }
        return nil
    }

    static func walk(_ engine: AdventureEngine, to point: PagePoint) {
        guard let route = path(engine, to: point) else { preconditionFailure("No route to \(point) in \(engine.page.id)") }
        for tile in route {
            expect(engine.move(dx: Double(tile.x) - engine.save.x, dy: Double(tile.y) - engine.save.y), "Scripted move blocked")
            engine.tick(0.25)
        }
        expect(hypot(engine.save.x - Double(point.x), engine.save.y - Double(point.y)) < 0.001, "Walk reaches exact target")
    }

    @discardableResult
    static func use(_ engine: AdventureEngine, _ id: String, twice: Bool = false) -> AdventureEvent {
        guard let object = engine.page.objects.first(where: { $0.id == id }) else { preconditionFailure("Missing \(id)") }
        walk(engine, to: object.point)
        let first = engine.interact(id)
        expect(first.success, "First use of \(id): \(first.title)")
        if twice {
            expect(engine.save.painted.contains(id), "First interaction physically paints \(id)")
            let result = engine.interact(id)
            expect(result.success, "Second use of \(id): \(result.title)")
            return result
        }
        return first
    }

    static func catalog() {
        expect(AdventureCatalog.pages.count == 6, "Six pages")
        expect(Set(AdventureCatalog.pages.map(\.depth)) == [0, 1, 2], "Three depth layers")
        let objects = AdventureCatalog.pages.flatMap(\.objects)
        expect(Set(objects.map(\.id)).count == objects.count, "Globally unique object IDs")
        expect(objects.filter { $0.kind == .memory }.count == 6, "Six campaign memories")
        for page in AdventureCatalog.pages {
            let engine = fixture(page: page.id, x: Double(page.spawn.x), y: Double(page.spawn.y))
            expect(engine.canStand(x: engine.save.x, y: engine.save.y), "Safe spawn")
            expect(page.blocked.count >= 20, "Each page has meaningful traversable geography")
            for object in page.objects {
                expect(!page.blocked.contains(object.point), "\(object.id) not hidden in collision")
                expect(path(engine, to: object.point) != nil, "\(object.id) physically reachable")
                expect(FileManager.default.fileExists(atPath: "assets/\(object.folder)/\(object.art).png"), "Existing art \(object.art)")
                if let target = object.targetPage {
                    expect(AdventureCatalog.pages.contains { $0.id == target }, "Gate destination exists")
                    let destination = AdventureCatalog.page(target)
                    expect(object.targetPoint == destination.spawn, "Gate has safe arrival")
                }
            }
        }
    }

    static func paintingAndClaims() {
        let engine = AdventureEngine()
        expect(!engine.interact("first_chest").success, "Cannot use distant chest")
        walk(engine, to: PagePoint(x: 12, y: 11))
        let before = engine.save
        expect(!engine.interact("first_chest").success, "Chest blocked without brown")
        expect(engine.save == before, "Failed interaction spends nothing")
        use(engine, "pigment_brown")
        expect(engine.save.painted.isEmpty, "Discovering brown does not auto-paint")
        walk(engine, to: PagePoint(x: 12, y: 11))
        let scraps = engine.save.scraps
        expect(engine.interact("first_chest").success, "Paint chest with brown")
        expect(engine.save.scraps == scraps && !engine.save.collected.contains("first_chest"), "Paint is not opening")
        expect(engine.interact("first_chest").success, "Open painted chest")
        expect(engine.save.scraps == scraps + 6, "Open grants contents")
        expect(!engine.interact("first_chest").success && engine.save.scraps == scraps + 6, "No double claim")
        walk(engine, to: PagePoint(x: 17, y: 12))
        expect(engine.interact("margin_garden").success, "Gate can be physically painted")
        expect(!engine.interact("margin_garden").success, "Story gate still requires NPC")
        use(engine, "margin_guide")
        expect(engine.save.flags.contains("margin_pass"), "NPC opens story gate only after chest")
        expect(use(engine, "margin_garden").changedPage, "Painted unlocked gate crosses")
        expect(engine.page.id == "garden", "Gate arrives in garden")
        expect(!engine.interact("first_chest").success, "Cannot interact across pages")
        let early = AdventureEngine()
        use(early, "margin_guide")
        expect(!early.save.flags.contains("margin_pass"), "Conversation without requirements does not unlock")
    }

    static func fullCampaign() throws {
        let engine = AdventureEngine()
        use(engine, "pigment_brown")
        use(engine, "first_chest", twice: true)
        use(engine, "memory_margin", twice: true)
        use(engine, "margin_guide")
        use(engine, "margin_garden", twice: true)
        use(engine, "pigment_green")
        use(engine, "garden_tree", twice: true)
        use(engine, "garden_berries", twice: true)
        use(engine, "pigment_yellow")
        use(engine, "memory_garden", twice: true)
        expect(engine.save.eraserLevel == 1 && engine.eraserReach == 2.2, "Second memory upgrades reach")
        use(engine, "garden_guide")
        use(engine, "garden_reverse", twice: true)
        use(engine, "pigment_red")
        use(engine, "memory_reverse", twice: true)
        use(engine, "reverse_guide")
        use(engine, "reverse_archive", twice: true)
        use(engine, "pigment_blue")
        use(engine, "memory_archive", twice: true)
        use(engine, "archive_guide")
        use(engine, "archive_margin", twice: true)
        expect(engine.page.id == "margin", "Blue + upgraded eraser return tunnel")
        use(engine, "margin_garden")
        use(engine, "garden_reverse")
        use(engine, "reverse_archive")
        use(engine, "archive_seam", twice: true)
        use(engine, "pigment_violet")
        use(engine, "memory_seam", twice: true)
        use(engine, "seam_guide")
        use(engine, "seam_origin", twice: true)
        walk(engine, to: PagePoint(x: 11, y: 16))
        expect(engine.interact("origin_inkwell").success, "Paint origin before finale")
        expect(!engine.interact("origin_inkwell").success, "Finale requires all six memories")
        use(engine, "memory_origin", twice: true)
        expect(engine.memoryCount == 6 && engine.save.eraserLevel == 3, "All memories and upgrades")
        expect(engine.save.elapsed > 60 && engine.save.hunger < 100, "Full campaign walks run live survival simulation")
        let ending = use(engine, "origin_inkwell")
        expect(ending.lines.count >= 3 && engine.isCompleted && engine.save.endingSeen, "Finite narrative ending")
        expect(engine.save.visited.count == 6, "All pages visited by actual movement")
        expect(engine.save.colors == Set(Pigment.allCases), "All pigments discovered")
        expect(engine.save.ink.values.allSatisfy(\.isEmpty), "Restoration clears all ink")
        use(engine, "origin_garden", twice: true)
        expect(engine.page.id == "garden", "Final return loop remains usable")
        use(engine, "garden_margin", twice: true)
        expect(engine.page.id == "margin", "Exploration continues after ending")
        advance(engine, seconds: 300)
        expect(engine.inkTiles.isEmpty && engine.save.creatures.isEmpty, "Restored world stays safe through night")
        let data = try JSONEncoder().encode(engine.save)
        let decoded = try JSONDecoder().decode(AdventureSave.self, from: data)
        expect(decoded == engine.save, "Complete campaign save roundtrip")
    }

    static func constructionAndSurvival() {
        let engine = fixture()
        let point = PagePoint(x: 11, y: 6)
        engine.save.wood = 30
        engine.save.scraps = 30
        expect(!engine.build(.campfire, at: point).success, "Fire needs colors")
        engine.save.colors = [.red]
        expect(!engine.canBuild(.campfire, at: point), "Fire needs yellow too")
        engine.save.colors.insert(.yellow)
        let wood = engine.save.wood
        expect(engine.build(.campfire, at: point).success, "Red + yellow allow fire")
        expect(engine.save.wood == wood - 3 && engine.save.builds[0].fuel == 90, "Fire costs and initial fuel")
        expect(engine.isProtected, "Fire protects nearby player")
        engine.tick(1)
        expect(abs(engine.save.builds[0].fuel - 89) < 0.00001, "Fuel burns with simulation time")
        expect(!engine.build(.campfire, at: point).success, "No overlapping build")
        let fuel = engine.save.builds[0].fuel
        expect(engine.rest().success, "Rest refuels and heals")
        expect(abs(engine.save.builds[0].fuel - (fuel + 52)) < 0.001, "Rest consumes eight seconds of fuel")
        engine.save.builds[0].fuel = 0.05
        engine.save.wood = 0
        engine.tick(0.1)
        expect(!engine.isProtected && !engine.rest().success, "Extinguished fire cannot protect or give free rest")
        engine.save.colors = [.brown, .green]
        engine.save.wood = 20
        let shelter = PagePoint(x: 10, y: 7)
        expect(engine.build(.shelter, at: shelter).success, "Build checkpoint shelter")
        expect(engine.save.checkpoint == shelter && engine.isProtected, "Shelter saves checkpoint and protects")
        engine.save.integrity = 0
        engine.save.scraps = 0
        engine.save.food = 0
        engine.tick(0.1)
        expect(engine.save.integrity == 85 && engine.save.x == 10 && engine.save.y == 7, "Death respawns checkpoint")
        expect(engine.save.scraps >= 3 && engine.save.food >= 1, "Respawn prevents survival softlock")
        expect(engine.save.colors == [.brown, .green], "Death preserves progression")

        let hungry = fixture()
        hungry.save.hunger = 0
        hungry.tick(1)
        expect(hungry.save.integrity < 100, "Starvation harms paper")
        expect(hungry.eat().success && hungry.save.hunger == 35, "Eating restores hunger")
        hungry.save.food = 0
        expect(!hungry.eat().success, "No free food")
        hungry.save.elapsed = 170
        hungry.save.warmth = 0
        let integrity = hungry.save.integrity
        hungry.tick(1)
        expect(hungry.save.integrity < integrity, "Night exposure harms paper")
        expect(!hungry.rest().success, "Cannot rest without camp")
        let cap = hungry.save.elapsed
        hungry.tick(1000)
        expect(hungry.save.elapsed - cap < 1.001, "Background delta capped")
        let stable = hungry.save
        hungry.tick(.nan)
        hungry.tick(-1)
        expect(hungry.save == stable, "Invalid deltas do nothing")
    }

    static func inkMovementAndEraser() {
        let engine = fixture()
        engine.save.ink["margin"] = [PagePoint(x: 11, y: 6)]
        expect(!engine.canStand(x: 11, y: 6), "Raw ink blocks movement")
        expect(engine.build(.path, at: PagePoint(x: 11, y: 6)).success, "Monochrome scrap path over ink")
        expect(engine.canStand(x: 11, y: 6), "Path bridges ink")
        expect(engine.move(dx: 1, dy: 0), "Cross path")
        expect(!engine.move(dx: 10, dy: 0), "No teleport")
        expect(!engine.canStand(x: .nan, y: 4), "Nonfinite positions rejected")
        expect(!engine.move(dx: .infinity, dy: 0), "Nonfinite movement rejected")
        expect(!engine.build(.path, at: PagePoint(x: 19, y: 19)).success, "Remote construction rejected")
        let boundary = fixture(x: 1, y: 1)
        boundary.move(dx: -1, dy: 0)
        expect(boundary.save.x >= 0.5, "Map boundary collision")

        let wall = fixture(x: 3, y: 2)
        wall.save.colors = [.brown]
        wall.save.wood = 8
        expect(wall.build(.wall, at: PagePoint(x: 3, y: 1)).success, "Wall built")
        wall.save.ink["margin"] = [PagePoint(x: 2, y: 1)]
        wall.save.elapsed = 170
        wall.save.nextInkAt = 170
        wall.tick(0.1)
        expect(!wall.inkTiles.contains(PagePoint(x: 3, y: 1)), "Wall blocks ink propagation")
        expect(wall.inkTiles.contains(PagePoint(x: 2, y: 2)), "Ink still propagates through open neighbors")
        expect(!wall.canStand(x: 3, y: 1), "Walls are solid")
        wall.save.ink["margin"] = []
        wall.save.facing = PagePoint(x: 0, y: -1)
        expect(wall.erase().success && wall.save.builds.isEmpty, "Facing wall can be recovered to avoid trapping player")

        let eraser = fixture()
        eraser.save.creatures = [InkCreature(id: "test", pageID: "margin", x: 11, y: 6, remaining: 1),
                                InkCreature(id: "remote", pageID: "garden", x: 10, y: 6, remaining: 1)]
        let scraps = eraser.save.scraps
        _ = eraser.erase()
        expect(abs(eraser.save.creatures[0].remaining - 0.66) < 0.00001, "Eraser reduces opacity, not hitpoints")
        expect(eraser.save.creatures[1].remaining == 1, "No erasure across pages")
        expect(!eraser.erase().success, "Eraser has live cooldown")
        eraser.tick(0.4)
        _ = eraser.erase()
        eraser.tick(0.4)
        _ = eraser.erase()
        expect(eraser.save.creatures.count == 1 && eraser.save.scraps == scraps + 1, "Fully erased creature becomes retal")
        eraser.tick(0.4)
        eraser.save.ink["margin"] = [PagePoint(x: 11, y: 6)]
        _ = eraser.erase()
        expect(eraser.inkTiles.isEmpty, "Goma opens ink without resources")

        let fire = fixture()
        fire.save.colors = [.red, .yellow]
        fire.save.wood = 10
        _ = fire.build(.campfire, at: PagePoint(x: 11, y: 6))
        fire.save.creatures = [InkCreature(id: "repelled", pageID: "margin", x: 12, y: 6, remaining: 1)]
        let x = fire.save.creatures[0].x
        fire.tick(1)
        expect(fire.save.creatures[0].x > x, "Fire actively repels creatures")
        let night = fixture()
        night.save.elapsed = 170
        night.save.nextCreatureAt = 170
        night.tick(0.1)
        expect(night.save.creatures.count == 1, "Night spawns deterministic live enemies")
        let old = night.save.creatures[0]
        night.tick(1)
        let new = night.save.creatures[0]
        expect(hypot(new.x - night.save.x, new.y - night.save.y) < hypot(old.x - night.save.x, old.y - night.save.y),
               "Night enemies pursue player")
        let canal = fixture(page: "archive", x: 13, y: 7)
        let crossing = PagePoint(x: 14, y: 7)
        expect(canal.inkTiles.contains(crossing), "Archive has genuine ink canal")
        expect(!canal.canStand(x: 14, y: 7), "Canal blocks unprepared direct crossing")
        expect(canal.build(.path, at: crossing).success, "Scraps bridge the actual catalog canal")
        expect(canal.move(dx: 1, dy: 0), "Built bridge permits actual canal crossing")
    }

    static func renewalAndPersistence() throws {
        let engine = fixture(page: "garden", x: 13, y: 18)
        engine.save.colors = [.green]
        expect(engine.interact("garden_berries").success && engine.save.food == 3, "Must paint harvestable first")
        expect(engine.interact("garden_berries").success && engine.save.food == 7, "Harvest painted berries")
        expect(!engine.interact("garden_berries").success && engine.save.food == 7, "No same-day double harvest")
        engine.save.elapsed = 240
        expect(engine.interact("garden_berries").success && engine.save.food == 11, "Deterministic dawn regrowth")
        walk(engine, to: PagePoint(x: 9, y: 13))
        engine.save.colors = []
        expect(engine.interact("garden_scraps").success, "Scraps intentionally usable without paint")
        expect(!engine.interact("garden_scraps").success, "Scraps also enforce daily claims")

        let first = fixture()
        first.save.elapsed = 165
        first.save.nextCreatureAt = 166
        first.save.nextInkAt = 167
        let second = AdventureEngine(save: first.save)
        for _ in 0..<100 { first.tick(0.1) }
        for _ in 0..<20 { second.tick(0.5) }
        expect(first.save == second.save, "Fixed-step behavior independent of frame grouping")
        first.tick(0.035)
        let resumed = AdventureEngine(save: try JSONDecoder().decode(AdventureSave.self, from: JSONEncoder().encode(first.save)))
        for _ in 0..<30 { first.tick(0.3); resumed.tick(0.3) }
        expect(first.save == resumed.save, "Save/load retains simulation clocks and determinism")

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("notebook-adventure-validation-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("slot.json")
        try AdventureStore.save(first.save, to: url)
        expect(AdventureStore.load(from: url) == first.save, "Atomic persistence roundtrip")
        expect(AdventureStore.loadError == nil, "Successful load clears error")
        try Data("not a save".utf8).write(to: url)
        expect(AdventureStore.load(from: url) == nil && AdventureStore.loadError != nil, "Corruption surfaced")
        let corruptSource = try String(contentsOf: url, encoding: .utf8)
        expect(corruptSource == "not a save", "Corrupt source preserved")
        let migrated = try JSONDecoder().decode(AdventureSave.self, from: Data("{\"pageID\":\"garden\",\"x\":10,\"y\":11}".utf8))
        expect(migrated.visited == ["garden"] && migrated.hunger == 100 && migrated.sequence == 0, "Missing fields migrate with defaults")
        var invalid = first.save
        invalid.facing.x = Int.min
        do {
            try AdventureStore.save(invalid, to: url)
            preconditionFailure("Invalid save accepted")
        } catch AdventureStore.StoreError.invalidState {
            expect(true, "Invalid state rejected safely")
        }
        try Data("{\"pageID\":\"missing\"}".utf8).write(to: url)
        expect(AdventureStore.load(from: url) == nil && AdventureStore.loadError != nil, "Unknown page rejected before engine")
    }

    static func main() throws {
        catalog()
        paintingAndClaims()
        try fullCampaign()
        constructionAndSurvival()
        inkMovementAndEraser()
        try renewalAndPersistence()
        print("Adventure validation passed: \(checks) checks, six-page campaign completed.")
    }
}
