import Foundation

final class AdventureEngine {
    var save: AdventureSave
    private(set) var lastMessage: String?

    init(save: AdventureSave = .fresh) {
        self.save = save
        enterPage()
    }

    var page: AdventurePage { AdventureCatalog.page(save.pageID) }
    var day: Int { Int(save.elapsed / 240) + 1 }
    var isNight: Bool { save.elapsed.truncatingRemainder(dividingBy: 240) >= 160 }
    var phaseTitle: String { "Dia \(day) | \(isNight ? "Noche" : "Luz")" }
    var inkTiles: Set<PagePoint> { save.ink[save.pageID] ?? [] }
    var memoryCount: Int {
        AdventureCatalog.pages.flatMap(\.objects)
            .filter { $0.kind == .memory && save.collected.contains($0.id) }.count
    }
    var maxMemories: Int { 6 }
    var eraserReach: Double { 1.8 + Double(save.eraserLevel) * 0.4 }
    var isCompleted: Bool { save.flags.contains("restored") }
    var isProtected: Bool { protected(x: save.x, y: save.y) }
    var targetPoint: PagePoint {
        PagePoint(x: Int(save.x.rounded()) + save.facing.x,
                  y: Int(save.y.rounded()) + save.facing.y)
    }

    var nearbyObject: AdventureObject? {
        page.objects.filter { isAvailable($0) && distance($0.point) <= 1.65 }
            .sorted {
                let a = distance($0.point), b = distance($1.point)
                return a == b ? $0.id < $1.id : a < b
            }.first
    }

    var objective: String {
        if isCompleted { return "El cuaderno vive. Explora, construye y vuelve a tus refugios." }
        if !save.colors.contains(.brown) { return "Recoge el pigmento marron junto a Tinta." }
        if !save.collected.contains("first_chest") { return "Pinta el cofre marron; vuelve a tocarlo para abrirlo." }
        if !save.flags.contains("margin_pass") { return "Habla con Tinta para abrir el jardin." }
        if !save.colors.contains(.green) { return "Busca verde en el jardin: pinta bayas y arboles." }
        if !save.colors.contains(.yellow) { return "Encuentra amarillo en el jardin." }
        if memoryCount < 2 { return "Recupera los recuerdos del margen y del jardin." }
        if !save.flags.contains("garden_pass") { return "La jardinera conoce el camino al reves." }
        if !save.colors.contains(.red) { return "Busca rojo bajo el papel. Rojo + amarillo = fuego." }
        if memoryCount < 3 { return "Pinta el recuerdo rojo del reves del papel." }
        if !save.flags.contains("reverse_pass") { return "Carbon puede abrir la puerta del archivo." }
        if !save.colors.contains(.blue) { return "Recupera azul en el archivo sumergido." }
        if memoryCount < 4 { return "Busca el recuerdo azul. Tu goma alcanzara mas lejos." }
        if !save.flags.contains("archive_pass") { return "Habla con el archivero y pinta el puente azul." }
        if !save.colors.contains(.violet) { return "Encuentra violeta en la costura profunda." }
        if memoryCount < 5 { return "Devuelve color al quinto recuerdo." }
        if !save.flags.contains("seam_pass") { return "La costurera conoce el sello del origen." }
        if memoryCount < 6 { return "Recupera el ultimo recuerdo junto al tintero." }
        return "Pinta el tintero violeta y devuelve los seis recuerdos."
    }

    var journal: [String] {
        var entries = ["Seis hojas, una historia. Recuerdos: \(memoryCount)/\(maxMemories).",
                       "Primero descubre el pigmento. Luego pinta el objeto. Despues usalo.",
                       "La goma borra manchas y tinta; no es una espada.",
                       "Retales: caminos sin color. Marron: paredes. Verde: lena y comida.",
                       "Rojo + amarillo: hoguera. Marron + verde: refugio y punto de regreso.",
                       "Los recursos vuelven al amanecer. Descansar junto al fuego lo alimenta con lena."]
        entries += AdventureCatalog.pages.filter { save.visited.contains($0.id) }.map(\.flavor)
        entries += AdventureCatalog.pages.flatMap(\.objects)
            .filter { $0.kind == .memory && save.collected.contains($0.id) }.map(\.name)
        if isCompleted { entries.append("La autora no nos olvido. Ahora cada nueva linea nos pertenece.") }
        return entries
    }

    func markIntroSeen() { save.introSeen = true }

    func isAvailable(_ object: AdventureObject) -> Bool {
        switch object.kind {
        case .tree, .berries, .scraps:
            return (save.harvestedDay[object.id] ?? 0) < day
        case .pigment, .chest, .memory:
            return !save.collected.contains(object.id)
        default:
            return true
        }
    }

    func prompt(for object: AdventureObject) -> String {
        if !isAvailable(object) {
            return [.tree, .berries, .scraps].contains(object.kind) ? "Vuelve al amanecer" : "Ya recuperado"
        }
        if let color = object.pigment, needsPaint(object), !save.painted.contains(object.id) {
            return save.colors.contains(color) ? "Pintar: \(color.title)" : "Falta \(color.title.lowercased())"
        }
        switch object.kind {
        case .pigment: return "Descubrir color"
        case .chest: return "Abrir cofre"
        case .tree: return "Recoger lena"
        case .berries: return "Cosechar bayas"
        case .scraps: return "Recoger retales"
        case .npc: return "Conversar"
        case .gate: return gateFailure(object) ?? "Cruzar"
        case .memory: return "Recordar"
        case .inkwell: return isCompleted ? "El cuaderno vive" : "Restaurar: \(memoryCount)/6"
        case .rock: return "Leer el margen"
        }
    }

    func canStand(x: Double, y: Double) -> Bool {
        guard x.isFinite, y.isFinite, x >= 0.5, y >= 0.5,
              x <= Double(page.width) - 1.5, y <= Double(page.height) - 1.5 else { return false }
        for ox in [-0.22, 0.22] {
            for oy in [-0.22, 0.22] {
                let tile = PagePoint(x: Int((x + ox).rounded()), y: Int((y + oy).rounded()))
                if page.blocked.contains(tile) || hasBuild(.wall, at: tile) { return false }
                if inkTiles.contains(tile), !hasBuild(.path, at: tile), !hasBuild(.shelter, at: tile) {
                    return false
                }
            }
        }
        return true
    }

    @discardableResult
    func move(dx: Double, dy: Double) -> Bool {
        guard dx.isFinite, dy.isFinite, hypot(dx, dy) <= 1.01 else {
            lastMessage = "Paso demasiado largo."
            return false
        }
        guard abs(dx) + abs(dy) > 0 else { return false }
        save.facing = abs(dx) > abs(dy)
            ? PagePoint(x: dx >= 0 ? 1 : -1, y: 0)
            : PagePoint(x: 0, y: dy >= 0 ? 1 : -1)
        let steps = max(1, Int(ceil(hypot(dx, dy) / 0.12)))
        var moved = false
        for _ in 0..<steps {
            let x = save.x + dx / Double(steps), y = save.y + dy / Double(steps)
            if canStand(x: x, y: save.y) { save.x = x; moved = moved || dx != 0 }
            if canStand(x: save.x, y: y) { save.y = y; moved = moved || dy != 0 }
        }
        return moved
    }

    func interact(_ id: String) -> AdventureEvent {
        guard let object = page.objects.first(where: { $0.id == id }) else {
            return fail("No esta en esta pagina.")
        }
        guard distance(object.point) <= 1.65 else { return fail("Acercate a \(object.name.lowercased()).") }
        guard isAvailable(object) else { return fail(prompt(for: object)) }
        if let color = object.pigment, needsPaint(object), !save.painted.contains(id) {
            guard save.colors.contains(color) else { return fail("Primero descubre \(color.title.lowercased()).") }
            save.painted.insert(id)
            return emit(AdventureEvent(title: "Un trazo de \(color.title.lowercased())",
                                       lines: ["\(object.name) ya tiene color. Tocalo otra vez para usarlo."], color: color))
        }
        switch object.kind {
        case .pigment:
            guard let color = object.pigment else { return fail("Este pigmento no tiene color.") }
            save.colors.insert(color)
            save.collected.insert(id)
            return emit(AdventureEvent(title: "\(color.title) descubierto",
                                       lines: ["Nada se pinta solo. Acercate a un objeto y dale color."], color: color))
        case .chest:
            save.collected.insert(id)
            save.scraps += 6
            save.wood += 3
            save.food += 2
            return event("Cofre abierto", ["+6 retales | +3 lena | +2 comida", "Un objeto sin color no podia guardar nada."])
        case .tree, .berries, .scraps:
            save.harvestedDay[id] = day
            switch object.kind {
            case .tree: save.wood += 5
            case .berries: save.food += 4
            default: save.scraps += 6
            }
            let gain = object.kind == .tree ? "+5 lena" : object.kind == .berries ? "+4 comida" : "+6 retales"
            return event(gain, ["El papel volvera a ofrecerlo al amanecer."])
        case .npc:
            let unlocked = talk(object.id)
            return event(object.name, object.lines + [unlocked])
        case .gate:
            if let reason = gateFailure(object) { return fail(reason) }
            guard let target = object.targetPage,
                  AdventureCatalog.pages.contains(where: { $0.id == target }) else {
                return fail("Este paso no lleva a ninguna pagina.")
            }
            let destination = object.targetPoint ?? AdventureCatalog.page(target).spawn
            save.pageID = target
            save.x = Double(destination.x)
            save.y = Double(destination.y)
            enterPage()
            clearArrival(destination)
            return emit(AdventureEvent(title: page.name, lines: [page.subtitle], changedPage: true))
        case .memory:
            save.collected.insert(id)
            save.eraserLevel = min(3, memoryCount / 2)
            return event(object.name, [memoryLine(page.id), "Recuerdos: \(memoryCount)/6. Goma: nivel \(save.eraserLevel)."])
        case .inkwell:
            guard !isCompleted else { return event("El cuaderno vive", ["No hace falta terminar de explorar para terminar una historia."]) }
            guard memoryCount == maxMemories else { return fail("Faltan recuerdos: \(memoryCount)/6.") }
            save.flags.insert("restored")
            save.endingSeen = true
            save.integrity = 100
            save.warmth = 100
            save.ink = Dictionary(uniqueKeysWithValues: AdventureCatalog.pages.map { ($0.id, Set<PagePoint>()) })
            save.creatures.removeAll()
            return event("El mundo sigue escribiendose", [
                "Las seis memorias caen al tintero. No devuelven a la autora: devuelven al mundo su voz.",
                "Tinta dibuja una puerta abierta. Al otro lado no hay final, sino espacio para vivir.",
                "La noche ya no avanza. Tus refugios, colores y caminos permanecen. Sigue explorando."
            ])
        case .rock:
            return event("Una nota al margen", ["Camina cerca y borra la tinta antes de cruzar.",
                                               "Un camino de retales permanece. Una pared puede recogerse con la goma si no hay manchas cerca."])
        }
    }

    func erase() -> AdventureEvent {
        guard save.elapsed + 0.00001 >= save.nextEraseAt else { return fail("La goma necesita un instante.") }
        save.nextEraseAt = save.elapsed + 0.35
        var touched = 0
        var removed = 0
        for index in save.creatures.indices where save.creatures[index].pageID == save.pageID {
            if hypot(save.creatures[index].x - save.x, save.creatures[index].y - save.y) <= eraserReach {
                save.creatures[index].remaining = max(0, save.creatures[index].remaining - 0.34 - Double(save.eraserLevel) * 0.08)
                touched += 1
                if save.creatures[index].remaining <= 0.00001 { removed += 1 }
            }
        }
        save.creatures.removeAll { $0.remaining <= 0.00001 }
        save.scraps += removed
        let cleaned = inkTiles.filter { distance($0) <= eraserReach }
        save.ink[save.pageID, default: []].subtract(cleaned)
        if touched > 0 || !cleaned.isEmpty {
            return event(removed > 0 ? "Mancha borrada" : "El trazo se desvanece",
                         ["\(touched) manchas rozadas | \(cleaned.count) casillas limpias",
                          removed > 0 ? "+\(removed) retales recuperados." : "Sigue borrando hasta que no quede tinta."])
        }
        if let index = save.builds.firstIndex(where: {
            $0.pageID == save.pageID && $0.kind == .wall && $0.point == targetPoint
        }) {
            save.builds.remove(at: index)
            save.wood += 2
            return event("Pared recogida", ["+2 lena. El paso vuelve a estar libre."])
        }
        return event("Un arco de goma", ["No hay tinta a tu alcance."])
    }

    func buildRequirement(_ kind: BuildKind) -> String {
        switch kind {
        case .wall: return "Marron | 2 lena"
        case .path: return "1 retal | sin pigmento"
        case .campfire: return "Rojo + amarillo | 3 lena + 2 retales"
        case .shelter: return "Marron + verde | 5 lena + 4 retales"
        }
    }

    func canBuild(_ kind: BuildKind, at point: PagePoint) -> Bool {
        buildFailure(kind, at: point) == nil
    }

    func build(_ kind: BuildKind, at point: PagePoint) -> AdventureEvent {
        if let reason = buildFailure(kind, at: point) { return fail(reason) }
        let cost = buildCost(kind)
        save.wood -= cost.wood
        save.scraps -= cost.scraps
        save.sequence += 1
        save.builds.append(PlacedBuild(id: "build_\(save.sequence)", pageID: save.pageID,
                                      point: point, kind: kind, fuel: kind == .campfire ? 90 : 0))
        if kind != .path { save.ink[save.pageID, default: []].remove(point) }
        if kind == .shelter {
            save.checkpointPage = save.pageID
            save.checkpoint = point
        }
        return event("\(kind.title) construido", [
            kind == .shelter ? "Nuevo punto de regreso. Descansa cerca para recuperarte."
                : kind == .campfire ? "90 s de calor. Descansar cerca consume 1 lena y repone el fuego."
                : kind == .wall ? "Frena tinta y manchas. Puedes recogerla con la goma."
                : "Ahora puedes caminar sobre esta casilla, incluso si hay tinta."
        ])
    }

    func eat() -> AdventureEvent {
        guard save.food > 0 else { return fail("No queda comida. Pinta bayas verdes o busca un cofre.") }
        guard save.hunger < 99 else { return fail("Todavia no tienes hambre.") }
        save.food -= 1
        save.hunger = min(100, save.hunger + 35)
        save.integrity = min(100, save.integrity + 4)
        return event("Un pequeno bocado", ["+35 saciedad. Guarda algo para la noche."])
    }

    func rest() -> AdventureEvent {
        let nearby = save.builds.indices.filter {
            save.builds[$0].pageID == save.pageID && distance(save.builds[$0].point) <= 2.4
        }
        let shelter = nearby.first { save.builds[$0].kind == .shelter }
        let fire = nearby.first { save.builds[$0].kind == .campfire }
        guard shelter != nil || fire != nil else { return fail("Descansa junto a una hoguera o un refugio.") }
        if let fire, save.wood > 0, save.builds[fire].fuel < 150 {
            save.wood -= 1
            save.builds[fire].fuel = min(180, save.builds[fire].fuel + 60)
        } else if shelter == nil, let fire, save.builds[fire].fuel <= 0 {
            return fail("La hoguera esta apagada. Necesitas 1 lena para avivarla.")
        }
        if let shelter {
            save.checkpointPage = save.pageID
            save.checkpoint = save.builds[shelter].point
        }
        save.hunger = max(0, save.hunger - 4)
        save.warmth = min(100, save.warmth + 30)
        save.integrity = min(100, save.integrity + 18)
        for _ in 0..<8 { tick(1) }
        return event("Un respiro entre lineas", ["Recuperas calor e integridad. Pasan 8 segundos.",
                                                shelter != nil ? "Refugio guardado como punto de regreso." : "El fuego mantiene lejos las manchas."])
    }

    func tick(_ dt: Double) {
        guard dt.isFinite, dt > 0 else { return }
        save.simulationRemainder += min(dt, 1)
        // Fixed simulation steps keep damage, pursuit and propagation identical across frame rates.
        while save.simulationRemainder + 0.0000001 >= 0.1 {
            save.simulationRemainder = max(0, save.simulationRemainder - 0.1)
            step(0.1)
        }
        if save.simulationRemainder < 0.0000001 { save.simulationRemainder = 0 }
    }

    private func step(_ dt: Double) {
        save.elapsed += dt
        for index in save.builds.indices where save.builds[index].kind == .campfire {
            save.builds[index].fuel = max(0, save.builds[index].fuel - dt)
        }
        save.hunger = max(0, save.hunger - dt * 0.055)
        save.warmth = min(100, max(0, save.warmth + dt * (isProtected ? 2 : isNight ? -0.32 : 0.22)))
        if save.hunger <= 0 { save.integrity -= dt * 1.1 }
        if save.warmth <= 0 { save.integrity -= dt * 0.8 }
        let here = PagePoint(x: Int(save.x.rounded()), y: Int(save.y.rounded()))
        if inkTiles.contains(here), !hasBuild(.path, at: here), !isProtected { save.integrity -= dt * 3 }
        if save.elapsed >= save.nextInkAt {
            save.nextInkAt = save.elapsed + 12
            spreadInk()
        }
        if save.elapsed >= save.nextCreatureAt {
            save.nextCreatureAt = save.elapsed + 20
            spawnCreature()
        }
        updateCreatures(dt)
        save.integrity = min(100, max(0, save.integrity))
        if save.integrity <= 0 { respawn() }
    }

    private func spreadInk() {
        guard !isCompleted else { return }
        var tiles = inkTiles
        if !isNight {
            let sources = Set(page.inkSources)
            let removable = tiles.subtracting(sources).sorted(by: pointOrder)
            tiles.subtract(removable.prefix(8))
        } else {
            var candidates: Set<PagePoint> = []
            for tile in tiles.union(page.inkSources) {
                for direction in directions {
                    let next = PagePoint(x: tile.x + direction.x, y: tile.y + direction.y)
                    if inside(next), !page.blocked.contains(next), !hasBuild(.wall, at: next),
                       !protected(x: Double(next.x), y: Double(next.y)),
                       hypot(Double(next.x - page.spawn.x), Double(next.y - page.spawn.y)) > 2.5 {
                        candidates.insert(next)
                    }
                }
            }
            tiles.formUnion(candidates.subtracting(tiles).sorted(by: pointOrder).prefix(max(0, 140 - tiles.count)))
        }
        save.ink[save.pageID] = tiles
    }

    private func spawnCreature() {
        guard isNight, !isCompleted,
              save.creatures.filter({ $0.pageID == save.pageID }).count < 5 else { return }
        let sources = page.inkSources
        guard !sources.isEmpty else { return }
        let source = sources[save.sequence % sources.count]
        guard !hasBuild(.wall, at: source), !protected(x: Double(source.x), y: Double(source.y)) else { return }
        save.sequence += 1
        save.creatures.append(InkCreature(id: "smudge_\(save.sequence)", pageID: save.pageID,
                                         x: Double(source.x), y: Double(source.y), remaining: 1))
    }

    private func updateCreatures(_ dt: Double) {
        for index in save.creatures.indices where save.creatures[index].pageID == save.pageID {
            var creature = save.creatures[index]
            let fire = save.builds.first {
                $0.pageID == save.pageID && $0.kind == .campfire && $0.fuel > 0
                    && hypot(Double($0.point.x) - creature.x, Double($0.point.y) - creature.y) < 4
            }
            if isNight || fire != nil {
                let dx = fire.map { creature.x - Double($0.point.x) } ?? (save.x - creature.x)
                let dy = fire.map { creature.y - Double($0.point.y) } ?? (save.y - creature.y)
                let length = max(0.001, hypot(dx, dy))
                let speed = fire == nil ? 0.65 : 1.5
                let x = creature.x + dx / length * speed * dt
                let y = creature.y + dy / length * speed * dt
                if creatureCanStand(x: x, y: creature.y) { creature.x = x }
                if creatureCanStand(x: creature.x, y: y) { creature.y = y }
            }
            if hypot(creature.x - save.x, creature.y - save.y) < 0.8 && !isProtected {
                save.integrity -= dt * (isNight ? 5 : 2) * creature.remaining
            }
            save.creatures[index] = creature
        }
    }

    private func respawn() {
        save.pageID = save.checkpointPage
        save.x = Double(save.checkpoint.x)
        save.y = Double(save.checkpoint.y)
        save.integrity = 85
        save.hunger = 70
        save.warmth = 80
        save.scraps = max(3, save.scraps - 2)
        save.wood = max(0, save.wood - 1)
        save.food = max(1, save.food)
        enterPage()
        clearArrival(save.checkpoint)
        lastMessage = "Te desdibujaste. Despiertas en tu refugio; colores y recuerdos siguen contigo."
    }

    private func enterPage() {
        save.visited.insert(save.pageID)
        if save.ink[save.pageID] == nil {
            save.ink[save.pageID] = isCompleted ? [] : Set(page.inkSources)
        }
    }

    private func clearArrival(_ point: PagePoint) {
        save.ink[save.pageID, default: []] = inkTiles.filter {
            hypot(Double($0.x - point.x), Double($0.y - point.y)) > 2.5
        }
        save.creatures.removeAll {
            $0.pageID == save.pageID && hypot($0.x - Double(point.x), $0.y - Double(point.y)) <= 4
        }
    }

    private func talk(_ id: String) -> String {
        let flag: String
        let ready: Bool
        switch id {
        case "margin_guide":
            flag = "margin_pass"
            ready = save.collected.contains("first_chest")
        case "garden_guide":
            flag = "garden_pass"
            ready = save.colors.isSuperset(of: [.green, .yellow]) && memoryCount >= 2
        case "reverse_guide":
            flag = "reverse_pass"
            ready = save.colors.contains(.red) && memoryCount >= 3
        case "archive_guide":
            flag = "archive_pass"
            ready = save.colors.contains(.blue) && memoryCount >= 4
        case "seam_guide":
            flag = "seam_pass"
            ready = save.colors.contains(.violet) && memoryCount >= 5 && save.eraserLevel >= 2
        default:
            return isCompleted ? "Gracias por dejarnos un futuro." : "Los seis recuerdos caben en una sola gota."
        }
        guard ready else { return "Aun falta algo. \(objective)" }
        if save.flags.insert(flag).inserted { return "Ya esta. El paso queda abierto; pintalo para cruzar." }
        return "El camino sigue abierto. \(objective)"
    }

    private func gateFailure(_ object: AdventureObject) -> String? {
        guard let flag = object.requiredFlag else { return nil }
        if flag == "eraser_2" { return save.eraserLevel >= 2 ? nil : "Necesitas goma nivel 2 (4 recuerdos)." }
        if flag == "eraser_3" { return save.eraserLevel >= 3 ? nil : "Necesitas goma nivel 3 (6 recuerdos)." }
        return save.flags.contains(flag) ? nil : "Habla con quien cuida esta pagina."
    }

    private func buildFailure(_ kind: BuildKind, at point: PagePoint) -> String? {
        guard inside(point), distance(point) <= 1.65 else { return "Construye en una casilla cercana." }
        guard !page.blocked.contains(point) else { return "La piedra ocupa ese lugar." }
        guard !save.builds.contains(where: { $0.pageID == save.pageID && $0.point == point }) else {
            return "Ya hay una construccion aqui."
        }
        if kind != .path {
            guard distance(point) >= 0.75 else { return "No puedes construir encima de ti." }
            guard !inkTiles.contains(point) else { return "Borra primero la tinta o coloca un camino." }
            guard !page.objects.contains(where: { $0.point == point }),
                  hypot(Double(point.x - page.spawn.x), Double(point.y - page.spawn.y)) > 1.5 else {
                return "Deja libre el objeto y el punto de llegada."
            }
        }
        let required: Set<Pigment>
        switch kind {
        case .wall: required = [.brown]
        case .path: required = []
        case .campfire: required = [.red, .yellow]
        case .shelter: required = [.brown, .green]
        }
        let missing = required.subtracting(save.colors).sorted { $0.rawValue < $1.rawValue }
        if !missing.isEmpty { return "Falta color: \(missing.map(\.title).joined(separator: " + "))." }
        let cost = buildCost(kind)
        guard save.wood >= cost.wood, save.scraps >= cost.scraps else {
            return "Materiales insuficientes. \(buildRequirement(kind))"
        }
        return nil
    }

    private func buildCost(_ kind: BuildKind) -> (wood: Int, scraps: Int) {
        switch kind {
        case .wall: return (2, 0)
        case .path: return (0, 1)
        case .campfire: return (3, 2)
        case .shelter: return (5, 4)
        }
    }

    private func protected(x: Double, y: Double) -> Bool {
        save.builds.contains {
            $0.pageID == save.pageID &&
                (($0.kind == .campfire && $0.fuel > 0 && hypot(Double($0.point.x) - x, Double($0.point.y) - y) <= 3)
                 || ($0.kind == .shelter && hypot(Double($0.point.x) - x, Double($0.point.y) - y) <= 1.6))
        }
    }

    private func creatureCanStand(x: Double, y: Double) -> Bool {
        guard x >= 0.5, y >= 0.5, x < Double(page.width) - 1.5, y < Double(page.height) - 1.5 else { return false }
        let tile = PagePoint(x: Int(x.rounded()), y: Int(y.rounded()))
        return !page.blocked.contains(tile) && !hasBuild(.wall, at: tile) && !hasBuild(.shelter, at: tile)
    }

    private func hasBuild(_ kind: BuildKind, at point: PagePoint) -> Bool {
        save.builds.contains { $0.pageID == save.pageID && $0.point == point && $0.kind == kind }
    }
    private func inside(_ point: PagePoint) -> Bool {
        point.x >= 1 && point.y >= 1 && point.x < page.width - 1 && point.y < page.height - 1
    }
    private func distance(_ point: PagePoint) -> Double { hypot(Double(point.x) - save.x, Double(point.y) - save.y) }
    private func needsPaint(_ object: AdventureObject) -> Bool {
        [.chest, .tree, .berries, .gate, .memory, .inkwell].contains(object.kind)
    }
    private var directions: [PagePoint] {
        [PagePoint(x: 1, y: 0), PagePoint(x: -1, y: 0), PagePoint(x: 0, y: 1), PagePoint(x: 0, y: -1)]
    }
    private func pointOrder(_ a: PagePoint, _ b: PagePoint) -> Bool { a.y == b.y ? a.x < b.x : a.y < b.y }
    private func memoryLine(_ page: String) -> String {
        switch page {
        case "margin": return "Una nina traza un camino. Al final dibuja a alguien que la espera."
        case "garden": return "Dos tazas bajo un arbol. Una es demasiado grande para sus manos."
        case "reverse": return "Fuera hace frio. Dentro, alguien convierte el silencio en cuentos."
        case "archive": return "Una carta llega tarde. Aun asi, encuentra a quien la necesitaba."
        case "seam": return "La despedida no rompe el hilo. Lo vuelve invisible."
        default: return "La nina ya no es nina. Abre el cuaderno y deja sitio para otra historia."
        }
    }
    private func event(_ title: String, _ lines: [String]) -> AdventureEvent {
        emit(AdventureEvent(title: title, lines: lines))
    }
    private func fail(_ message: String) -> AdventureEvent {
        emit(AdventureEvent(title: message, lines: [message], success: false))
    }
    private func emit(_ event: AdventureEvent) -> AdventureEvent {
        lastMessage = event.title
        return event
    }
}
