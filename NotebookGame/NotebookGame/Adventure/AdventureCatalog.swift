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
        // Broken perimeter patterns frame distinct pages without sealing their readable central paths.
        let patterns: [[PagePoint]] = [
            (3...8).map { PagePoint(x: $0, y: 3) },
            (4...9).map { PagePoint(x: 19, y: $0) },
            (3...8).map { PagePoint(x: $0, y: 20) },
            (3...7).map { PagePoint(x: 2, y: $0 + 10) },
            (13...18).map { PagePoint(x: $0, y: 21) },
            (4...8).map { PagePoint(x: $0, y: 2) } + (14...18).map { PagePoint(x: $0, y: 2) }
        ]
        let blocked = Set(patterns[number - 1])
        let sources = number.isMultiple(of: 2)
            ? [PagePoint(x: 2, y: 21), PagePoint(x: 19, y: 2)]
            : [PagePoint(x: 2, y: 2), PagePoint(x: 19, y: 21)]
        return AdventurePage(id: id, name: name, subtitle: subtitle, number: number, depth: depth,
                             width: 22, height: 24, spawn: PagePoint(x: 10, y: 11),
                             objects: props, inkSources: sources, blocked: blocked, flavor: flavor)
    }
}
