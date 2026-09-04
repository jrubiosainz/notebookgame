import Foundation

enum AdventureCatalog {
    static let pages: [AdventurePage] = [
        makePage(id: "margin", name: "El margen despierto", subtitle: "Donde empieza un trazo",
                 number: 1, depth: 0, flavor: "No eres una espada. Eres lo que queda al borrar el miedo.",
                 objects: [
                    pigment("brown", .brown, 8, 11),
                    object("first_chest", .chest, 12, 11, "Cofre sin terminar", .brown, "chest"),
                    npc("margin_guide", 10, 9, "Tinta, la cartografa", [
                        "El cuaderno se olvido de quien lo dibujaba. La noche se come sus margenes.",
                        "Recoge marron. Acercate al cofre: primero pintalo, luego abrelo.",
                        "Trae sus retales. Yo abrire el paso al jardin."
                    ]),
                    memory("margin", 14, 8, .brown, "I. La primera linea"),
                    gate("margin_garden", 17, 12, "Pliegue del jardin", .brown, "garden", "margin_pass")
                 ]),
        makePage(id: "garden", name: "Jardin de grafito", subtitle: "Las cosas aprenden a crecer",
                 number: 2, depth: 0, flavor: "Las hojas del arbol y las del cuaderno recuerdan la misma primavera.",
                 objects: [
                    pigment("green", .green, 7, 10), pigment("yellow", .yellow, 14, 14),
                    npc("garden_guide", 12, 9, "La jardinera", [
                        "Con verde puedes pintar arboles y bayas. Vuelven a crecer al amanecer.",
                        "Amarillo es luz, pero sin rojo no hay fuego.",
                        "Dos recuerdos y estos dos colores: entonces te mostrare el reves."
                    ]),
                    memory("garden", 16, 8, .green, "II. Una casa para dos"),
                    gate("garden_margin", 4, 12, "Volver al margen", .brown, "margin"),
                    gate("garden_reverse", 17, 17, "Escalera entre hojas", .green, "reverse", "garden_pass")
                 ]),
        makePage(id: "reverse", name: "El reves del papel", subtitle: "Un calor bajo las tachaduras",
                 number: 3, depth: 1, flavor: "Aqui se guardaron todas las palabras que nadie se atrevio a decir.",
                 objects: [
                    pigment("red", .red, 7, 14),
                    npc("reverse_guide", 12, 8, "Carbon, el fogonero", [
                        "Rojo y amarillo encienden una hoguera. Acercate y descansa para echar lena.",
                        "Las paredes frenan la tinta. Los retales permiten pisarla.",
                        "Tres recuerdos y rojo: el archivo volvera a abrirse."
                    ]),
                    memory("reverse", 16, 16, .red, "III. El invierno compartido"),
                    gate("reverse_garden", 4, 12, "Subir al jardin", .green, "garden"),
                    gate("reverse_archive", 17, 9, "Puerta chamuscada", .red, "archive", "reverse_pass")
                 ]),
        makePage(id: "archive", name: "Archivo sumergido", subtitle: "Puentes sobre lo olvidado",
                 number: 4, depth: 1, flavor: "El agua no borro las cartas. Solo las dejo esperando una respuesta.",
                 objects: [
                    pigment("blue", .blue, 7, 8),
                    npc("archive_guide", 12, 14, "El archivero", [
                        "Azul da cuerpo a los puentes. Pintalos y permaneceran abiertos.",
                        "Tu goma no hiere: cada pasada hace mas transparentes las manchas.",
                        "Cuatro recuerdos y azul abren la costura. La goma doble abre mi tunel al margen."
                    ]),
                    memory("archive", 16, 8, .blue, "IV. La carta que volvio"),
                    gate("archive_reverse", 4, 12, "Volver al reves", .red, "reverse"),
                    gate("archive_seam", 17, 17, "Puente de agua", .blue, "seam", "archive_pass"),
                    gate("archive_margin", 4, 18, "Tunel del margen", .blue, "margin", "eraser_2")
                 ]),
        makePage(id: "seam", name: "La costura violeta", subtitle: "Donde se unen los recuerdos",
                 number: 5, depth: 2, flavor: "No es una grieta. Es una cicatriz que mantiene unido el libro.",
                 objects: [
                    pigment("violet", .violet, 7, 15),
                    npc("seam_guide", 12, 8, "La costurera", [
                        "Yo cosi el cuaderno cuando su autora dejo de venir.",
                        "No falta tinta: faltan sus seis recuerdos. El ultimo duerme junto al tintero.",
                        "Cinco recuerdos, violeta y una goma doble soltaran el sello."
                    ]),
                    memory("seam", 16, 15, .violet, "V. Lo que permanece"),
                    gate("seam_archive", 4, 12, "Puente del archivo", .blue, "archive"),
                    gate("seam_origin", 17, 9, "Sello del origen", .violet, "origin", "seam_pass")
                 ]),
        makePage(id: "origin", name: "Corazon del tintero", subtitle: "El final es un nuevo margen",
                 number: 6, depth: 2, flavor: "Una pequena mano dibujo este mundo para no sentirse sola.",
                 objects: [
                    npc("origin_guide", 8, 8, "La ultima gota", [
                        "La autora crecio. No nos abandono: nos llevo consigo.",
                        "Pinta el ultimo recuerdo. Reune los seis y devuelve violeta al tintero.",
                        "Cuando cierres esta historia, todas sus paginas seguiran siendo tuyas."
                    ]),
                    memory("origin", 15, 9, .violet, "VI. Volver a empezar"),
                    object("origin_inkwell", .inkwell, 11, 16, "El tintero del origen", .violet, "inkwell"),
                    gate("origin_seam", 4, 12, "Volver a la costura", .violet, "seam"),
                    gate("origin_garden", 17, 18, "Raiz de regreso", .blue, "garden", "eraser_3")
                 ])
    ]

    static func page(_ id: String) -> AdventurePage {
        guard let page = pages.first(where: { $0.id == id }) else {
            preconditionFailure("Unknown adventure page: \(id)")
        }
        return page
    }

    private static func object(_ id: String, _ kind: AdventureObjectKind, _ x: Int, _ y: Int,
                               _ name: String, _ color: Pigment? = nil, _ art: String) -> AdventureObject {
        AdventureObject(id: id, kind: kind, point: PagePoint(x: x, y: y),
                        name: name, pigment: color, art: art)
    }

    private static func pigment(_ id: String, _ color: Pigment, _ x: Int, _ y: Int) -> AdventureObject {
        AdventureObject(id: "pigment_\(id)", kind: .pigment, point: PagePoint(x: x, y: y),
                        name: "Pigmento \(color.title.lowercased())", pigment: color,
                        art: "ink_drop", folder: "ui")
    }

    private static func npc(_ id: String, _ x: Int, _ y: Int, _ name: String,
                            _ lines: [String]) -> AdventureObject {
        AdventureObject(id: id, kind: .npc, point: PagePoint(x: x, y: y), name: name,
                        art: id == "margin_guide" ? "hiker" : "bench_elder", folder: "npcs", lines: lines)
    }

    private static func memory(_ page: String, _ x: Int, _ y: Int, _ color: Pigment,
                               _ name: String) -> AdventureObject {
        AdventureObject(id: "memory_\(page)", kind: .memory, point: PagePoint(x: x, y: y),
                        name: name, pigment: color, art: "star", folder: "ui")
    }

    private static func gate(_ id: String, _ x: Int, _ y: Int, _ name: String, _ color: Pigment,
                             _ target: String, _ flag: String? = nil) -> AdventureObject {
        AdventureObject(id: id, kind: .gate, point: PagePoint(x: x, y: y), name: name,
                        pigment: color, art: color == .blue ? "rock_small" : "signpost",
                        targetPage: target, targetPoint: PagePoint(x: 10, y: 11), requiredFlag: flag)
    }

    private static func makePage(id: String, name: String, subtitle: String, number: Int,
                                 depth: Int, flavor: String, objects: [AdventureObject]) -> AdventurePage {
        var props = objects
        props += [
            object("\(id)_scraps", .scraps, 9, 13, "Retales del sendero", nil, "stump"),
            object("\(id)_tree", .tree, 6, 16, "Arbol de papel", .green, "tree_round"),
            object("\(id)_berries", .berries, 13, 18, "Bayas dibujadas", .green, "bush"),
            object("\(id)_chest", .chest, 18, 5, "Cofre del margen", .brown, "chest"),
            object("\(id)_rock", .rock, 3, 5, "Nota en piedra", nil, "rock_large")
        ]
        let blocked: Set<PagePoint>
        let sources: [PagePoint]
        switch id {
        case "margin":
            // Two groves frame the safe central trail; the northern chest rewards a short detour.
            blocked = Set(rect(3...5, 6...8) + rect(15...18, 20...21) + row(3, 5...8))
            sources = [PagePoint(x: 2, y: 2), PagePoint(x: 19, y: 21)]
            props += [object("margin_pine", .tree, 6, 7, "Pino del primer trazo", .green, "tree_pine")]
        case "garden":
            // Broken terraces make the player wind between harvesting beds.
            blocked = Set(row(6, 4...17, gaps: [8, 9, 12, 13]) +
                          row(15, 9...18, gaps: [12, 13, 16, 17]) + rect(3...4, 17...20))
            sources = [PagePoint(x: 2, y: 21), PagePoint(x: 19, y: 2), PagePoint(x: 19, y: 15)]
            props += [
                object("garden_orchard", .tree, 6, 5, "Huerto de papel", .green, "tree_round"),
                object("garden_bed", .berries, 15, 13, "Bayas del bancal", .green, "bush")
            ]
        case "reverse":
            // Parallel folds form three chambers with generous staggered openings.
            blocked = Set(column(8, 3...20, gaps: [8, 9, 10, 11, 14, 15]) +
                          column(14, 4...21, gaps: [7, 8, 9, 12, 13, 16, 17]) + row(21, 3...7))
            sources = [PagePoint(x: 3, y: 3), PagePoint(x: 19, y: 20), PagePoint(x: 12, y: 21)]
            props += [object("reverse_stump", .scraps, 5, 18, "Retales entre pliegues", nil, "stump")]
        case "archive":
            // An ink canal cuts the eastern archive in two. Its central ford stays traversable;
            // erasure and scrap bridges offer shorter crossings toward the blue memory.
            blocked = Set(row(5, 3...11, gaps: [3, 6, 7]) + row(19, 3...11, gaps: [6, 7]) +
                          column(18, 6...15, gaps: [8, 9, 12]) + rect(3...4, 3...4))
            sources = (3...20).filter { ![10, 11, 12, 13].contains($0) }.map { PagePoint(x: 14, y: $0) }
            props += [object("archive_cache", .scraps, 12, 7, "Cartas sueltas", nil, "stump")]
        case "seam":
            // Offset seams pinch into two thread-width corridors, then open around the seal.
            blocked = Set(row(6, 3...18, gaps: [8, 9, 14, 15]) +
                          row(13, 3...18, gaps: [6, 7, 9, 10, 11, 16, 17]) +
                          row(20, 5...18, gaps: [9, 10, 15, 16]) + column(19, 7...12))
            sources = [PagePoint(x: 3, y: 20), PagePoint(x: 18, y: 3), PagePoint(x: 18, y: 19)]
            props += [object("seam_thread", .scraps, 8, 18, "Hilo de retales", nil, "stump")]
        default:
            // A broken amphitheatre surrounds the inkwell. Four doorways keep the finale open.
            blocked = Set(row(5, 5...17, gaps: [10, 11, 12]) +
                          row(20, 5...17, gaps: [10, 11, 12]) +
                          column(5, 6...19, gaps: [10, 11, 12, 16]) +
                          column(18, 6...19, gaps: [10, 11, 12, 16, 17, 18]))
            sources = [PagePoint(x: 2, y: 3), PagePoint(x: 20, y: 3), PagePoint(x: 20, y: 21)]
            props += [object("origin_last_tree", .tree, 8, 17, "El arbol de la autora", .green, "tree_pine")]
        }
        return AdventurePage(id: id, name: name, subtitle: subtitle, number: number, depth: depth,
                             width: 22, height: 24, spawn: PagePoint(x: 10, y: 11),
                             objects: props, inkSources: sources, blocked: blocked, flavor: flavor)
    }

    private static func row(_ y: Int, _ xs: ClosedRange<Int>, gaps: Set<Int> = []) -> [PagePoint] {
        xs.filter { !gaps.contains($0) }.map { PagePoint(x: $0, y: y) }
    }

    private static func column(_ x: Int, _ ys: ClosedRange<Int>, gaps: Set<Int> = []) -> [PagePoint] {
        ys.filter { !gaps.contains($0) }.map { PagePoint(x: x, y: $0) }
    }

    private static func rect(_ xs: ClosedRange<Int>, _ ys: ClosedRange<Int>) -> [PagePoint] {
        xs.flatMap { x in ys.map { PagePoint(x: x, y: $0) } }
    }
}
